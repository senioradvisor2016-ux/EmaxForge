import Foundation

/// Ersätt ett sampels PCM-data i en bank, inklusive kluster-reallokering om nödvändigt.
///
/// Disk-layout (Ghidra-verifierad):
///   BankData-buffer: header(0x200) + presets(0x10000) + sampleParams(0x10200) + sampleData(0x20000+)
///   Sample param entry (64 bytes):
///     +0x00 startAddress (U32 LE) — offset relativt sampleData-area (0x20000)
///     +0x04 endAddress   (U32 LE)
///     +0x08 sampleRate   (U16 LE)
///     +0x0A originalKey  (U8)
///     +0x0B flags        (U8)
///     +0x0C sustainLoopStart (U32 LE)
///     +0x10 sustainLoopEnd   (U32 LE)
///     +0x14 releaseLoopStart (U32 LE)
///     +0x18 releaseLoopEnd   (U32 LE)
///     +0x1C loopFlags   (U8)
///     +0x20 name        (16 bytes, NUL-terminated)
///     +0x30 outputChannel (U8)
///
/// FAT-kluster: N (0-based) → caOffset + N×clusterSize  (verified vs EmaxIIFileSystem.swift)
/// FAT alltid på 0x400.
/// End-of-chain marker: 0x7FFF (EMAX II hardware standard; 0x8080 = compat EOC, handled in readers)
class PCMReallocator {

    struct ReplacementResult {
        let sampleIndex: Int
        let oldSizeBytes: Int
        let newSizeBytes: Int
        let clustersAdded: Int   // >0 om kedjan utökades
        let clustersFreed: Int   // >0 om kedjan kortades
    }

    enum ReplacementError: LocalizedError {
        case bankNotFound(String)
        case sampleIndexOutOfRange(Int)
        case invalidPCMData(String)
        case noFreeClusterSpace(needed: Int, available: Int)
        case readError(String)
        case writeError(String)

        var errorDescription: String? {
            switch self {
            case .bankNotFound(let s):      return "Bank not found: \(s)"
            case .sampleIndexOutOfRange(let i): return "Sample index out of range: \(i)"
            case .invalidPCMData(let s):    return "Invalid PCM data: \(s)"
            case .noFreeClusterSpace(let n, let a):
                return "No free cluster space: need \(n), available \(a)"
            case .readError(let s):         return "Read error: \(s)"
            case .writeError(let s):        return "Write error: \(s)"
            }
        }
    }

    // MARK: - Disk geometry (mirrors BankImporter.DiskGeometry)

    private struct DiskGeometry {
        let clusterSize: Int
        let fatSectors: Int
        let bntStartSector: UInt32
        let clusterAreaStartSector: UInt32
        let totalClusters: Int

        var fatOffset: UInt64 { 0x400 }
        var fatSize: Int { fatSectors * 512 }
        var fatEntryCount: Int { fatSize / 2 }
        var clusterAreaOffset: UInt64 { UInt64(clusterAreaStartSector) * 512 }
        var bntOffset: UInt64 { UInt64(bntStartSector) * 512 }

        /// 0-based cluster → byte offset in image  (verified vs EmaxIIFileSystem.swift)
        func clusterOffset(_ cluster: Int) -> UInt64 {
            clusterAreaOffset + UInt64(cluster) * UInt64(clusterSize)
        }
    }

    private static func parseGeometry(handle: FileHandle, fileSize: UInt64) throws -> DiskGeometry {
        handle.seek(toFileOffset: 0)
        let header = handle.readData(ofLength: 512)
        guard header.count == 512 else {
            throw ReplacementError.readError("Cannot read image header")
        }
        guard String(data: header[0..<4], encoding: .ascii) == "EMX2" else {
            throw ReplacementError.readError("Not an EMX2 image")
        }

        let caStartSector   = Int(header.readU32LE(at: 0x20))
        let totalClusters   = Int(header.readU32LE(at: 0x24))

        // Cluster size from header[0x04]. Do NOT require % 512 == 0 — the EMAX II format
        // stores opaque values that may not be sector-aligned (96 MB → 196352, 962 MB → 1969408).
        // Trust header[0x04] when non-zero and within a sane range; fall back to geometric
        // computation only when it is absent (zero).
        let headerCS = Int(header.readU32LE(at: 0x04))
        let clusterSize: Int
        if headerCS > 0 && headerCS <= 4_194_304 {
            clusterSize = headerCS
        } else {
            let diskSizeSectors   = Int(fileSize / 512)
            let sectorsPerCluster = totalClusters > 0
                ? max((diskSizeSectors - caStartSector) / totalClusters, 1)
                : 128
            clusterSize = sectorsPerCluster * 512
        }

        return DiskGeometry(
            clusterSize:            clusterSize,
            fatSectors:             Int(header.readU32LE(at: 0x1C)),
            bntStartSector:         header.readU32LE(at: 0x10),
            clusterAreaStartSector: header.readU32LE(at: 0x20),
            totalClusters:          totalClusters
        )
    }

