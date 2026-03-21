import Foundation

/// Export banks from EMAX II disk images to .EB2 files
///
/// Verified disk layout (Mar 18 2026):
///   FAT:     ALWAYS at 0x400
///   BNT:     sector header[0x10]*512 (32-byte entries)
///   Clusters: 1-based — cluster n → ca_off + (n-1) * clusterSize
class BankExporter {
    
    struct ExportResult {
        let bankName: String
        let outputPath: URL
        let sizeBytes: Int
        let clustersUsed: Int
        let startCluster: Int
    }
    
    enum ExportError: LocalizedError {
        case notEmaxImage
        case bankNotFound(String)
        case readError(String)
        case writeError(String)
        
        var errorDescription: String? {
            switch self {
            case .notEmaxImage: return "Not a valid EMAX II image"
            case .bankNotFound(let name): return "Bank '\(name)' not found on disk"
            case .readError(let msg): return "Read error: \(msg)"
            case .writeError(let msg): return "Write error: \(msg)"
            }
        }
    }
    
    /// Export a single bank from disk image to .EB2 file
    static func exportBank(
        bankName: String,
        from imageURL: URL,
        to outputURL: URL
    ) throws -> ExportResult {
        let handle = try FileHandle(forReadingFrom: imageURL)
        defer { try? handle.close() }
        
        // --- Read header ---
        handle.seek(toFileOffset: 0)
        guard let headerData = try handle.read(upToCount: 512), headerData.count == 512 else {
            throw ExportError.readError("Could not read header")
        }
        
        let magic = String(data: headerData[0..<4], encoding: .ascii) ?? ""
        guard magic == "EMX2" else { throw ExportError.notEmaxImage }
        
        let clusterSize     = Int(headerData.readU32LE(at: 0x04))
        let bntStartSector  = Int(headerData.readU32LE(at: 0x10))
        let maxBanks        = Int(headerData.readU32LE(at: 0x14))
        let fatSectors      = Int(headerData.readU32LE(at: 0x1C))
        let caStartSector   = Int(headerData.readU32LE(at: 0x20))
        
        let bntOffset  = bntStartSector * 512
        let caOffset   = UInt64(caStartSector) * 512
        let fatSize    = fatSectors * 512
        let bntSize    = (caStartSector - bntStartSector) * 512
        
        // --- Read FAT (ALWAYS at 0x400) ---
        handle.seek(toFileOffset: 0x400)
        guard let fatData = try handle.read(upToCount: fatSize), fatData.count == fatSize else {
            throw ExportError.readError("Could not read FAT")
        }
        
        // --- Find bank in BNT (32-byte entries) ---
        handle.seek(toFileOffset: UInt64(bntOffset))
        guard let bntData = try handle.read(upToCount: bntSize) else {
            throw ExportError.readError("Could not read BNT")
        }
        
        var foundCluster: Int?
        var foundClusterCount: Int?
        let maxSlots = min(maxBanks + 1, bntSize / 32)
        
        for i in 0..<maxSlots {
            let off = i * 32
            guard off + 32 <= bntData.count else { break }
            let entry = bntData[off..<(off + 32)]
            
            // Skip empty/deleted
            if entry.allSatisfy({ $0 == 0x00 }) { continue }
            if entry.allSatisfy({ $0 == 0xFF }) { continue }
            
            // Check flags
            let flags = entry.readU16LE(at: 26)
            guard flags == 0x0081 else { continue }
            
            let name = String(data: entry[off..<(off + 14)], encoding: .ascii)?
                .trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? ""
            
            if name.lowercased() == bankName.lowercased() {
                foundCluster = Int(entry.readU16LE(at: 18))
                foundClusterCount = Int(entry.readU16LE(at: 20))
                break
            }
        }
        
        guard let startCluster = foundCluster, startCluster > 1 else {
            throw ExportError.bankNotFound(bankName)
        }
        
        // --- Follow FAT chain ---
        var clusters = [Int]()
        var current = startCluster
        let fatEntryCount = fatSize / 2
        
        while current > 0 && current < fatEntryCount && clusters.count < 10000 {
            clusters.append(current)
            
            let next = Int(fatData.readU16LE(at: current * 2))
            if next == 0x7FFF { break }  // end-of-chain
            if next == 0x8000 { break }  // reserved
            if next == 0x0000 { break }  // free (broken chain)
            if next == current { break }  // loop
            current = next
        }
        
        // Sanity check against BNT cluster count
        if let bntCount = foundClusterCount, bntCount > 0 && clusters.count != bntCount {
            print("⚠️  FAT chain (\(clusters.count)) != BNT f20 (\(bntCount)) for '\(bankName)'")
        }
        
        // --- Read bank data (1-based clusters) ---
        var bankData = Data()
        bankData.reserveCapacity(clusters.count * clusterSize)
        
        for cluster in clusters {
            // 1-based: cluster n → ca_off + (n-1) * clusterSize
            let offset = caOffset + UInt64(cluster - 1) * UInt64(clusterSize)
            handle.seek(toFileOffset: offset)
            guard let data = try handle.read(upToCount: clusterSize), data.count == clusterSize else {
                throw ExportError.readError("Failed to read cluster \(cluster)")
            }
            bankData.append(data)
        }
        
        // --- Write .EB2 file ---
        try bankData.write(to: outputURL)
        print("💾 Exported '\(bankName)': \(clusters.count) clusters, \(bankData.count) bytes → \(outputURL.lastPathComponent)")
        
        return ExportResult(
            bankName: bankName,
            outputPath: outputURL,
            sizeBytes: bankData.count,
            clustersUsed: clusters.count,
            startCluster: startCluster
        )
    }
    
