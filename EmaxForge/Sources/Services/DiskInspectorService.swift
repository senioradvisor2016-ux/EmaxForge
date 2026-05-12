import Foundation

// MARK: - Result Models

/// Complete inspection result for an EMAX II disk image (.hda / .ez2)
struct DiskInspection {
    let header: DiskHeaderInfo
    let fat: FATSummary
    let banks: [DiskBankInfo]
    let os: DiskOSInfo?
    let health: [DiskHealthWarning]
}

/// Parsed header fields from sector 0
struct DiskHeaderInfo {
    let magic: String               // "EMX2"
    let imageSize: Int              // File size in bytes
    let diskSizeSectors: Int        // Total sectors computed from file size
    let clusterSize: Int            // Bytes per cluster (computed, not from header[0x04])
    let totalClusters: Int          // header[0x24]
    let maxBanks: Int               // header[0x14]
    let bntOffset: UInt64           // byte offset of BNT area
    let fatOffset: UInt64           // always 0x400
    let clusterAreaStartSector: UInt32  // header[0x20]
    let bootSignature: (UInt8, UInt8)   // bytes at 0x1FE-0x1FF
}

/// FAT usage summary
struct FATSummary {
    let totalEntries: Int
    let usedClusters: Int
    let freeClusters: Int
    let reservedClusters: Int   // FAT entries with 0x8000 marker
}

/// Single bank entry parsed from the BNT catalog
struct DiskBankInfo {
    let catalogIndex: Int
    let name: String
    let startCluster: UInt16    // BNT +0x10 (0-based cluster index)
    let clusterCount: UInt16    // BNT +0x12 (stored hint; authoritative count = fatChain.count)
    let sizeBytes: Int          // fatChain.count * clusterSize
    let fatChain: [Int]         // Actual cluster chain traced from FAT
    let fatChainValid: Bool     // false if cycle / out-of-bounds / premature free
    let flags: UInt16           // BNT +0x1A (valid bank = 0x0081)
}

/// OS data found at FAT chain starting at cluster 1
struct DiskOSInfo {
    let versionString: String?  // ASCII version string found in OS data, if any
    let startCluster: Int       // First cluster (always 1)
    let clusterChain: [Int]     // Full cluster chain (1→2→3→4→...)
    let sizeBytes: Int          // clusterChain.count * clusterSize
}

/// Health issues detected during inspection
enum DiskHealthWarning: Equatable {
    case missingBootSignature               // Bytes at 0x1FE are both 0x00
    case brokenFATChain(bankName: String, startCluster: Int) // Cycle or invalid entry
    case orphanClusters([Int])              // Allocated in FAT but unreferenced
    case duplicateAllocations(clusters: [Int])  // Same cluster in multiple chains
}

// MARK: - Service

/// Analyzes EMAX II .hda / .ez2 disk images and returns structured inspection data.
///
/// Disk format constants verified against EmaxII-02.ez2 reference disk (Mar 21 2026):
///   Header:  sector 0 (0x000)
///   FAT:     always at 0x400, 2 bytes/cluster LE, 0x7FFF = EOC, 0x8000 = reserved
///   BNT:     sector header[0x10]*512, 32 bytes/entry
///   Clusters: sector header[0x20]*512
///
/// BNT entry layout (verified empirically against HD0.hda byte-level analysis, May 2026):
///   +0x00..+0x0F  name (16 bytes, ASCII, space/null padded)
///   +0x10..+0x11  startCluster (U16 LE, 0-based; 0x7800 = OS special marker)
///   +0x12..+0x13  clusterCount (U16 LE, stored hint; authoritative count comes from FAT chain)
///   +0x14..+0x15  numPresets   (U16 LE)
///   +0x16..+0x17  f22 (unknown, range 0-0x1FF)
///   +0x18..+0x19  bankIndex (idx, preset address)
///   +0x1A..+0x1B  flags (0x0081 = active user bank)
///   +0x1C..+0x1F  zeros
enum DiskInspectorService {