    // MARK: - FAT helpers

    /// Läs hela FAT som [UInt16]-array
    private static func readFAT(handle: FileHandle, geo: DiskGeometry) -> [UInt16] {
        handle.seek(toFileOffset: geo.fatOffset)
        let fatData = handle.readData(ofLength: geo.fatSize)
        var fat = [UInt16]()
        fat.reserveCapacity(geo.fatEntryCount)
        for i in stride(from: 0, to: min(geo.fatSize, fatData.count), by: 2) {
            fat.append(fatData.readU16LE(at: i))
        }
        return fat
    }

    /// Skriv FAT tillbaka till 0x400
    private static func writeFAT(handle: FileHandle, geo: DiskGeometry, fat: [UInt16]) {
        var fatData = Data(count: geo.fatSize)
        for i in 0..<min(fat.count, geo.fatEntryCount) {
            fatData.writeU16LE(fat[i], at: i * 2)
        }
        handle.seek(toFileOffset: geo.fatOffset)
        handle.write(fatData)
    }

    /// Bygg kluster-kedja från startkluster
    private static func traceChain(fat: [UInt16], start: Int) -> [Int] {
        var chain = [start]
        var current = start
        var seen = Set([current])
        while current < fat.count {
            let next = Int(fat[current])
            if next == 0x7FFF || next == 0x8080 || next == 0x8000 || next == 0 { break }
            if seen.contains(next) { break }
            seen.insert(next)
            chain.append(next)
            current = next
        }
        return chain
    }

    // MARK: - Läs bankdata via kluster-kedja

    private static func readBankData(handle: FileHandle, geo: DiskGeometry, chain: [Int]) -> Data {
        var data = Data()
        data.reserveCapacity(chain.count * geo.clusterSize)
        for cluster in chain {
            handle.seek(toFileOffset: geo.clusterOffset(cluster))
            data.append(handle.readData(ofLength: geo.clusterSize))
        }
        return data
    }

    // MARK: - Skriv bankdata till kluster-kedja

    private static func writeBankData(
        handle: FileHandle,
        geo: DiskGeometry,
        chain: [Int],
        data: Data
    ) throws {
        guard !chain.isEmpty else {
            throw ReplacementError.writeError("Empty cluster chain")
        }
        var offset = 0
        for cluster in chain {
            handle.seek(toFileOffset: geo.clusterOffset(cluster))
            let end = min(offset + geo.clusterSize, data.count)
            if offset < end {
                handle.write(data[offset..<end])
            }
            let written = end - offset
            let padding = geo.clusterSize - written
            if padding > 0 {
                handle.write(Data(count: padding))
            }
            offset += geo.clusterSize
        }
    }

    // MARK: - BNT clusterCount uppdatering

    private static func updateBNTClusterCount(
        handle: FileHandle,
        geo: DiskGeometry,
        catalogIndex: Int,
        newCount: UInt16
    ) {
        // BNT entry layout: +0x10=startCluster, +0x12=clusterCount, +0x14=numPresets (verified)
        let entryOffset = geo.bntOffset + UInt64(catalogIndex * 32)
        handle.seek(toFileOffset: entryOffset + 18)   // +0x12 = clusterCount (NOT +0x14 which is numPresets)
        var countLE = newCount.littleEndian
        handle.write(Data(bytes: &countLE, count: 2))
    }

    // MARK: - Hitta lediga kluster i FAT

    private static func findFreeClusters(
        fat: [UInt16],
        totalClusters: Int,
        needed: Int,
        excluding: Set<Int> = []
    ) -> [Int] {
        var found = [Int]()
        for i in 1..<min(fat.count, totalClusters + 2) {
            if fat[i] == 0x0000 && !excluding.contains(i) {
                found.append(i)
                if found.count >= needed { break }
            }
        }
        return found
    }

    // MARK: - Huvud-API

