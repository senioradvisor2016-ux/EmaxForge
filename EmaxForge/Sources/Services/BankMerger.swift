import Foundation

/// Merge presets and samples from one bank into another within an EMAX II HD image.
///
/// Bank data layout (EMX full format — Ghidra-verified):
///   0x000–0x1FF   Bank header (512 bytes)
///   0x200–0x101FF Preset area: 256 × 256-byte blocks
///   0x10200–0x1FFFF Sample param area: up to 999 × 64-byte entries
///   0x20000+      Sample PCM data (raw 16-bit LE)
///
/// Per preset block (256 bytes at presetArea + index × 0x100):
///   +0x00..+0x0B  name (12 bytes ASCII, NUL-padded)
///   +0x23         zoneCount (1 byte)
///   +0x24..+0x7B  keyMap (88 bytes — sample index per MIDI key)
///   +0x7C..       zone descriptors + voice records
///
/// Per sample param entry (64 bytes at 0x10200 + index × 0x40):
///   +0x00  startAddress (UInt32 LE — relative offset into sample data area)
///   +0x04  endAddress   (UInt32 LE)
///   +0x20  name         (16 bytes ASCII)
class BankMerger {

    // MARK: - Public types

    struct MergeOptions {
        var skipDuplicatePresetNames: Bool = true
        var skipDuplicateSampleNames: Bool = false
        var maxPresetsInTarget: Int = 256
    }

    struct MergeResult {
        let presetsAdded: Int
        let presetNamesSkipped: [String]
        let samplesAdded: Int
        let sampleNamesSkipped: [String]
        let clustersUsed: Int
    }

    enum MergeError: LocalizedError {
        case targetBankFull(maxPresets: Int)
        case insufficientDiskSpace(needed: Int, available: Int)
        case sourceReadError(String)
        case targetWriteError(String)

        var errorDescription: String? {
            switch self {
            case .targetBankFull(let max):
                return "Target bank is full (max \(max) presets)"
            case .insufficientDiskSpace(let needed, let available):
                return "Insufficient disk space: need \(needed) clusters, \(available) available"
            case .sourceReadError(let msg):
                return "Source read error: \(msg)"
            case .targetWriteError(let msg):
                return "Target write error: \(msg)"
            }
        }
    }

    // MARK: - Constants (mirrors EmaxIIFormat)

    private static let presetAreaOffset   = 0x200
    private static let presetSize         = 0x100        // 256 bytes per preset
    private static let maxPresets         = 256
    private static let sampleParamOffset  = 0x10200
    private static let sampleParamSize    = 0x40         // 64 bytes per param entry
    private static let sampleDataOffset   = 0x20000
    private static let presetNameLength   = 12
    private static let presetKeyMapOffset = 0x24         // within preset block
    private static let presetKeyMapLength = 88
    private static let sampleParamName   = 0x20          // within sample param block (16 bytes)
    private static let sampleParamStart  = 0x00          // UInt32 startAddress offset
    private static let sampleParamEnd    = 0x04          // UInt32 endAddress offset

    // MARK: - Main merge entry point