    // MARK: - Errors

    enum InspectionError: LocalizedError {
        case cannotOpenFile
        case fileTooSmall
        case invalidMagic(found: String)

        var errorDescription: String? {
            switch self {
            case .cannotOpenFile:
                return "Cannot open disk image for reading"
            case .fileTooSmall:
                return "File is too small to be a valid EMAX II image (minimum 8 KB)"
            case .invalidMagic(let found):
                return "Invalid magic '\(found)' — expected 'EMX2'"
            }
        }
    }

    // MARK: - Main entry point

    /// Inspect a disk image and return full structural analysis.
    /// - Parameter url: Path to .hda or .ez2 file
    /// - Returns: `DiskInspection` with header, FAT, banks, OS info, and health warnings
    static func inspectDisk(at url: URL) throws -> DiskInspection {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw InspectionError.cannotOpenFile
        }
        defer { try? handle.close() }

        let fileSize = Int((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0)
        guard fileSize >= 0x2000 else { throw InspectionError.fileTooSmall }

        // --- Read sector 0 (header, 512 bytes) ---
        try? handle.seek(toOffset: 0)
        guard let headerData = try? handle.read(upToCount: 512), headerData.count == 512 else {
            throw InspectionError.fileTooSmall
        }

        let magic = String(data: headerData[0..<4], encoding: .ascii) ?? ""
        guard magic == "EMX2" else { throw InspectionError.invalidMagic(found: magic) }

        // Parse header fields
        let bntStartSector  = Int(headerData.readU32LE(at: 0x10))
        let maxBanks        = Int(headerData.readU32LE(at: 0x14))
        let fatSectors      = Int(headerData.readU32LE(at: 0x1C))
        let caStartSector   = Int(headerData.readU32LE(at: 0x20))
        let totalClusters   = Int(headerData.readU32LE(at: 0x24))

        // Boot signature at 0x1FE-0x1FF
        let bootSig0 = headerData[0x1FE]
        let bootSig1 = headerData[0x1FF]

        // Cluster size: computed from actual file size (header[0x04] is disk size in sectors, not cluster size)
        let diskSizeSectors     = fileSize / 512
        let sectorsPerCluster   = totalClusters > 0 ? max((diskSizeSectors - caStartSector) / totalClusters, 1) : 128
        let clusterSize         = sectorsPerCluster * 512

        let fatOffset: UInt64   = 0x400
        let fatSize             = max(fatSectors * 512, 4)
        let bntOffset           = UInt64(bntStartSector) * 512

        let headerInfo = DiskHeaderInfo(
            magic:                  magic,
            imageSize:              fileSize,
            diskSizeSectors:        diskSizeSectors,
            clusterSize:            clusterSize,
            totalClusters:          totalClusters,
            maxBanks:               maxBanks,
            bntOffset:              bntOffset,
            fatOffset:              fatOffset,
            clusterAreaStartSector: UInt32(caStartSector),
            bootSignature:          (bootSig0, bootSig1)
        )

        // --- Read FAT (always at 0x400) ---
        try? handle.seek(toOffset: fatOffset)
        guard let fatData = try? handle.read(upToCount: fatSize), fatData.count >= 2 else {
            throw InspectionError.fileTooSmall
        }

        var fat = [UInt16]()
        fat.reserveCapacity(fatData.count / 2)
        for i in stride(from: 0, through: fatData.count - 2, by: 2) {
            fat.append(fatData.readU16LE(at: i))
        }

        // --- Read BNT catalog ---
        let bntSize = max((caStartSector - bntStartSector) * 512, 0)
        try? handle.seek(toOffset: bntOffset)
        let catalogData = (bntSize > 0 ? (try? handle.read(upToCount: bntSize)) : nil) ?? Data()

        // --- Parse bank entries ---
        let maxSlots = min(maxBanks + 1, catalogData.count / 32)
        var bankInfos = [DiskBankInfo]()

        for i in 0..<maxSlots {
            let offset = i * 32
            guard offset + 32 <= catalogData.count else { break }
            let entry = Data(catalogData[offset..<(offset + 32)])

            let nameBytes = Data(entry[0..<16])
            if nameBytes.allSatisfy({ $0 == 0x00 }) { continue }
            if nameBytes.allSatisfy({ $0 == 0xFF }) { continue }

            let name = String(data: nameBytes, encoding: .ascii)?
                .trimmingCharacters(in: .controlCharacters)
                .trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? ""
            guard !name.isEmpty else { continue }

            // BNT offsets verified empirically against HD0.hda (May 2026) and EmaxIIFileSystem.swift:
            //   startCluster at +0x10 (offset 16) — 0x7800 = OS marker, 0x0000 = cluster 0 (STEEL DRUMS), etc.
            //   clusterCount at +0x12 (offset 18) — stored hint, FAT chain is authoritative
            let startCluster = entry.readU16LE(at: 16)  // +0x10
            if startCluster == 0xFFFF { continue }
            let clusterCount = entry.readU16LE(at: 18)  // +0x12
            let flags        = entry.readU16LE(at: 26)  // +0x1A

            let (chain, valid) = traceChainValidated(fat: fat, start: Int(startCluster))

            bankInfos.append(DiskBankInfo(
                catalogIndex:   i,
                name:           name,
                startCluster:   startCluster,
                clusterCount:   clusterCount,
                sizeBytes:      chain.count * clusterSize,
                fatChain:       chain,
                fatChainValid:  valid,
                flags:          flags
            ))
        }

        // --- OS info: FAT chain starting at cluster 1 ---
        let osChain = traceOSChain(fat: fat)
        var osVersionString: String? = nil

        if !osChain.isEmpty, clusterSize > 0 {
            let caByteOffset = UInt64(caStartSector) * 512
            let firstOSOffset = caByteOffset + UInt64(osChain[0]) * UInt64(clusterSize)
            try? handle.seek(toOffset: firstOSOffset)
            if let osData = try? handle.read(upToCount: min(clusterSize, 4096)) {
                osVersionString = extractOSVersionString(from: osData)
            }
        }

        let osInfo: DiskOSInfo? = osChain.isEmpty ? nil : DiskOSInfo(
            versionString: osVersionString,
            startCluster:  osChain[0],
            clusterChain:  osChain,
            sizeBytes:     osChain.count * clusterSize
        )

        // --- FAT summary ---
        let fatSummary = buildFATSummary(fat: fat)

        // --- Health warnings ---
        let warnings = computeHealthWarnings(
            bootSig: (bootSig0, bootSig1),
            banks:   bankInfos,
            osChain: osChain,
            fat:     fat
        )

        return DiskInspection(
            header: headerInfo,
            fat:    fatSummary,
            banks:  bankInfos,
            os:     osInfo,
            health: warnings
        )
    }

