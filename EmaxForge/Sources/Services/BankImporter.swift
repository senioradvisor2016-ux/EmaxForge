import Foundation

/// Import .EB2 bank files into EMAX II HD images
///
/// Verified disk layout (from working disk analysis, Mar 21 2026):
///   Header:  sector 0 (0x000), 512 bytes
///   FAT:     ALWAYS at 0x400 (sector 2), size = header[0x1C] sectors
///   BNT:     sector header[0x10]*512, 32-byte entries, max header[0x14] banks
///   Clusters: sector header[0x20]*512, size computed from (diskSectors-caSector)/totalClusters
///
/// BNT entry layout (32 bytes) — verified against EmaxIIFileSystem.swift and EmaxII-02.ez2:
///   [0-15]:  name, ASCII space/null padded to 16 bytes
///   [16-17]: startCluster (U16 LE, 0-based cluster index; 0x7800 = OS special marker)
///   [18-19]: clusterCount (U16 LE, must match FAT chain length)
///   [20-21]: numPresets (U16 LE; set to 0 on import — written by EMAX II at load time)
///   [22-23]: f22 (unknown EMAX II metadata; range 0-127; set to 0 on import — verified safe)
///   [24-25]: bankIndex (idx, preset address; set to 0 on import — verified safe)
///   [26-27]: flags = 0x0081 (ALWAYS)
///   [28-31]: zeros
///
/// NOTE: f22/bankIndex are preserved when reading disks but written as 0x0000 on import.
/// Analysis (Mar 21 2026) shows no correlation to bank size, cluster count, or preset count.
/// Current hypothesis: EMAX II runtime metadata (caching hints) or EMXP-specific fields.
/// EmaxForge-created disks with f22=bankIndex=0 work correctly — fields are not critical for boot/load.
///
/// Cluster offset formula: ca_off + cluster * clusterSize  (0-based, verified vs EmaxIIFileSystem.swift)
class BankImporter {

    enum ImportError: LocalizedError {
        case notEmaxImage
        case imageTooSmall
        case noFreeSpace(needed: Int, available: Int)
        case bankTooSmall
        case noFreeBNTSlot
        case duplicateBankName(String)
        case writeError(String)
        case unsupportedFormat(String)

        var errorDescription: String? {
            switch self {
            case .notEmaxImage:   return "Not a valid EMAX II image (missing EMX2 magic)"
            case .imageTooSmall:  return "Image file too small"
            case .noFreeSpace(let needed, let available):
                return "Not enough space: need \(needed) cluster(s), only \(available) free"
            case .bankTooSmall:   return "Bank file is too small to be valid"
            case .noFreeBNTSlot:  return "No free bank slot (BNT full)"
            case .duplicateBankName(let name): return "Bank '\(name)' already exists in this image (use allowDuplicate to override)"
            case .writeError(let msg): return "Write error: \(msg)"
            case .unsupportedFormat(let msg): return "Unsupported format: \(msg)"
            }
        }
    }

    struct ImportResult {
        let bankName: String
        let clustersUsed: Int
        let sizeBytes: Int
        let catalogIndex: Int
    }

    /// Parsed disk geometry from header
    private struct DiskGeometry {
        let clusterSize: Int
        let fatSectors: UInt32
        let bntStartSector: UInt32
        let maxBanks: Int
        let clusterAreaStartSector: UInt32
        let totalClusters: Int

        /// FAT is ALWAYS at 0x400 regardless of header field 0x0C
        var fatOffset: UInt64 { 0x400 }
        var fatSize: Int { Int(fatSectors) * 512 }
        var fatEntryCount: Int { fatSize / 2 }
        var bntOffset: UInt64 { UInt64(bntStartSector) * 512 }
        var clusterAreaOffset: UInt64 { UInt64(clusterAreaStartSector) * 512 }

        /// cluster → byte offset in image (0-based, verified vs EmaxIIFileSystem.swift):
        ///   cluster 0 → ca_off               (e.g. STEEL DRUMS on HD0.hda)
        ///   cluster 1 → ca_off + 1*cs
        ///   cluster n → ca_off + n*cs
        func clusterOffset(_ cluster: Int) -> UInt64 {
            clusterAreaOffset + UInt64(cluster) * UInt64(clusterSize)
        }
    }