    /// Merge presets and samples from `sourceEntry` into `targetEntry` in-place on disk.
    ///
    /// Algorithm:
    ///  1. Read source and target bank data via their cluster chains.
    ///  2. Inventory existing target presets and samples.
    ///  3. For each source preset (non-empty name):
    ///     a. Optionally skip if name already exists in target.
    ///     b. Copy the 256-byte preset block into the next free target slot.
    ///     c. Remap key-map sample indices: source index → target index.
    ///  4. Copy source sample params after existing target params, adjusting startAddress/endAddress.
    ///  5. Append source PCM data after existing target PCM data.
    ///  6. Allocate additional clusters if needed; update FAT and BNT clusterCount.
    ///  7. Write the enlarged target bank data back to disk.
    static func merge(
        source sourceEntry: BankCatalogEntry,
        into targetEntry: BankCatalogEntry,
        imageURL: URL,
        options: MergeOptions = MergeOptions()
    ) throws -> MergeResult {

        // --- Load disk geometry ---
        let geo = try BankDataWriter.loadGeometry(from: imageURL)

        // --- Read source bank data ---
        guard !sourceEntry.clusterChain.isEmpty else {
            throw MergeError.sourceReadError("Source bank has empty cluster chain")
        }
        let sourceData: Data
        do {
            sourceData = try BankDataWriter.readBankData(
                entry: sourceEntry, from: imageURL, geometry: geo)
        } catch {
            throw MergeError.sourceReadError(error.localizedDescription)
        }

        // --- Read target bank data ---
        guard !targetEntry.clusterChain.isEmpty else {
            throw MergeError.targetWriteError("Target bank has empty cluster chain")
        }
        var targetData: Data
        do {
            targetData = try BankDataWriter.readBankData(
                entry: targetEntry, from: imageURL, geometry: geo)
        } catch {
            throw MergeError.targetWriteError(error.localizedDescription)
        }

        // Ensure target data buffer is at least the minimum EMX size.
        let minSize = Self.sampleDataOffset
        if targetData.count < minSize {
            targetData.append(Data(count: minSize - targetData.count))
        }

        // --- Inventory existing target presets ---
        var targetPresetNames = Set<String>()
        var firstFreeTargetPresetSlot = -1

        for i in 0..<Self.maxPresets {
            let blockBase = Self.presetAreaOffset + i * Self.presetSize
            guard blockBase + Self.presetNameLength <= targetData.count else { break }
            let nameBytes = targetData[blockBase ..< blockBase + Self.presetNameLength]
            let name = presetName(from: nameBytes)
            if name.isEmpty {
                if firstFreeTargetPresetSlot < 0 { firstFreeTargetPresetSlot = i }
            } else {
                targetPresetNames.insert(name)
            }
        }

        // --- Inventory existing target samples ---
        var targetSampleCount = 0
        var targetSampleNames = Set<String>()
        var targetPCMEnd: UInt32 = 0   // highest endAddress seen across all target samples

        for i in 0..<999 {
            let paramBase = Self.sampleParamOffset + i * Self.sampleParamSize
            guard paramBase + Self.sampleParamSize <= targetData.count else { break }
            let startAddr = bm_readU32LE(targetData, at: paramBase + Self.sampleParamStart)
            let endAddr   = bm_readU32LE(targetData, at: paramBase + Self.sampleParamEnd)
            if startAddr == 0 && endAddr == 0 { continue }
            targetSampleCount += 1
            if endAddr > targetPCMEnd { targetPCMEnd = endAddr }
            let nameOff = paramBase + Self.sampleParamName
            let nameEnd = min(nameOff + 16, targetData.count)
            if nameOff < nameEnd {
                let sname = presetName(from: targetData[nameOff ..< nameEnd])
                if !sname.isEmpty { targetSampleNames.insert(sname) }
            }
        }

        // --- Collect source presets ---
        struct SourcePreset {
            let index: Int
            let name: String
        }
        var sourcePresets = [SourcePreset]()
        for i in 0..<Self.maxPresets {
            let blockBase = Self.presetAreaOffset + i * Self.presetSize
            guard blockBase + Self.presetNameLength <= sourceData.count else { break }
            let nameBytes = sourceData[blockBase ..< blockBase + Self.presetNameLength]
            let name = presetName(from: nameBytes)
            if !name.isEmpty {
                sourcePresets.append(SourcePreset(index: i, name: name))
            }
        }

        // --- Collect source samples ---
        struct SourceSample {
            let index: Int
            let name: String
            let startAddr: UInt32
            let endAddr: UInt32
        }
        var sourceSamples = [SourceSample]()
        for i in 0..<999 {
            let paramBase = Self.sampleParamOffset + i * Self.sampleParamSize
            guard paramBase + Self.sampleParamSize <= sourceData.count else { break }
            let startAddr = bm_readU32LE(sourceData, at: paramBase + Self.sampleParamStart)
            let endAddr   = bm_readU32LE(sourceData, at: paramBase + Self.sampleParamEnd)
            if startAddr == 0 && endAddr == 0 { continue }
            let nameOff = paramBase + Self.sampleParamName
            let nameEnd = min(nameOff + 16, sourceData.count)
            var sname = ""
            if nameOff < nameEnd {
                sname = presetName(from: sourceData[nameOff ..< nameEnd])
            }
            sourceSamples.append(SourceSample(index: i, name: sname, startAddr: startAddr, endAddr: endAddr))
        }

        // --- Filter samples to add ---
        var samplesSkipped = [String]()
        var samplesToAdd = [SourceSample]()
        for sample in sourceSamples {
            if options.skipDuplicateSampleNames && targetSampleNames.contains(sample.name) {
                samplesSkipped.append(sample.name)
            } else {
                samplesToAdd.append(sample)
            }
        }

        // Build source→target sample index mapping
        // targetSampleCount is the first free target sample slot index
        var sourceSampleIndexToTarget = [Int: Int]()
        for (offset, sample) in samplesToAdd.enumerated() {
            sourceSampleIndexToTarget[sample.index] = targetSampleCount + offset
        }
        // Samples skipped still need a mapping (their source index → closest already-existing)
        // We map them to 0xFF (no sample) since we can't reliably deduplicate by name-matching index
        // (0xFF = no assignment in key map)

        // --- Filter presets to add ---
        var presetsSkipped = [String]()
        var presetsToAdd = [SourcePreset]()
        for preset in sourcePresets {
            if options.skipDuplicatePresetNames && targetPresetNames.contains(preset.name) {
                presetsSkipped.append(preset.name)
            } else {
                presetsToAdd.append(preset)
            }
        }

        // Check target capacity
        let targetFreeSlots = countFreePresetSlots(in: targetData)
        let actualMaxAdd = min(presetsToAdd.count, targetFreeSlots,
                               options.maxPresetsInTarget - targetPresetNames.count)
        let presetsToWrite = Array(presetsToAdd.prefix(actualMaxAdd))

        // --- Copy sample PCM data ---
        // Source PCM data starts at sampleDataOffset in source bank
        let sourcePCMBase = Self.sampleDataOffset
        let sourcePCMEnd  = sourceData.count
        var sourcePCMData = Data()
        if sourcePCMBase < sourcePCMEnd {
            sourcePCMData = sourceData[sourcePCMBase ..< sourcePCMEnd]
        }

        // targetPCMEnd is the byte offset just after the last target sample (relative to PCM area start)
        // We will append source samples starting at targetPCMEnd
        let appendOffset: UInt32 = targetPCMEnd

        // --- Extend target data buffer to accommodate new data ---
        // We need:
        //   - Extra preset blocks (already in preset area if slots free)
        //   - Extra sample param entries (at sampleParamOffset + targetSampleCount*64)
        //   - Extra PCM data (appended after current PCM)
        let newSampleParamEndOffset = Self.sampleParamOffset +
            (targetSampleCount + samplesToAdd.count) * Self.sampleParamSize
        let newPCMAreaEndOffset = Self.sampleDataOffset + Int(appendOffset) + sourcePCMData.count
        let newTotalSize = max(newPCMAreaEndOffset, targetData.count)

        if newTotalSize > targetData.count {
            targetData.append(Data(count: newTotalSize - targetData.count))
        }

        // --- Write new sample params into target ---
        for (offset, sample) in samplesToAdd.enumerated() {
            let targetParamIdx = targetSampleCount + offset
            let targetParamBase = Self.sampleParamOffset + targetParamIdx * Self.sampleParamSize
            guard targetParamBase + Self.sampleParamSize <= targetData.count else { break }

            // Copy entire 64-byte param block from source
            let srcParamBase = Self.sampleParamOffset + sample.index * Self.sampleParamSize
            if srcParamBase + Self.sampleParamSize <= sourceData.count {
                targetData.replaceSubrange(
                    targetParamBase ..< targetParamBase + Self.sampleParamSize,
                    with: sourceData[srcParamBase ..< srcParamBase + Self.sampleParamSize]
                )
            }

            // Adjust addresses: new addr = source relative addr + appendOffset
            let newStart = sample.startAddr + appendOffset
            let newEnd   = sample.endAddr   + appendOffset
            bm_writeU32LE(newStart, into: &targetData, at: targetParamBase + Self.sampleParamStart)
            bm_writeU32LE(newEnd,   into: &targetData, at: targetParamBase + Self.sampleParamEnd)
        }

        // --- Write new PCM data into target ---
        if !sourcePCMData.isEmpty {
            let pcmWriteBase = Self.sampleDataOffset + Int(appendOffset)
            let pcmWriteEnd  = pcmWriteBase + sourcePCMData.count
            if pcmWriteEnd <= targetData.count {
                targetData.replaceSubrange(pcmWriteBase ..< pcmWriteEnd, with: sourcePCMData)
            }
        }

        // --- Write presets into target, remapping key-map sample indices ---
        var nextSlot = firstFreeTargetPresetSlot < 0 ? 0 : firstFreeTargetPresetSlot
        for preset in presetsToWrite {
            // Advance to a truly free slot
            while nextSlot < Self.maxPresets {
                let bb = Self.presetAreaOffset + nextSlot * Self.presetSize
                guard bb + Self.presetNameLength <= targetData.count else { break }
                let n = presetName(from: targetData[bb ..< bb + Self.presetNameLength])
                if n.isEmpty { break }
                nextSlot += 1
            }
            guard nextSlot < Self.maxPresets else { break }

            let srcBlockBase = Self.presetAreaOffset + preset.index * Self.presetSize
            let dstBlockBase = Self.presetAreaOffset + nextSlot  * Self.presetSize
            guard srcBlockBase + Self.presetSize <= sourceData.count,
                  dstBlockBase + Self.presetSize <= targetData.count else {
                nextSlot += 1
                continue
            }

            // Copy the 256-byte block
            targetData.replaceSubrange(
                dstBlockBase ..< dstBlockBase + Self.presetSize,
                with: sourceData[srcBlockBase ..< srcBlockBase + Self.presetSize]
            )

            // Remap key-map sample indices
            let keyMapBase = dstBlockBase + Self.presetKeyMapOffset
            for k in 0..<Self.presetKeyMapLength {
                let byteOff = keyMapBase + k
                guard byteOff < targetData.count else { break }
                let srcIdx = Int(targetData[byteOff])
                if srcIdx == 0xFF { continue }  // no assignment
                if let dstIdx = sourceSampleIndexToTarget[srcIdx] {
                    targetData[byteOff] = UInt8(clamping: dstIdx)
                } else {
                    // Sample was skipped (duplicate); clear the assignment
                    targetData[byteOff] = 0xFF
                }
            }

            nextSlot += 1
        }

        // --- Update bank header preset/sample counts ---
        let newPresetCount = countNonEmptyPresets(in: targetData)
        let newSampleCount = targetSampleCount + samplesToAdd.count
        bm_writeU16LE(UInt16(newPresetCount), into: &targetData, at: 0x1C)
        bm_writeU16LE(UInt16(newSampleCount), into: &targetData, at: 0x1E)

        // Update total sample size
        let totalSampleBytes = UInt32(Int(appendOffset) + sourcePCMData.count)
        if totalSampleBytes > bm_readU32LE(targetData, at: 0x20) {
            bm_writeU32LE(totalSampleBytes, into: &targetData, at: 0x20)
        }

        // --- Check if we need more clusters ---
        let currentCapacity = targetEntry.clusterChain.count * geo.clusterSize
        let additionalClustersNeeded: Int
        if targetData.count > currentCapacity {
            let extraBytes = targetData.count - currentCapacity
            additionalClustersNeeded = (extraBytes + geo.clusterSize - 1) / geo.clusterSize
        } else {
            additionalClustersNeeded = 0
        }

        // Allocate additional clusters if needed and update FAT + BNT
        var finalClusterChain = targetEntry.clusterChain
        if additionalClustersNeeded > 0 {
            // Read FAT
            let fatData = try readFAT(from: imageURL, geo: geo)
            var fat = fatData

            // Find free clusters
            var usedSet = Set(fat.enumerated().compactMap { $1 != 0x0000 ? $0 : nil })
            var freeClusters = [Int]()
            for i in 1..<min(fat.count, geo.totalClusters + 2) {
                if !usedSet.contains(i) {
                    freeClusters.append(i)
                    if freeClusters.count >= additionalClustersNeeded { break }
                }
            }
            guard freeClusters.count >= additionalClustersNeeded else {
                throw MergeError.insufficientDiskSpace(
                    needed: additionalClustersNeeded, available: freeClusters.count)
            }

            let newClusters = Array(freeClusters.prefix(additionalClustersNeeded))

            // Link last existing cluster to first new cluster
            if let lastExisting = finalClusterChain.last {
                fat[lastExisting] = UInt16(newClusters[0])
            }
            // Chain new clusters together, end with 0x8080
            for i in 0..<newClusters.count {
                fat[newClusters[i]] = i < newClusters.count - 1
                    ? UInt16(newClusters[i + 1])
                    : 0x8080
            }

            finalClusterChain.append(contentsOf: newClusters)

            // Write updated FAT
            try writeFAT(fat, to: imageURL, geo: geo)

            // Update BNT clusterCount
            try updateBNTClusterCount(
                catalogIndex: targetEntry.catalogIndex,
                newCount: finalClusterChain.count,
                imageURL: imageURL,
                geo: geo
            )
        }

        // --- Write target bank data back ---
        // Build a synthetic entry with the updated cluster chain so BankDataWriter can write it
        let updatedEntry = BankCatalogEntry(
            catalogIndex: targetEntry.catalogIndex,
            name: targetEntry.name,
            bankIndex: targetEntry.bankIndex,         // BNT +0x18 idx (preset address)
            startCluster: targetEntry.startCluster,   // BNT +0x10 bankTag (slot marker)
            numPresets: UInt16(finalClusterChain.count), // BNT +0x14 cluster count
            fieldA: targetEntry.fieldA,
            fieldB: targetEntry.fieldB,               // BNT +0x12 real FAT start cluster
            flags: targetEntry.flags,
            clusterChain: finalClusterChain,
            sizeBytes: targetData.count
        )

        do {
            try BankDataWriter.writeBankData(targetData, entry: updatedEntry, to: imageURL, geometry: geo)
        } catch {
            throw MergeError.targetWriteError(error.localizedDescription)
        }

        return MergeResult(
            presetsAdded: presetsToWrite.count,
            presetNamesSkipped: presetsSkipped,
            samplesAdded: samplesToAdd.count,
            sampleNamesSkipped: samplesSkipped,
            clustersUsed: finalClusterChain.count
        )
    }