    // MARK: - FAT chain tracing

    /// Trace a FAT chain from `start`, returning (chain, isValid).
    /// `isValid` is false if a cycle, out-of-bounds entry, or unexpected 0x0000 is encountered.
    static func traceChainValidated(fat: [UInt16], start: Int) -> ([Int], Bool) {
        guard start > 0, start < fat.count else {
            return ([start], false)
        }
        var chain  = [start]
        var current = start
        var seen   = Set([current])
        var valid  = true

        while current < fat.count {
            let next = Int(fat[current])
            if next == 0x7FFF { break }          // normal end-of-chain
            if next == 0x8080 { break }          // compat EOC (old BankImporter format)
            if next == 0x0000 {                  // premature free cluster → broken
                valid = false; break
            }
            if seen.contains(next) { valid = false; break }
            if next >= fat.count   { valid = false; break }
            seen.insert(next)
            chain.append(next)
            current = next
        }
        return (chain, valid)
    }

    /// Trace the OS cluster chain (always starts at cluster 1).
    /// Returns empty if FAT[1] is free (0x0000) or reserved (0x8000).
    static func traceOSChain(fat: [UInt16]) -> [Int] {
        guard fat.count > 1 else { return [] }
        if fat[1] == 0x0000 || fat[1] == 0x8000 { return [] }

        var chain   = [1]
        var current = 1
        var seen    = Set([1])

        while current < fat.count {
            let next = Int(fat[current])
            if next == 0x7FFF || next == 0x8080 || next == 0x0000 || next == 0x8000 { break }
            if seen.contains(next) { break }
            seen.insert(next)
            chain.append(next)
            current = next
        }
        return chain
    }