    /// Parse disk geometry from header
    private static func parseGeometry(header: Data, fileSize: UInt64) throws -> DiskGeometry {
        guard header.count >= 40 else { throw ImportError.imageTooSmall }
        guard String(data: header[0..<4], encoding: .ascii) == "EMX2" else {
            throw ImportError.notEmaxImage
        }

        // Cluster size from header[0x04]. Do NOT require % 512 == 0 — the EMAX II format
        // stores opaque values that may not be sector-aligned (96 MB → 196352, 962 MB → 1969408).
        // Trust header[0x04] when non-zero and within a sane range; fall back to geometric
        // computation only when it is absent (zero).
        let caStartSector = Int(header.readU32LE(at: 0x20))
        let totalClusters = Int(header.readU32LE(at: 0x24))
        let headerClusterSize = Int(header.readU32LE(at: 0x04))
        let clusterSize: Int
        if headerClusterSize > 0 && headerClusterSize <= 4_194_304 {
            clusterSize = headerClusterSize
        } else {
            let diskSizeSectors = Int(fileSize / 512)
            let sectorsPerCluster = totalClusters > 0
                ? max((diskSizeSectors - caStartSector) / totalClusters, 1)
                : 128
            clusterSize = sectorsPerCluster * 512
        }

        return DiskGeometry(
            clusterSize:            clusterSize,
            fatSectors:             header.readU32LE(at: 0x1C),
            bntStartSector:         header.readU32LE(at: 0x10),
            maxBanks:               Int(header.readU32LE(at: 0x14)),
            clusterAreaStartSector: header.readU32LE(at: 0x20),
            totalClusters:          totalClusters
        )
    }