    /// List all bank names on a disk image (for UI bank selection)
    static func listBanks(imageURL: URL) throws -> [String] {
        let handle = try FileHandle(forReadingFrom: imageURL)
        defer { try? handle.close() }
        
        handle.seek(toFileOffset: 0)
        guard let header = try handle.read(upToCount: 512), header.count >= 0x24 else {
            throw ExportError.readError("Cannot read header")
        }
        guard String(data: header[0..<4], encoding: .ascii) == "EMX2" else {
            throw ExportError.notEmaxImage
        }
        
        let bntStartSector = Int(header.readU32LE(at: 0x10))
        let maxBanks       = Int(header.readU32LE(at: 0x14))
        let caStartSector  = Int(header.readU32LE(at: 0x20))
        let bntOffset      = UInt64(bntStartSector * 512)
        let bntSize        = (caStartSector - bntStartSector) * 512
        let maxSlots       = min(maxBanks + 1, bntSize / 32)
        
        handle.seek(toFileOffset: bntOffset)
        guard let bntData = try handle.read(upToCount: bntSize) else {
            throw ExportError.readError("Cannot read BNT")
        }
        
        var names = [String]()
        for i in 1..<maxSlots {   // Skip slot 0 (OS)
            let off = i * 32
            guard off + 32 <= bntData.count else { break }
            if bntData[off] == 0x00 || bntData[off] == 0xFF { continue }
            let flags = bntData.readU16LE(at: off + 26)
            guard flags == 0x0081 else { continue }
            let name = String(data: bntData[off..<(off + 14)], encoding: .ascii)?
                .trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? ""
            if !name.isEmpty { names.append(name) }
        }
        return names
    }
    
    /// Export all banks from disk image
    static func exportAllBanks(from imageURL: URL, to outputDir: URL) throws -> [ExportResult] {
        // Use BankExtractor to get all banks, then save each
        let banks = try BankExtractor.extractAllBanks(from: imageURL)
        var results = [ExportResult]()
        
        for bank in banks {
            let outputURL = outputDir.appendingPathComponent(bank.name + ".EB2")
            try bank.data.write(to: outputURL)
            results.append(ExportResult(
                bankName: bank.name,
                outputPath: outputURL,
                sizeBytes: bank.data.count,
                clustersUsed: bank.clusterCount,
                startCluster: 0
            ))
            print("💾 Exported '\(bank.name)' → \(outputURL.lastPathComponent)")
        }
        
        return results
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