    // MARK: - Helpers

    /// Extract a preset name from raw bytes (NUL/space-padded, 12 bytes)
    private static func presetName(from bytes: Data) -> String {
        var chars = [Character]()
        for b in bytes {
            if b == 0 { break }
            if b >= 32 && b < 127 { chars.append(Character(UnicodeScalar(b))) }
        }
        return String(chars).trimmingCharacters(in: .whitespaces)
    }

    /// Count free (empty-name) preset slots in target bank data
    private static func countFreePresetSlots(in bankData: Data) -> Int {
        var free = 0
        for i in 0..<Self.maxPresets {
            let base = Self.presetAreaOffset + i * Self.presetSize
            guard base + Self.presetNameLength <= bankData.count else { break }
            if presetName(from: bankData[base ..< base + Self.presetNameLength]).isEmpty {
                free += 1
            }
        }
        return free
    }

    /// Count non-empty presets in bank data
    private static func countNonEmptyPresets(in bankData: Data) -> Int {
        var count = 0
        for i in 0..<Self.maxPresets {
            let base = Self.presetAreaOffset + i * Self.presetSize
            guard base + Self.presetNameLength <= bankData.count else { break }
            if !presetName(from: bankData[base ..< base + Self.presetNameLength]).isEmpty {
                count += 1
            }
        }
        return count
    }