    /// Import a single bank file (.EB2 or .raw) into an HD image
    static func importBank(eb2URL: URL, into imageURL: URL, allowDuplicate: Bool = false) throws -> ImportResult {

        // EB2 filename IS the bank name — EB2 data starts with EMAX-encoded bytes, not ASCII
        let bankData = try Data(contentsOf: eb2URL)
        guard bankData.count >= 512 else { throw ImportError.bankTooSmall }

        let bankName: String = {
            var name = eb2URL.deletingPathExtension().lastPathComponent
            // Truncate to 14 chars (EMAX II limit)
            if name.count > 14 { name = String(name.prefix(14)) }
            return name
        }()

        // Open image for update
        let handle = try FileHandle(forUpdating: imageURL)
        defer { handle.closeFile() }

        let fileSize = Int(handle.seekToEndOfFile())
        guard fileSize >= 0x2000 else { throw ImportError.imageTooSmall }

        // Parse header
        handle.seek(toFileOffset: 0)
        let headerData = handle.readData(ofLength: 512)
        let diskSize = try handle.seekToEnd()
        let geo = try parseGeometry(header: headerData, fileSize: diskSize)

        // Read FAT (always at 0x400)
        handle.seek(toFileOffset: geo.fatOffset)
        let fatData = handle.readData(ofLength: geo.fatSize)
        var fat = [UInt16]()
        fat.reserveCapacity(geo.fatEntryCount)
        for i in stride(from: 0, to: min(geo.fatSize, fatData.count), by: 2) {
            fat.append(fatData.readU16LE(at: i))
        }

        // --- Duplicate name check (before any allocation) ---
        // Read BNT early so we can reject duplicates without side effects.
        let bntTotalSizeEarly = Int(geo.clusterAreaStartSector - geo.bntStartSector) * 512
        handle.seek(toFileOffset: geo.bntOffset)
        let bntEarlyData = handle.readData(ofLength: bntTotalSizeEarly)
        let maxSlotsEarly = min(geo.maxBanks + 1, bntTotalSizeEarly / 32)
        for i in 1..<maxSlotsEarly {
            let start = i * 32, end = start + 32
            guard end <= bntEarlyData.count else { break }
            // Use subdata(in:) to get a properly re-indexed copy (Data slice indices are absolute).
            let entry = bntEarlyData.subdata(in: start..<end)
            guard !entry.allSatisfy({ $0 == 0x00 }) else { continue }
            let existingName = String(data: entry[0..<16], encoding: .ascii)?
                .trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? ""
            if existingName == bankName && !allowDuplicate {
                throw ImportError.duplicateBankName(bankName)
            }
        }

        // Calculate clusters needed
        let clustersNeeded = (bankData.count + geo.clusterSize - 1) / geo.clusterSize

        // Determine used clusters by scanning FAT for non-free entries.
        // Free = 0x0000, Used = anything else (0x7FFF, 0x8080, 0x8000, or next cluster index).
        // Scan from index 0 — cluster 0 may be used (e.g. STEEL DRUMS on HD0.hda).
        var usedClusters = Set<Int>()
        for i in 0..<fat.count {
            if fat[i] != 0x0000 {
                usedClusters.insert(i)
            }
        }

        // Find free clusters (0-based, skip any that are in-use per FAT)
        var freeClusters = [Int]()
        for i in 0..<min(fat.count, geo.totalClusters + 1) {
            if !usedClusters.contains(i) {
                freeClusters.append(i)
                if freeClusters.count >= clustersNeeded { break }
            }
        }

        guard freeClusters.count >= clustersNeeded else {
            let totalFree = (0..<min(fat.count, geo.totalClusters + 1))
                .filter { fat[$0] == 0x0000 }.count
            throw ImportError.noFreeSpace(needed: clustersNeeded, available: totalFree)
        }

        let allocated = Array(freeClusters.prefix(clustersNeeded))

        // Write bank data to clusters (0-based: cluster n → ca_off + n*cs)
        for (i, cluster) in allocated.enumerated() {
            let dataStart = i * geo.clusterSize
            let dataEnd   = min(dataStart + geo.clusterSize, bankData.count)
            let chunk     = bankData[dataStart..<dataEnd]

            handle.seek(toFileOffset: geo.clusterOffset(cluster))
            handle.write(chunk)

            let remaining = geo.clusterSize - chunk.count
            if remaining > 0 {
                handle.write(Data(count: remaining))
            }
        }

        // Update FAT chain — use 0x7FFF as end-of-chain (EMAX II hardware standard).
        // All readers (EmaxIIFileSystem.traceChain, BankExtractor, DiskInspectorService) expect 0x7FFF.
        for i in 0..<allocated.count {
            let cluster = allocated[i]
            fat[cluster] = i < allocated.count - 1
                ? UInt16(allocated[i + 1])
                : 0x7FFF  // end-of-chain
        }

        // Write updated FAT at 0x400
        var newFatData = Data(count: geo.fatSize)
        for i in 0..<fat.count {
            newFatData.writeU16LE(fat[i], at: i * 2)
        }
        handle.seek(toFileOffset: geo.fatOffset)
        handle.write(newFatData)

        // --- Find free BNT slot (32-byte entries, slot 0 = OS, skip it) ---
        let bntTotalSize = Int(geo.clusterAreaStartSector - geo.bntStartSector) * 512
        handle.seek(toFileOffset: geo.bntOffset)
        let bntData = handle.readData(ofLength: bntTotalSize)

        let maxSlots = min(geo.maxBanks + 1, bntTotalSize / 32)  // +1 for OS
        var slotIndex = -1
        for i in 1..<maxSlots {
            let start = i * 32
            let end   = start + 32
            guard end <= bntData.count else { break }
            let entry = bntData[start..<end]
            if entry.allSatisfy({ $0 == 0x00 }) {
                slotIndex = i
                break
            }
        }
        guard slotIndex >= 0 else { throw ImportError.noFreeBNTSlot }

        // --- Build 32-byte BNT entry ---
        var bntEntry = Data(count: 32)

        // [0-13]: name, ASCII, space-padded to 14 chars
        // [14-15]: 0x00 0x00 (null padding, not part of name)
        let paddedName = bankName.padding(toLength: 14, withPad: " ", startingAt: 0)
        let nameData   = (paddedName + "\0\0").data(using: .ascii) ?? Data(count: 16)
        bntEntry.replaceSubrange(0..<16, with: nameData.prefix(16))

        // BNT entry layout (verified vs EmaxIIFileSystem.swift and reference disk EmaxII-02.ez2):
        //   +00..+0F  name, ASCII, space/null padded to 16 bytes
        //   +10..+11  startCluster (U16 LE, 0-based cluster index)
        //   +12..+13  clusterCount (U16 LE, must match FAT chain length)
        //   +14..+15  numPresets   (U16 LE, set to 0 — EMAX II updates at load time)
        //   +16..+17  f22          (varies, set to 0 on import)
        //   +18..+19  bankIndex    (idx/preset address, set to 0 on import)
        //   +1A..+1B  flags = 0x0081 (active bank entry, ALWAYS)
        //   +1C..+1F  zeros

        // [16-17]: startCluster (0-based cluster index of first bank cluster)
        bntEntry.writeU16LE(UInt16(allocated[0]), at: 16)

        // [18-19]: clusterCount (must match FAT chain length)
        bntEntry.writeU16LE(UInt16(allocated.count), at: 18)

        // [20-21]: numPresets — set to 0 on import (EMAX II updates this field at load time)
        bntEntry.writeU16LE(0x0000, at: 20)

        // [22-23]: f22 — set to 0 on import
        bntEntry.writeU16LE(0x0000, at: 22)

        // [24-25]: bankIndex — set to 0 on import
        bntEntry.writeU16LE(0x0000, at: 24)

        // [26-27]: flags = 0x0081 (active entry, ALWAYS this value)
        bntEntry.writeU16LE(0x0081, at: 26)

        // [28-31]: zeros (already zeroed)

        // Write BNT entry
        let entryOffset = geo.bntOffset + UInt64(slotIndex * 32)
        handle.seek(toFileOffset: entryOffset)
        handle.write(bntEntry)

        handle.synchronizeFile()

        print("✅ Imported '\(bankName)': \(allocated.count) clusters (\(bankData.count) bytes) at BNT slot \(slotIndex), cluster \(allocated[0])")

        return ImportResult(
            bankName:     bankName,
            clustersUsed: allocated.count,
            sizeBytes:    bankData.count,
            catalogIndex: slotIndex
        )
    }