    // MARK: - FAT summary

    private static func buildFATSummary(fat: [UInt16]) -> FATSummary {
        var used = 0, free = 0, reserved = 0
        for entry in fat {
            switch entry {
            case 0x0000: free     += 1
            case 0x8000: reserved += 1
            default:     used     += 1
            }
        }
        return FATSummary(
            totalEntries:     fat.count,
            usedClusters:     used,
            freeClusters:     free,
            reservedClusters: reserved
        )
    }

    // MARK: - Health warnings

    private static func computeHealthWarnings(
        bootSig: (UInt8, UInt8),
        banks:   [DiskBankInfo],
        osChain: [Int],
        fat:     [UInt16]
    ) -> [DiskHealthWarning] {
        var warnings = [DiskHealthWarning]()

        // 1. Missing boot signature
        if bootSig.0 == 0x00 && bootSig.1 == 0x00 {
            warnings.append(.missingBootSignature)
        }

        // 2. Broken FAT chains
        for bank in banks where !bank.fatChainValid {
            warnings.append(.brokenFATChain(bankName: bank.name, startCluster: Int(bank.startCluster)))
        }

        // 3. Orphan clusters: allocated in FAT but not referenced by any bank or OS
        var referenced = Set<Int>([0])  // cluster 0 always reserved
        for bank in banks { bank.fatChain.forEach { referenced.insert($0) } }
        osChain.forEach { referenced.insert($0) }

        var orphans = [Int]()
        for (i, entry) in fat.enumerated() {
            if entry != 0x0000 && entry != 0x8000 && !referenced.contains(i) {
                orphans.append(i)
            }
        }
        if !orphans.isEmpty { warnings.append(.orphanClusters(orphans)) }

        // 4. Duplicate allocations: same cluster referenced by multiple banks
        var ownerCount = [Int: Int]()
        for bank in banks {
            for cluster in bank.fatChain {
                ownerCount[cluster, default: 0] += 1
            }
        }
        let dupes = ownerCount.filter { $0.value > 1 }.map { $0.key }.sorted()
        if !dupes.isEmpty { warnings.append(.duplicateAllocations(clusters: dupes)) }

        return warnings
    }

    // MARK: - OS version string scan

    /// Scan the first kilobytes of OS cluster data for recognisable ASCII version markers.
    private static func extractOSVersionString(from data: Data) -> String? {
        var run = ""
        for i in 0..<min(data.count, 4096) {
            let b = data[i]
            if b >= 0x20 && b < 0x7F {
                run.append(Character(UnicodeScalar(b)))
            } else {
                if run.count >= 4 {
                    let t = run.trimmingCharacters(in: .whitespaces)
                    let startsWithVersion = t.hasPrefix("V") && t.count > 1 && t.dropFirst().first?.isNumber == true
                    if t.hasPrefix("EMAX") || t.hasPrefix("E-MU") || startsWithVersion {
                        return t
                    }
                }
                run = ""
            }
        }
        return nil
    }
}

// MARK: - Private Data helpers

private extension Data {
    func readU16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return withUnsafeBytes { buf in
            buf.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt16.self)
        }
    }

    func readU32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return withUnsafeBytes { buf in
            buf.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt32.self)
        }
    }
}
