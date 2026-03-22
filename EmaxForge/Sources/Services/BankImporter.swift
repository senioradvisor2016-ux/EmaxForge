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
///   [22-23]: f22 (unknown EMAX II metadata; range 0-127; set to 0 on import — verified safe)
///   [24-25]: f24 (unknown EMAX II metadata; range 0-508; set to 0 on import — verified safe)
///   [26-27]: flags = 0x0081 (ALWAYS)
///   [28-31]: zeros
///
/// NOTE: f22/f24 are preserved when reading disks but written as 0x0000 on import.
/// Analysis (Mar 21 2026) shows no correlation to bank size, cluster count, or preset count.
/// Current hypothesis: EMAX II runtime metadata (caching hints) or EMXP-specific fields.
/// EmaxForge-created disks with f22=f24=0 work correctly — fields are not critical for boot/load.
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

        /// cluster → byte offset in image (1-based: cluster 1 = start of cluster area)
        /// Verified against EMXP emxp_base.hda (Mar 22 2026):
        ///   cluster 1 → ca (OS data)
        ///   cluster 2 → ca + 1*cs (first bank)
        ///   cluster 3 → ca + 2*cs (second bank or overflow)
        /// Formula: ca + (cluster - 1) * cs
        func clusterOffset(_ cluster: Int) -> UInt64 {
            clusterAreaOffset + UInt64(cluster - 1) * UInt64(clusterSize)
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

        // Determine used clusters by scanning FAT for non-free entries
        // Free = 0x0000, Used = anything else (0x7FFF, 0x8080, 0x8000, or next cluster index)
        var usedClusters = Set<Int>([0])  // cluster 0 always reserved
        for i in 1..<fat.count {
            if fat[i] != 0x0000 {
                usedClusters.insert(i)
            }
        }

        // Find free clusters (skip reserved and used)
        var freeClusters = [Int]()
        for i in 1..<min(fat.count, geo.totalClusters + 2) {
            if !usedClusters.contains(i) {
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

        // Update FAT chain — EMXP uses 0x8080 as end-of-chain marker (verified Mar 22 2026)
        for i in 0..<allocated.count {
            let cluster = allocated[i]
            fat[cluster] = i < allocated.count - 1
                ? UInt16(allocated[i + 1])
                : 0x8080  // end-of-chain (EMXP format)
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

        var fatArr = [UInt16]()
        for i in stride(from: 0, to: min(geo.fatSize, fatData.count), by: 2) {
            fatArr.append(fatData.readU16LE(at: i))
        }

        var freeCount = 0
        for i in 1..<min(fatArr.count, geo.totalClusters + 2) {
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