    /// Ersätt PCM-data för ett specifikt sampel i en bank.
    ///
    /// - Parameter bankEntry: BankCatalogEntry från EmaxIIFileSystem
    /// - Parameter sampleIndex: 0-baserat index i bank (matchar SampleParameter-listan)
    /// - Parameter newPCM: råa 16-bit signed LE mono PCM-samples
    /// - Parameter imageURL: URL till HD-image (.hda / .ez2)
    static func replaceSamplePCM(
        bankEntry: BankCatalogEntry,
        sampleIndex: Int,
        newPCM: Data,
        imageURL: URL
    ) throws -> ReplacementResult {

        guard newPCM.count >= 2 else {
            throw ReplacementError.invalidPCMData("PCM data too short (< 2 bytes)")
        }
        // PCM ska vara jämnt antal bytes (16-bit samples)
        let newPCMAligned = newPCM.count % 2 == 0 ? newPCM : newPCM.dropLast(1)
        let newPCMSize = newPCMAligned.count

        // Öppna image för skrivning
        guard let handle = try? FileHandle(forUpdating: imageURL) else {
            throw ReplacementError.writeError("Cannot open image for update: \(imageURL.path)")
        }
        defer { handle.closeFile() }

        let fileSize = handle.seekToEndOfFile()
        let geo = try parseGeometry(handle: handle, fileSize: fileSize)

        // Läs FAT
        var fat = readFAT(handle: handle, geo: geo)

        // Hämta bankens kluster-kedja (använd BankCatalogEntry.clusterChain om tillgänglig,
        // annars spåra från FAT för att vara säker på att vi har aktuell kedja)
        let startCluster = Int(bankEntry.startCluster)
        guard startCluster > 0 && startCluster < fat.count else {
            throw ReplacementError.bankNotFound("Invalid startCluster \(startCluster) for bank '\(bankEntry.name)'")
        }
        let currentChain = traceChain(fat: fat, start: startCluster)
        guard !currentChain.isEmpty else {
            throw ReplacementError.bankNotFound("Empty FAT chain for bank '\(bankEntry.name)'")
        }

        // Läs hela bankdatan
        var bankData = readBankData(handle: handle, geo: geo, chain: currentChain)

        // Validera sampleIndex
        let paramBase = EmaxIIFormat.sampleParamOffset + sampleIndex * EmaxIIFormat.sampleParamSize
        guard paramBase + 8 <= bankData.count else {
            throw ReplacementError.sampleIndexOutOfRange(sampleIndex)
        }

        let oldStartRel = Int(bankData.readU32LE(at: paramBase + EmaxIIFormat.paramStartAddr))
        let oldEndRel   = Int(bankData.readU32LE(at: paramBase + EmaxIIFormat.paramEndAddr))

        guard oldEndRel > oldStartRel else {
            throw ReplacementError.invalidPCMData("Sample \(sampleIndex) has invalid start/end (start=\(oldStartRel), end=\(oldEndRel))")
        }
        let oldPCMSize = oldEndRel - oldStartRel

        // Absoluta positioner i bankData
        let pcmAreaStart = EmaxIIFormat.sampleDataOffset  // 0x20000
        let oldAbsStart  = pcmAreaStart + oldStartRel
        let oldAbsEnd    = pcmAreaStart + oldEndRel

        guard oldAbsEnd <= bankData.count else {
            throw ReplacementError.readError("Sample \(sampleIndex) PCM end (\(oldAbsEnd)) exceeds bankData size (\(bankData.count))")
        }

        // -- CASE 1: Samma storlek, in-place --
        if newPCMSize == oldPCMSize {
            bankData.replaceSubrange(oldAbsStart..<oldAbsEnd, with: newPCMAligned)
            try writeBankData(handle: handle, geo: geo, chain: currentChain, data: bankData)
            handle.synchronizeFile()
            return ReplacementResult(
                sampleIndex:    sampleIndex,
                oldSizeBytes:   oldPCMSize,
                newSizeBytes:   newPCMSize,
                clustersAdded:  0,
                clustersFreed:  0
            )
        }

        // -- CASE 2: Annan storlek, bygg ny bankData --
        let delta = newPCMSize - oldPCMSize

        // Bygg ny bankData: [0..<oldAbsStart] + newPCM + [oldAbsEnd..<bankData.count]
        var newBankData = Data()
        newBankData.reserveCapacity(bankData.count + delta)
        newBankData.append(bankData[0..<oldAbsStart])
        newBankData.append(contentsOf: newPCMAligned)
        newBankData.append(bankData[oldAbsEnd...])

        // Uppdatera detta sampels endAddress
        let newEndRel = oldStartRel + newPCMSize
        newBankData.writeU32LE(UInt32(newEndRel), at: paramBase + EmaxIIFormat.paramEndAddr)

        // Uppdatera ALLA efterföljande sampels start/end (om de har högre startAddress)
        // Scanna alla möjliga sampel-slots
        let numSamplesInHeader = min(
            Int(newBankData.readU16LE(at: EmaxIIFormat.numSamplesOffset)),
            EmaxIIFormat.maxSamples
        )
        let slotsToScan = max(numSamplesInHeader, sampleIndex + 32)  // generous upper bound

        for j in 0..<slotsToScan {
            guard j != sampleIndex else { continue }
            let jBase = EmaxIIFormat.sampleParamOffset + j * EmaxIIFormat.sampleParamSize
            guard jBase + 8 <= newBankData.count else { break }

            let jStart = Int(newBankData.readU32LE(at: jBase + EmaxIIFormat.paramStartAddr))
            let jEnd   = Int(newBankData.readU32LE(at: jBase + EmaxIIFormat.paramEndAddr))

            // Hoppa över tomma slots
            if jStart == 0 && jEnd == 0 { continue }
            guard jStart < jEnd else { continue }

            // Uppdatera om samplet ligger efter det ersatta (startAddress > oldStartRel)
            if jStart > oldStartRel {
                let newJStart = jStart + delta
                let newJEnd   = jEnd + delta
                newBankData.writeU32LE(UInt32(max(0, newJStart)), at: jBase + EmaxIIFormat.paramStartAddr)
                newBankData.writeU32LE(UInt32(max(0, newJEnd)),   at: jBase + EmaxIIFormat.paramEndAddr)
            }
        }

        // Beräkna nödvändigt antal kluster för nya bankdatan
        let clustersNeeded = (newBankData.count + geo.clusterSize - 1) / geo.clusterSize
        let currentClusterCount = currentChain.count

        var clustersAdded = 0
        var clustersFreed = 0
        var newChain = currentChain

        if clustersNeeded > currentClusterCount {
            // Behöver fler kluster
            let extra = clustersNeeded - currentClusterCount
            let currentSet = Set(currentChain)
            let freeList = findFreeClusters(
                fat: fat, totalClusters: geo.totalClusters,
                needed: extra, excluding: currentSet
            )
            guard freeList.count >= extra else {
                let totalFree = (1..<min(fat.count, geo.totalClusters + 2))
                    .filter { fat[$0] == 0x0000 && !currentSet.contains($0) }.count
                throw ReplacementError.noFreeClusterSpace(needed: extra, available: totalFree)
            }

            // Lägg till nya kluster i FAT-kedjan
            // Bryt nuvarande end-of-chain och fortsätt kedjan
            fat[currentChain.last!] = UInt16(freeList[0])
            for k in 0..<freeList.count {
                fat[freeList[k]] = k < freeList.count - 1
                    ? UInt16(freeList[k + 1])
                    : 0x7FFF   // end-of-chain (EMAX II hardware standard)
            }
            newChain = currentChain + freeList
            clustersAdded = freeList.count

        } else if clustersNeeded < currentClusterCount {
            // Frigör överskottskluster
            let keepChain  = Array(currentChain.prefix(clustersNeeded))
            let freeChain  = Array(currentChain.dropFirst(clustersNeeded))

            // Sätt ny end-of-chain på sista behållna klustret
            fat[keepChain.last!] = 0x7FFF   // end-of-chain (EMAX II hardware standard)
            // Frisätt övriga
            for cluster in freeChain {
                fat[cluster] = 0x0000
            }
            newChain = keepChain
            clustersFreed = freeChain.count
        }
        // Om clustersNeeded == currentClusterCount: ingen FAT-ändring nödvändig

        // Skriv FAT om den ändrats
        if clustersAdded > 0 || clustersFreed > 0 {
            writeFAT(handle: handle, geo: geo, fat: fat)
            // Uppdatera BNT clusterCount
            updateBNTClusterCount(
                handle: handle, geo: geo,
                catalogIndex: bankEntry.catalogIndex,
                newCount: UInt16(newChain.count)
            )
        }

        // Skriv ny bankdata
        try writeBankData(handle: handle, geo: geo, chain: newChain, data: newBankData)
        handle.synchronizeFile()

        print("PCMReallocator: sample \(sampleIndex) ersatt — \(oldPCMSize) → \(newPCMSize) bytes, " +
              "+\(clustersAdded)/-\(clustersFreed) kluster")

        return ReplacementResult(
            sampleIndex:   sampleIndex,
            oldSizeBytes:  oldPCMSize,
            newSizeBytes:  newPCMSize,
            clustersAdded: clustersAdded,
            clustersFreed: clustersFreed
        )
    }
}

// MARK: - Data helpers (privata för denna fil)

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
        guard offset + 2 <= count else { return }
        self[offset]     = UInt8(value & 0xFF)
        self[offset + 1] = UInt8(value >> 8)
    }

    mutating func writeU32LE(_ value: UInt32, at offset: Int) {
        guard offset + 4 <= count else { return }
        self[offset]     = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8)  & 0xFF)
        self[offset + 2] = UInt8((value >> 16) & 0xFF)
        self[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
}