    // MARK: - FAT / BNT helpers

    private static func readFAT(from imageURL: URL, geo: BankDataWriter.DiskGeometry) throws -> [UInt16] {
        guard let handle = try? FileHandle(forReadingFrom: imageURL) else {
            throw MergeError.targetWriteError("Cannot open image for FAT read")
        }
        defer { handle.closeFile() }
        handle.seek(toFileOffset: geo.fatOffset)
        let fatData = handle.readData(ofLength: geo.fatSize)
        var fat = [UInt16]()
        fat.reserveCapacity(geo.fatEntryCount)
        for i in stride(from: 0, to: min(geo.fatSize, fatData.count), by: 2) {
            fat.append(bm_readU16LE(fatData, at: i))
        }
        // Pad to fatEntryCount if needed
        while fat.count < geo.fatEntryCount { fat.append(0) }
        return fat
    }

    private static func writeFAT(_ fat: [UInt16], to imageURL: URL, geo: BankDataWriter.DiskGeometry) throws {
        guard let handle = try? FileHandle(forUpdating: imageURL) else {
            throw MergeError.targetWriteError("Cannot open image for FAT write")
        }
        defer {
            handle.synchronizeFile()
            handle.closeFile()
        }
        var fatBytes = Data(count: geo.fatSize)
        for i in 0..<min(fat.count, geo.fatEntryCount) {
            bm_writeU16LE(fat[i], into: &fatBytes, at: i * 2)
        }
        handle.seek(toFileOffset: geo.fatOffset)
        handle.write(fatBytes)
    }

