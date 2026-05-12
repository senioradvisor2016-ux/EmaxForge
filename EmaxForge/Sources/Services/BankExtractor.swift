import Foundation

/// Extract banks from existing EMAX II disk images (.EZ2/.HDA)
///
/// Disk layout (verified against working disk, Mar 18 2026):
///   BNT: at sector header[0x10]*512 (NOT hardcoded 0x1000!)
///   FAT: ALWAYS at 0x400
///   Cluster offset: ca_off + cluster * clusterSize  (0-based, verified vs EmaxIIFileSystem.swift)
struct BankExtractor {

    struct ExtractedBank {
        let name: String
        let data: Data
        let clusterCount: Int
    }

    enum ExtractionError: Error {
        case invalidDisk(String)
        case bankNotFound(String)
        case readError(String)
    }

    /// Extract all banks from a disk image
    /// Fast BNT-only scan — reads header (512B) + BNT (< 3KB). No FAT or cluster data.
    static func countBanks(in imageURL: URL) throws -> (count: Int, names: [String]) {
        guard let handle = try? FileHandle(forReadingFrom: imageURL) else {
            throw ExtractionError.invalidDisk("Cannot open disk image")
        }
        defer { try? handle.close() }
        
        handle.seek(toFileOffset: 0)
        let headerData = handle.readData(ofLength: 512)
        guard headerData.count == 512,
              String(data: headerData[0..<4], encoding: .ascii) == "EMX2" else {
            throw ExtractionError.invalidDisk("Not an EMAX II image")
        }
        
        let bntStartSector = headerData.readU32LE(at: 0x10)
        let maxBanks       = Int(headerData.readU32LE(at: 0x14))
        let caStartSector  = headerData.readU32LE(at: 0x20)
        
        let bntOffset  = UInt64(bntStartSector) * 512
        let bntSize    = Int(caStartSector - bntStartSector) * 512
        let maxEntries = min(maxBanks + 1, bntSize / 32)
        
        handle.seek(toFileOffset: bntOffset)
        let bntData = handle.readData(ofLength: bntSize)
        
        var names = [String]()
        for i in 1..<maxEntries {  // Skip slot 0 (OS)
            let off = i * 32
            guard off + 32 <= bntData.count else { break }
            let entry = bntData[off..<(off + 32)]
            guard !entry.allSatisfy({ $0 == 0x00 }) else { continue }
            let flags = entry.readU16LE(at: 26)
            guard flags == 0x0081 else { continue }
            let name = String(data: bntData[off..<(off + 14)], encoding: .ascii)?
                .trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? ""
            names.append(name)
        }
        return (names.count, names)
    }
    
