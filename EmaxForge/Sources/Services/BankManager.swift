import Foundation

/// Manage banks on EMAX-II disk images (delete, rename, export, info)
///
/// Verified disk layout (Mar 18 2026):
///   FAT:     ALWAYS at 0x400
///   BNT:     sector header[0x10]*512 (32-byte entries, NOT 64!)
///   Clusters: 0-based — cluster n → ca_off + n * clusterSize  (verified vs EmaxIIFileSystem.swift)
class BankManager {
    
    enum BankError: Error, LocalizedError {
        case diskReadFailed
        case diskWriteFailed
        case invalidDiskStructure
        case bankNotFound
        case diskFull
        case operationFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .diskReadFailed:       return "Failed to read disk image"
            case .diskWriteFailed:      return "Failed to write disk image"
            case .invalidDiskStructure: return "Invalid disk structure"
            case .bankNotFound:         return "Bank not found on disk"
            case .diskFull:             return "Disk is full"
            case .operationFailed(let msg): return "Operation failed: \(msg)"
            }
        }
    }
    
    /// Parsed geometry from header
    private struct Geo {
        let clusterSize: Int
        let bntStartSector: Int
        let maxBanks: Int
        let fatSectors: Int
        let caStartSector: Int
        let totalClusters: Int
        
        var fatOffset: Int { 0x400 }   // ALWAYS
        var fatSize: Int { fatSectors * 512 }
        var bntOffset: Int { bntStartSector * 512 }
        var bntSize: Int { (caStartSector - bntStartSector) * 512 }
        var caOffset: Int { caStartSector * 512 }
        var maxSlots: Int { min(maxBanks + 1, bntSize / 32) }
        
        /// 0-based: cluster n → caOffset + n*clusterSize  (verified vs EmaxIIFileSystem.swift)
        func clusterOffset(_ cluster: Int) -> Int {
            caOffset + cluster * clusterSize
        }
    }
    
    private static func parseGeo(from data: Data) throws -> Geo {
        guard data.count >= 0x28 else { throw BankError.invalidDiskStructure }
        let magic = String(data: data[0..<4], encoding: .ascii) ?? ""
        guard magic == "EMX2" else { throw BankError.invalidDiskStructure }

        // Cluster size from header[0x04]. Do NOT require % 512 == 0 — the EMAX II format
        // stores opaque byte-count values that may not be sector-aligned (e.g. 96 MB → 196352,
        // % 512 = 256; 962 MB → 1969408, % 512 = 256). Trust if non-zero and ≤ 4 MB.
        let rawCS = Int(data.readU32LE(at: 0x04))
        guard rawCS > 0 && rawCS <= 4_194_304 else {
            throw BankError.operationFailed("Invalid cluster size in header: \(rawCS)")
        }
        return Geo(
            clusterSize:    rawCS,
            bntStartSector: Int(data.readU32LE(at: 0x10)),
            maxBanks:       Int(data.readU32LE(at: 0x14)),
            fatSectors:     Int(data.readU32LE(at: 0x1C)),
            caStartSector:  Int(data.readU32LE(at: 0x20)),
            totalClusters:  Int(data.readU32LE(at: 0x24))
        )
    }
    
    /// Find a bank's BNT slot index by name; returns (slotIndex, startCluster, clusterCount)
    private static func findBank(named bankName: String, in data: Data, geo: Geo) -> (slot: Int, cluster: Int, count: Int)? {
        for i in 1..<geo.maxSlots {  // Skip slot 0 (OS)
            let off = geo.bntOffset + (i * 32)
            guard off + 32 <= data.count else { break }
            
            let entry = data[off..<(off + 32)]
            if entry.allSatisfy({ $0 == 0x00 }) { continue }
            
            let name = String(data: data[off..<(off + 14)], encoding: .ascii)?
                .trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? ""
            
            if name.lowercased() == bankName.lowercased() ||
               name.contains(bankName) || bankName.contains(name) {
                // BNT layout (verified vs BANK_HANDLING_ANALYSIS.md):
                //   +0x10 (offset 16): bankIndex (0x7800=OS, (n-1)*256 user)
                //   +0x12 (offset 18): startCluster — actual FAT cluster
                let cl  = Int(data.readU16LE(at: off + 18))  // startCluster at +0x12
                // Determine chain length by tracing FAT
                var cnt = 0
                var cur = cl
                var seen = Set<Int>()
                while cur > 0 && cur < data.count / 2 {
                    guard !seen.contains(cur) else { break }
                    seen.insert(cur)
                    let nxt = Int(data.readU16LE(at: geo.fatOffset + cur * 2))
                    cnt += 1
                    if nxt == 0x7FFF || nxt == 0x8080 || nxt == 0x8000 || nxt == 0 { break }
                    cur = nxt
                }
                return (i, cl, max(cnt, 1))
            }
        }
        return nil
    }
    
    // MARK: - Delete Bank
    
    static func deleteBank(entry: BankCatalogEntry, from diskURL: URL) throws {
        try deleteBank(named: entry.name, from: diskURL)
    }
    
    static func deleteBank(named bankName: String, from diskURL: URL) throws {
        var diskData = try Data(contentsOf: diskURL)
        let geo = try parseGeo(from: diskData)
        
        guard let found = findBank(named: bankName, in: diskData, geo: geo) else {
            throw BankError.bankNotFound
        }
        
        print("🗑️  Deleting bank '\(bankName)' at slot \(found.slot), cluster \(found.cluster)")
        
        // Free FAT chain (cluster 0 is valid — 0-based addressing)
        var currentCluster = found.cluster
        var freedClusters = 0
        var visited = Set<Int>()

        while currentCluster >= 0 && currentCluster < geo.fatSize / 2 {
            guard !visited.contains(currentCluster) else {
                print("⚠️  FAT loop at cluster \(currentCluster)")
                break
            }
            visited.insert(currentCluster)
            
            let fatOff = geo.fatOffset + (currentCluster * 2)
            let next = Int(diskData.readU16LE(at: fatOff))
            
            // Clear FAT entry
            diskData[fatOff] = 0x00
            diskData[fatOff + 1] = 0x00
            freedClusters += 1
            
            if next == 0x7FFF || next == 0x8080 || next == 0xFFFF || next == 0x0000 { break }
            currentCluster = next
        }

        // Clear BNT entry (32 bytes)
        let entryOffset = geo.bntOffset + (found.slot * 32)
        let zeroes = Data(count: 32)
        diskData.replaceSubrange(entryOffset..<(entryOffset + 32), with: zeroes)
        
        try diskData.write(to: diskURL)
        print("✅ Deleted '\(bankName)': freed \(freedClusters) clusters")
    }
    
    // MARK: - Rename Bank
    
    static func renameBank(from oldName: String, to newName: String, on diskURL: URL) throws {
        var diskData = try Data(contentsOf: diskURL)
        let geo = try parseGeo(from: diskData)
        
        guard newName.count <= 14 else {
            throw BankError.operationFailed("Name too long (max 14 characters)")
        }
        
        guard let found = findBank(named: oldName, in: diskData, geo: geo) else {
            throw BankError.bankNotFound
        }
        
        // Update name in BNT entry (14 chars, space-padded + 2 null)
        let entryOffset = geo.bntOffset + (found.slot * 32)
        let paddedName = newName.padding(toLength: 14, withPad: " ", startingAt: 0)
        guard let nameData = (paddedName + "\0\0").data(using: .ascii) else {
            throw BankError.operationFailed("Invalid characters in name")
        }
        diskData.replaceSubrange(entryOffset..<(entryOffset + 16), with: nameData.prefix(16))
        
        try diskData.write(to: diskURL)
        print("✅ Renamed '\(oldName)' → '\(newName)'")
    }
    
    // MARK: - Export Bank
    
    static func exportBank(
        entry: BankCatalogEntry,
        from diskURL: URL,
        to outputURL: URL,
        clusterSize: Int,
        clusterAreaStartSector: UInt32
    ) throws {
        let diskData = try Data(contentsOf: diskURL)
        let geo = try parseGeo(from: diskData)
        
        print("📦 Exporting '\(entry.name)' (cluster \(entry.startCluster))")
        
        // Follow FAT chain
        var currentCluster = Int(entry.startCluster)
        var bankData = Data()
        var visited = Set<Int>()
        
        // Cluster 0 is valid — 0-based addressing
        while currentCluster >= 0 && currentCluster < geo.fatSize / 2 {
            guard !visited.contains(currentCluster) else {
                throw BankError.operationFailed("FAT chain loop at cluster \(currentCluster)")
            }
            visited.insert(currentCluster)
            
            // 0-based: cluster n → caOffset + n×clusterSize (via geo.clusterOffset)
            let clusterOff = geo.clusterOffset(currentCluster)
            guard clusterOff + geo.clusterSize <= diskData.count else {
                throw BankError.operationFailed("Cluster \(currentCluster) out of bounds")
            }
            
            bankData.append(diskData[clusterOff..<(clusterOff + geo.clusterSize)])
            
            let fatOff = geo.fatOffset + (currentCluster * 2)
            let next = Int(diskData.readU16LE(at: fatOff))
            if next == 0x7FFF || next == 0x8080 || next == 0xFFFF { break }
            if next == 0x0000 { break }
            currentCluster = next
        }

        // Trim trailing zeros (sector-aligned)
        var trimmedSize = bankData.count
        while trimmedSize > 0 && bankData[trimmedSize - 1] == 0 { trimmedSize -= 1 }
        trimmedSize = ((trimmedSize + 511) / 512) * 512
        
        try bankData.prefix(trimmedSize).write(to: outputURL)
        print("✅ Exported → \(outputURL.lastPathComponent) (\(trimmedSize) bytes)")
    }
    
    // MARK: - Copy Bank
    
    static func copyBank(
        entry: BankCatalogEntry,
        sourceImageURL: URL,
        destinationImageURL: URL,
        clusterSize: Int,
        clusterAreaStartSector: UInt32
    ) throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempEB2 = tempDir.appendingPathComponent("\(UUID().uuidString).EB2")
        defer { try? FileManager.default.removeItem(at: tempEB2) }
        
        try exportBank(entry: entry, from: sourceImageURL, to: tempEB2,
                       clusterSize: clusterSize, clusterAreaStartSector: clusterAreaStartSector)
        _ = try BankImporter.importBank(eb2URL: tempEB2, into: destinationImageURL)
    }
    
    // MARK: - Defragment
    
    /// Defragment disk: repack all banks into contiguous clusters starting at 0.
    /// Returns number of clusters compacted (moved).
    /// Algorithm:
    ///   1. Read all bank data following FAT chains
    ///   2. Rewrite each bank's data into a fresh contiguous run of clusters
    ///   3. Rebuild FAT and BNT to match new layout
    static func defragmentDisk(at diskURL: URL) throws -> Int {
        var diskData = try Data(contentsOf: diskURL)
        let geo = try parseGeo(from: diskData)

        guard geo.clusterSize > 0 else {
            throw BankError.operationFailed("Invalid cluster size")
        }

        // --- 1. Collect all live banks (BNT scan) ---
        struct BankRecord {
            let slot:    Int
            let name:    String
            let data:    Data
            let count:   Int    // original cluster count
        }

        var banks: [BankRecord] = []

        for i in 1..<geo.maxSlots {
            let off = geo.bntOffset + i * 32
            guard off + 32 <= diskData.count else { break }

            let entry = diskData[off..<(off + 32)]
            guard !entry.allSatisfy({ $0 == 0x00 || $0 == 0xFF }) else { continue }

            let flags = diskData.readU16LE(at: off + 26)
            guard flags == 0x0081 else { continue }

            let nameRaw = String(data: diskData[off..<(off + 14)], encoding: .ascii) ?? ""
            let name = nameRaw.trimmingCharacters(in: .init(charactersIn: " \0"))
            guard !name.isEmpty else { continue }

            // BNT layout: bankIndex at +0x10 (offset 16), startCluster at +0x12 (offset 18)
            let bntBankIndex  = Int(diskData.readU16LE(at: off + 16))
            if bntBankIndex == 0x7800 { continue }  // skip OS entry
            let startCluster = Int(diskData.readU16LE(at: off + 18))  // +0x12: actual FAT cluster
            guard startCluster > 0 else { continue }

            // Follow FAT chain to read data
            var data = Data()
            var cur = startCluster
            var visited = Set<Int>()
            while cur >= 0 && cur < geo.fatSize / 2 {
                guard !visited.contains(cur) else { break }
                visited.insert(cur)
                let clOff = geo.clusterOffset(cur)
                guard clOff + geo.clusterSize <= diskData.count else { break }
                data.append(diskData[clOff..<(clOff + geo.clusterSize)])
                let fatOff = geo.fatOffset + cur * 2
                let next = Int(diskData.readU16LE(at: fatOff))
                if next == 0x7FFF || next == 0x8080 || next == 0xFFFF || next == 0x0000 { break }
                cur = next
            }

            banks.append(BankRecord(slot: i, name: name, data: data, count: visited.count))
        }

        // --- 2. Clear FAT, then restore reserved markers ---
        // FAT[0] = 0x8000 (reserved, never a real cluster)
        // FAT[1] = 0x7FFF (OS EOC — OS always lives at cluster 1, 0-based)
        let fatStart = geo.fatOffset
        let fatEnd   = min(fatStart + geo.fatSize, diskData.count)
        diskData.replaceSubrange(fatStart..<fatEnd, with: Data(count: fatEnd - fatStart))
        // Restore FAT[0] reserved marker and OS chain
        if fatStart + 4 <= diskData.count {
            diskData[fatStart + 0] = 0x00; diskData[fatStart + 1] = 0x80  // FAT[0] = 0x8000
            diskData[fatStart + 2] = 0xFF; diskData[fatStart + 3] = 0x7F  // FAT[1] = 0x7FFF (OS EOC)
        }

        // --- 3. Repack banks contiguously starting at cluster 2 ---
        // Cluster 0 is reserved (FAT[0] = 0x8000); cluster 1 is always the OS.
        // User banks start at cluster 2.
        var nextCluster = 2
        var totalMoved = 0

        for bank in banks {
            let clustersNeeded = (bank.data.count + geo.clusterSize - 1) / geo.clusterSize
            let oldStart = Int(diskData.readU16LE(at: geo.bntOffset + bank.slot * 32 + 16))
            let newStart = nextCluster

            // Write cluster data
            for c in 0..<clustersNeeded {
                let dst = geo.clusterOffset(newStart + c)
                guard dst + geo.clusterSize <= diskData.count else { break }
                let srcStart = c * geo.clusterSize
                let srcEnd   = min(srcStart + geo.clusterSize, bank.data.count)
                var chunk = Data(bank.data[srcStart..<srcEnd])
                if chunk.count < geo.clusterSize {
                    chunk.append(Data(count: geo.clusterSize - chunk.count))
                }
                diskData.replaceSubrange(dst..<(dst + geo.clusterSize), with: chunk)
            }

            // Write FAT chain
            for c in 0..<clustersNeeded {
                let cluster = newStart + c
                let fatOff  = geo.fatOffset + cluster * 2
                let nextVal: UInt16 = c < clustersNeeded - 1
                    ? UInt16(newStart + c + 1)
                    : 0x7FFF  // end-of-chain
                diskData[fatOff]     = UInt8(nextVal & 0xFF)
                diskData[fatOff + 1] = UInt8((nextVal >> 8) & 0xFF)
            }

            // Update BNT entry: startCluster at +0x12 (offset 18), bankIndex at +0x10 unchanged
            let bntOff = geo.bntOffset + bank.slot * 32
            // +0x10 (offset 16): bankIndex — preserved unchanged (don't overwrite)
            // +0x12 (offset 18): startCluster — update to new location after defrag
            diskData[bntOff + 18] = UInt8(newStart & 0xFF)
            diskData[bntOff + 19] = UInt8((newStart >> 8) & 0xFF)

            if newStart != oldStart { totalMoved += clustersNeeded }
            nextCluster += clustersNeeded

            print("🔧 Defrag: '\(bank.name)' → cluster \(newStart) (\(clustersNeeded) cluster(s))")
        }

        try diskData.write(to: diskURL)
        print("✅ Defragmentation complete: \(totalMoved) cluster(s) moved, \(nextCluster) cluster(s) used")
        return totalMoved
    }
    
    // MARK: - Disk Info
    
    struct DiskInfo {
        let totalSize: Int
        let usedSize: Int
        let freeSize: Int
        let bankCount: Int
        let fragmentedClusters: Int
    }
    
    static func getDiskInfo(for diskURL: URL) throws -> DiskInfo {
        let diskData = try Data(contentsOf: diskURL)
        let geo = try parseGeo(from: diskData)
        
        // Count used FAT entries
        var usedClusters = 0
        let fatEntries = geo.fatSize / 2
        for i in 0..<fatEntries {
            let off = geo.fatOffset + (i * 2)
            let entry = diskData.readU16LE(at: off)
            if entry != 0x0000 { usedClusters += 1 }
        }
        
        // Count banks from BNT (32-byte entries, skip slot 0 = OS)
        var bankCount = 0
        for i in 1..<geo.maxSlots {
            let off = geo.bntOffset + (i * 32)
            guard off + 32 <= diskData.count else { break }
            if diskData[off] == 0x00 || diskData[off] == 0xFF { continue }
            let flags = diskData.readU16LE(at: off + 26)
            if flags == 0x0081 { bankCount += 1 }
        }
        
        return DiskInfo(
            totalSize: geo.totalClusters * geo.clusterSize,
            usedSize: usedClusters * geo.clusterSize,
            freeSize: (geo.totalClusters - usedClusters) * geo.clusterSize,
            bankCount: bankCount,
            fragmentedClusters: 0
        )
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
}