    private static func updateBNTClusterCount(
        catalogIndex: Int,
        newCount: Int,
        imageURL: URL,
        geo: BankDataWriter.DiskGeometry
    ) throws {
        guard let handle = try? FileHandle(forUpdating: imageURL) else {
            throw MergeError.targetWriteError("Cannot open image for BNT update")
        }
        defer {
            handle.synchronizeFile()
            handle.closeFile()
        }
        // BNT entry for catalogIndex is at geo.bntOffset + catalogIndex * 32
        // clusterCount is at +0x14 (2 bytes, UInt16 LE)
        let entryOffset = geo.bntOffset + UInt64(catalogIndex * 32)
        handle.seek(toFileOffset: entryOffset + 0x14)
        var countBytes = Data(count: 2)
        bm_writeU16LE(UInt16(newCount), into: &countBytes, at: 0)
        handle.write(countBytes)
    }
}

// MARK: - Data helpers
// Free functions to avoid fileprivate extension collision with other files in the module.

private func bm_readU16LE(_ data: Data, at offset: Int) -> UInt16 {
    guard offset + 2 <= data.count else { return 0 }
    return data.withUnsafeBytes { $0.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt16.self) }
}

private func bm_readU32LE(_ data: Data, at offset: Int) -> UInt32 {
    guard offset + 4 <= data.count else { return 0 }
    return data.withUnsafeBytes { $0.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt32.self) }
}

private func bm_writeU16LE(_ value: UInt16, into data: inout Data, at offset: Int) {
    guard offset + 2 <= data.count else { return }
    data[offset]     = UInt8(value & 0xFF)
    data[offset + 1] = UInt8(value >> 8)
}

private func bm_writeU32LE(_ value: UInt32, into data: inout Data, at offset: Int) {
    guard offset + 4 <= data.count else { return }
    data[offset]     = UInt8(value & 0xFF)
    data[offset + 1] = UInt8((value >> 8)  & 0xFF)
    data[offset + 2] = UInt8((value >> 16) & 0xFF)
    data[offset + 3] = UInt8((value >> 24) & 0xFF)
}
