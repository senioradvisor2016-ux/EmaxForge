import Foundation

/// Import .EB2 bank files into EMAX II HD images
///
/// Verified disk layout (from working disk analysis, Mar 21 2026):
///   Header:  sector 0 (0x000), 512 bytes
///   FAT:     ALWAYS at 0x400 (sector 2), size = header[0x1C] sectors
///   BNT:     sector header[0x10]*512, 32-byte entries, max header[0x14] banks
///   Clusters: sector header[0x20]*512, size computed from (diskSectors-caSector)/totalClusters
///
/// BNT entry layout (32 bytes) — VERIFIED byte-for-byte against EmaxII-02.ez2:
///   [0-13]:  name, ASCII space-padded to 14 chars
///   [14-15]: 0x00 0x00 (null padding)
///   [16-17]: idx (bank preset address, 0x0000 for bank 1, varies; set to 0 on import)
///   [18-19]: start cluster (LE, 0-based cluster number in cluster area)
///   [20-21]: cluster count (must match FAT chain length)
///   [22-23]: f22 (varies, set to 0 on import)
///   [24-25]: f24 (varies, set to 0 on import)
///   [26-27]: flags = 0x0081 (ALWAYS)
///   [28-31]: zeros
///
/// Cluster offset formula: ca_off + cluster * clusterSize  (0-based)
class BankImporter {

    enum ImportError: LocalizedError {
        case notEmaxImage
        case imageTooSmall
        case noFreeSpace(needed: Int, available: Int)
        case bankTooSmall
        case noFreeBNTSlot
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

        /// cluster → byte offset in image (0-based: cluster 0 = start of cluster area)
        /// Verified against EmaxII-02.ez2: ca_offset=0xF000, cluster_size=65536
        ///   cluster 0 → 0xF000 (reserved/BNT area overlap)
        ///   cluster 1 → 0x1F000 (OS data, cluster 1 in FAT chain)
        ///   cluster 5 → 0x5F000 (first bank, GUITAR/FLUTE)
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

        // clusterSize is NOT in header (0x04 = disk size in sectors).
        // Computed: (diskSizeSectors - caStartSector) / totalClusters * 512
        // Verified: EmaxII-02.ez2 = 64 KB/cluster, 239 MB = 256 KB/cluster
        let diskSizeSectors = Int(fileSize / 512)
        let caStartSector = Int(header.readU32LE(at: 0x20))
        let totalClusters = Int(header.readU32LE(at: 0x24))
        
        let sectorsPerCluster = totalClusters > 0 ? (diskSizeSectors - caStartSector) / totalClusters : 128
        let clusterSize = sectorsPerCluster * 512

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

        // Calculate clusters needed
        let clustersNeeded = (bankData.count + geo.clusterSize - 1) / geo.clusterSize

        // Determine OS clusters by following FAT chain from cluster 1
        // Cluster 0 is always reserved (BNT area), cluster 1+ are OS data clusters
        var osClusters = Set<Int>([0])
        var cur = 1
        while cur < fat.count && fat[cur] != 0x0000 && fat[cur] != 0x8000 {
            osClusters.insert(cur)
            let next = Int(fat[cur])
            if next == 0x7FFF { break }
            cur = next
        }
        if cur < fat.count { osClusters.insert(cur) }  // include last OS cluster

        // Find free clusters (skip reserved cluster 0 and all OS clusters)
        var freeClusters = [Int]()
        for i in 1..<min(fat.count, geo.totalClusters + 2) {
            if !osClusters.contains(i) && fat[i] == 0x0000 {
                freeClusters.append(i)
                if freeClusters.count >= clustersNeeded { break }
            }
        }

        guard freeClusters.count >= clustersNeeded else {
            let totalFree = (2..<min(fat.count, geo.totalClusters + 2))
                .filter { fat[$0] == 0x0000 }.count
            throw ImportError.noFreeSpace(needed: clustersNeeded, available: totalFree)
        }

        let allocated = Array(freeClusters.prefix(clustersNeeded))

        // Write bank data to clusters (1-based: cluster n → ca_off + (n-1)*cs)
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

        // Update FAT chain
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

        // BNT entry layout verified byte-for-byte against EmaxII-02.ez2:
        //   +00..+0D  name, ASCII, space-padded to 14 chars
        //   +0E..+0F  0x00 0x00  (null padding)
        //   +10..+11  idx — preset address table offset (0x0000 for bank 1, varies per content)
        //   +12..+13  start cluster (first cluster of bank data, 0-based)
        //   +14..+15  cluster count (number of clusters in FAT chain)
        //   +16..+17  f22 (varies, set to 0 on import)
        //   +18..+19  f24 (varies, set to 0 on import)
        //   +1A..+1B  flags = 0x0081 (active bank entry, ALWAYS)
        //   +1C..+1F  zeros

        // [16-17]: idx — set to 0 on import (actual value comes from bank preset data)
        bntEntry.writeU16LE(0x0000, at: 16)

        // [18-19]: start cluster (first cluster of bank data)
        bntEntry.writeU16LE(UInt16(allocated[0]), at: 18)

        // [20-21]: cluster count (must match FAT chain length)
        bntEntry.writeU16LE(UInt16(allocated.count), at: 20)

        // [22-23]: f22 — set to 0 on import
        bntEntry.writeU16LE(0x0000, at: 22)

        // [24-25]: f24 — set to 0 on import
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

        // Follow OS FAT chain from cluster 1, collect OS cluster indices
        var fatArr = [UInt16]()
        for i in stride(from: 0, to: min(geo.fatSize, fatData.count), by: 2) {
            fatArr.append(fatData.readU16LE(at: i))
        }
        var osSet = Set<Int>([0])
        var c = 1
        while c < fatArr.count && fatArr[c] != 0x0000 && fatArr[c] != 0x8000 {
            osSet.insert(c)
            let n = Int(fatArr[c])
            if n == 0x7FFF { break }
            c = n
        }
        if c < fatArr.count { osSet.insert(c) }

        var freeCount = 0
        for i in 1..<min(fatArr.count, geo.totalClusters + 2) {
            if !osSet.contains(i) && fatArr[i] == 0x0000 { freeCount += 1 }
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