    /// Import multiple .EB2 files
    static func importBanks(
        eb2URLs: [URL],
        into imageURL: URL,
        allowDuplicates: Bool = false
    ) -> (results: [ImportResult], errors: [(URL, Error)]) {
        var results = [ImportResult]()
        var errors  = [(URL, Error)]()

        for url in eb2URLs {
            do {
                let result = try importBank(eb2URL: url, into: imageURL, allowDuplicate: allowDuplicates)
                results.append(result)
            } catch {
                errors.append((url, error))
            }
        }

        return (results, errors)
    }

    /// Free-space info for an image
    static func freeSpaceInfo(imageURL: URL) -> (freeClusters: Int, clusterSize: Int, freeBytes: Int)? {
        guard let handle = try? FileHandle(forReadingFrom: imageURL) else { return nil }
        defer { handle.closeFile() }

        handle.seek(toFileOffset: 0)
        let header = handle.readData(ofLength: 512)
        guard let fileSize = try? handle.seekToEnd() else { return nil }
        guard let geo = try? parseGeometry(header: header, fileSize: fileSize) else { return nil }

        handle.seek(toFileOffset: geo.fatOffset)
        let fatData = handle.readData(ofLength: geo.fatSize)

        var fatArr = [UInt16]()
        for i in stride(from: 0, to: min(geo.fatSize, fatData.count), by: 2) {
            fatArr.append(fatData.readU16LE(at: i))
        }

        var freeCount = 0
        for i in 0..<min(fatArr.count, geo.totalClusters + 1) {
            if fatArr[i] == 0x0000 { freeCount += 1 }
        }

        return (freeCount, geo.clusterSize, freeCount * geo.clusterSize)
    }
}

// MARK: - Data helpers

private extension Data {
    func readU16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return withUnsafeBytes { $0.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt16.self) }
    }

    func readU32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return withUnsafeBytes { $0.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt32.self) }
    }

    mutating func writeU16LE(_ value: UInt16, at offset: Int) {
        self[offset]     = UInt8(value & 0xFF)
        self[offset + 1] = UInt8(value >> 8)
    }
}