    static func extractAllBanks(from imageURL: URL) throws -> [ExtractedBank] {
        guard let handle = try? FileHandle(forReadingFrom: imageURL) else {
            throw ExtractionError.invalidDisk("Cannot open disk image")
        }
        defer { try? handle.close() }

        // --- Parse header ---
        handle.seek(toFileOffset: 0)
        let headerData = handle.readData(ofLength: 512)
        guard headerData.count == 512 else {
            throw ExtractionError.invalidDisk("Cannot read header")
        }

        let magic = String(data: headerData[0..<4], encoding: .ascii) ?? ""
        guard magic == "EMX2" else {
            throw ExtractionError.invalidDisk("Not an EMAX II image (missing EMX2)")
        }

        // Cluster size from header[0x04]. Do NOT require % 512 == 0 — the EMAX II format
        // stores opaque byte-count values that may not be sector-aligned (e.g. 96 MB → 196352,
        // % 512 = 256; 962 MB → 1969408, % 512 = 256). Trust if non-zero and ≤ 4 MB.
        let rawCS = Int(headerData.readU32LE(at: 0x04))
        guard rawCS > 0 && rawCS <= 4_194_304 else {
            throw ExtractionError.invalidDisk("Invalid cluster size in header: \(rawCS)")
        }
        let clusterSize     = rawCS
        let bntStartSector  = headerData.readU32LE(at: 0x10)
        let maxBanks        = Int(headerData.readU32LE(at: 0x14))
        let fatSectors      = Int(headerData.readU32LE(at: 0x1C))
        let caStartSector   = headerData.readU32LE(at: 0x20)
        let totalClusters   = Int(headerData.readU32LE(at: 0x24))

        let bntOffset = UInt64(bntStartSector) * 512
        let caOffset  = UInt64(caStartSector) * 512

        // --- Read FAT (always at 0x400) ---
        let fatSize = fatSectors * 512
        handle.seek(toFileOffset: 0x400)
        let fatData = handle.readData(ofLength: fatSize)
        var fat = [UInt16]()
        fat.reserveCapacity(fatSize / 2)
        for i in stride(from: 0, to: fatData.count, by: 2) {
            fat.append(fatData.readU16LE(at: i))
        }

        // --- Read BNT (from header-specified sector, NOT 0x1000) ---
        let bntTotalSize = Int(caStartSector - bntStartSector) * 512
        handle.seek(toFileOffset: bntOffset)
        let bntData = handle.readData(ofLength: bntTotalSize)

        let maxEntries = min(maxBanks + 1, bntTotalSize / 32)  // +1 for OS slot 0
        var banks = [ExtractedBank]()

        for i in 1..<maxEntries {  // Skip slot 0 (OS)
            let entryStart = i * 32
            guard entryStart + 32 <= bntData.count else { break }
            // Copy to a zero-based Data so subscript offsets are always relative
            let entry = Data(bntData[entryStart..<(entryStart + 32)])

            // Skip empty / deleted slots
            guard !entry.allSatisfy({ $0 == 0x00 || $0 == 0xFF }) else { continue }

            // flags must be 0x0081  (+1A..+1B = offset 26)
            let flags = entry.readU16LE(at: 26)
            guard flags == 0x0081 else { continue }

            // BNT entry layout (verified vs BANK_HANDLING_ANALYSIS.md + analyze_image.swift):
            //   +00..+0F  name (16 bytes ASCII, space/null padded)
            //   +10..+11  bankIndex    (U16 LE)  — 0x7800=OS, (n-1)*256 user banks
            //   +12..+13  startCluster (U16 LE)  — actual FAT cluster (what EMAX II reads)
            //   +14..+15  numPresets   (U16 LE)  — offset 20
            //   +18..+19  fieldB       (U16 LE)  — offset 24 (unknown)
            //   +1A..+1B  flags = 0x0081          — offset 26
            let nameData = Data(entry[0..<16])
            let name = String(data: nameData, encoding: .ascii)?
                .trimmingCharacters(in: CharacterSet(charactersIn: " \0"))
                ?? ""
            guard !name.isEmpty else { continue }

            let bankIndex   = Int(entry.readU16LE(at: 16))  // +10: bankIndex
            let startCluster = Int(entry.readU16LE(at: 18)) // +12: actual FAT start cluster

            // Skip OS entry (bankIndex=0x7800) — OS is not an extractable bank
            if bankIndex == 0x7800 { continue }
            guard startCluster > 0, startCluster < totalClusters else { continue }

            // Follow FAT chain to determine actual cluster list
            var chain = [Int]()
            var cur = startCluster
            while cur > 0, cur < fat.count, chain.count <= totalClusters {
                chain.append(cur)
                let next = Int(fat[cur])
                if next == 0x7FFF { break }  // standard EOC
                if next == 0x8080 { break }  // compat EOC
                if next == 0x8000 { break }  // reserved
                if next == 0x0000 { break }  // free — chain broken
                if next == cur   { break }  // self-loop guard
                cur = next
            }

            guard !chain.isEmpty else { continue }

            // Read bank data via FAT chain
            var bankData = Data()
            bankData.reserveCapacity(chain.count * clusterSize)

            let readChain = chain

            for cluster in readChain {
                // 0-based cluster addressing (verified against EmaxIIFileSystem.swift):
                // cluster n → caOffset + n * clusterSize
                let offset = caOffset + UInt64(cluster) * UInt64(clusterSize)
                handle.seek(toFileOffset: offset)
                guard let chunkData = try? handle.read(upToCount: clusterSize),
                      chunkData.count == clusterSize else {
                    print("⚠️  Read error for bank '\(name)' cluster \(cluster)")
                    break
                }
                bankData.append(chunkData)
            }

            guard !bankData.isEmpty else { continue }

            banks.append(ExtractedBank(
                name:         name,
                data:         bankData,
                clusterCount: readChain.count
            ))
            print("📦 Extracted: \(name) (\(bankData.count / 1024) KB, \(readChain.count) clusters)")
        }

        return banks
    }

    /// Extract a single bank by name
    static func extractBank(named bankName: String, from imageURL: URL) throws -> ExtractedBank {
        let allBanks = try extractAllBanks(from: imageURL)
        guard let bank = allBanks.first(where: {
            $0.name.lowercased() == bankName.lowercased()
        }) else {
            throw ExtractionError.bankNotFound(bankName)
        }
        return bank
    }

    /// Save extracted bank to .EB2 file
    static func saveBankToFile(bank: ExtractedBank, outputURL: URL) throws {
        try bank.data.write(to: outputURL)
        print("💾 Saved: \(bank.name) → \(outputURL.path)")
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
