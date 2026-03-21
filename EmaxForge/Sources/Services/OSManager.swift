import Foundation

/// Manage EMAX-II operating system (.EMX files)
///
/// Disk layout (verified Mar 18 2026):
///   BNT: at sector header[0x10]*512 (32-byte entries)
///   FAT: ALWAYS at 0x400
///   Clusters: 1-based — cluster 1 = CA offset + 0
///   OS entry: BNT slot 0, idx=0x7800, start cluster=1
class OSManager {
    
    enum OSError: Error, LocalizedError {
        case diskReadFailed
        case diskWriteFailed
        case invalidDiskStructure
        case osNotFound
        case osReadFailed
        case osWriteFailed
        case invalidOSFile
        
        var errorDescription: String? {
            switch self {
            case .diskReadFailed:       return "Failed to read disk image"
            case .diskWriteFailed:      return "Failed to write disk image"
            case .invalidDiskStructure: return "Invalid disk structure"
            case .osNotFound:           return "Operating system not found on disk"
            case .osReadFailed:         return "Failed to read OS from disk"
            case .osWriteFailed:        return "Failed to write OS to disk"
            case .invalidOSFile:        return "Invalid .EMX file format"
            }
        }
    }
    
    struct OSInfo {
        let version: String
        let size: Int
        let location: String
    }
    
    /// Geometry parsed from header
    private struct DiskGeo {
        let clusterSize: Int
        let bntStartSector: Int
        let maxBanks: Int
        let clusterAreaStartSector: Int
        
        var bntOffset: Int { bntStartSector * 512 }
        var clusterAreaOffset: Int { clusterAreaStartSector * 512 }
        
        /// 1-based: cluster n → clusterAreaOffset + (n-1)*clusterSize
        func clusterOffset(_ cluster: Int) -> Int {
            clusterAreaOffset + (cluster - 1) * clusterSize
        }
    }
    
    private static func parseGeo(from data: Data, fileSize: UInt64) throws -> DiskGeo {
        guard data.count >= 0x28 else { throw OSError.invalidDiskStructure }
        let magic = String(data: data[0..<4], encoding: .ascii) ?? ""
        guard magic == "EMX2" else { throw OSError.invalidDiskStructure }
        
        // clusterSize computed from disk geometry (not stored at 0x04)
        let diskSizeSectors = Int(fileSize / 512)
        let caStartSector = Int(data.readU32LE(at: 0x20))
        let totalClusters = Int(data.readU32LE(at: 0x24))
        let sectorsPerCluster = totalClusters > 0 ? (diskSizeSectors - caStartSector) / totalClusters : 128
        let clusterSize = sectorsPerCluster * 512
        
        return DiskGeo(
            clusterSize:            clusterSize,
            bntStartSector:         Int(data.readU32LE(at: 0x10)),
            maxBanks:               Int(data.readU32LE(at: 0x14)),
            clusterAreaStartSector: caStartSector
        )
    }
    
    // MARK: - Extract OS
    
    static func extractOS(from diskURL: URL, to outputURL: URL) throws {
        let diskData = try Data(contentsOf: diskURL)
        let geo = try parseGeo(from: diskData, fileSize: UInt64(diskData.count))
        
        print("🔍 Searching for OS on disk...")
        
        // Check BNT for OS entry (32-byte entries)
        var osCluster: Int?
        var osClusters: Int = 1
        
        let maxSlots = min(geo.maxBanks + 1, (geo.clusterAreaOffset - geo.bntOffset) / 32)
        for i in 0..<maxSlots {
            let offset = geo.bntOffset + (i * 32)
            guard offset + 32 <= diskData.count else { break }
            let entry = diskData[offset..<(offset + 32)]
            
            let name = String(data: entry[offset..<(offset + 14)], encoding: .ascii)?
                .trimmingCharacters(in: .controlCharacters)
                .trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? ""
            
            if name.contains("EMAX2") || name.contains("Software") {
                osCluster = Int(entry.readU16LE(at: offset + 18))
                osClusters = Int(entry.readU16LE(at: offset + 20))
                if osClusters == 0 { osClusters = 1 }
                print("✅ Found OS catalog entry: '\(name)'")
                print("   Cluster: \(osCluster!), Size: \(osClusters) clusters")
                break
            }
        }
        
        // OS is always cluster 1 on working disks
        if osCluster == nil {
            print("⚠️  OS not in catalog, assuming cluster 1")
            osCluster = 1
        }
        
        // Read OS data (1-based clusters)
        let osOffset = geo.clusterOffset(osCluster!)
        let totalOSBytes = osClusters * geo.clusterSize
        
        guard osOffset + totalOSBytes <= diskData.count else {
            throw OSError.osReadFailed
        }
        
        var osData = Data()
        for i in 0..<osClusters {
            let off = geo.clusterOffset(osCluster! + i)
            osData.append(diskData[off..<(off + geo.clusterSize)])
        }
        
        print("✅ Extracted \(osData.count) bytes (\(Double(osData.count) / 1024.0) KB)")
        
        // Trim trailing zeros, sector-aligned
        var trimmedSize = osData.count
        while trimmedSize > 0 && osData[trimmedSize - 1] == 0 {
            trimmedSize -= 1
        }
        trimmedSize = ((trimmedSize + 511) / 512) * 512
        
        let trimmedOS = osData.prefix(trimmedSize)
        print("✅ Trimmed to \(trimmedOS.count) bytes (\(Double(trimmedOS.count) / 1024.0) KB)")
        
        if trimmedOS.count >= 4 {
            let sig = String(format: "%02x %02x %02x %02x",
                             trimmedOS[0], trimmedOS[1], trimmedOS[2], trimmedOS[3])
            print("✅ OS signature: \(sig)")
        }
        
        try trimmedOS.write(to: outputURL)
        print("✅ Saved to \(outputURL.lastPathComponent)")
    }
    
    // MARK: - Install OS
    
    static func installOS(from emxURL: URL, to diskURL: URL) throws {
        var diskData = try Data(contentsOf: diskURL)
        let osData = try Data(contentsOf: emxURL)
        let geo = try parseGeo(from: diskData, fileSize: UInt64(diskData.count))
        
        guard osData.count >= 512 else { throw OSError.invalidOSFile }
        
        print("📦 Installing OS from \(emxURL.lastPathComponent)")
        print("   Size: \(osData.count) bytes (\(Double(osData.count) / 1024.0) KB)")
        
        // OS goes to cluster 1 (1-based: offset = clusterAreaOffset + 0)
        let osOffset = geo.clusterOffset(1)
        
        // Pad to full cluster
        var paddedOS = osData
        if paddedOS.count < geo.clusterSize {
            paddedOS.append(Data(count: geo.clusterSize - paddedOS.count))
        }
        
        // Write OS to cluster 1
        diskData.replaceSubrange(osOffset..<(osOffset + geo.clusterSize), with: paddedOS.prefix(geo.clusterSize))
        
        // Update FAT at 0x400: cluster 1 = 0x7FFF (end-of-chain, single cluster)
        let fatOffset = 0x400
        diskData[fatOffset + 2] = 0xFF  // FAT[1] low byte
        diskData[fatOffset + 3] = 0x7F  // FAT[1] high byte = 0x7FFF
        
        // Ensure BNT slot 0 has OS entry (32 bytes)
        let bntOffset = geo.bntOffset
        var osEntryExists = false
        
        let maxSlots = min(geo.maxBanks + 1, (geo.clusterAreaOffset - geo.bntOffset) / 32)
        for i in 0..<maxSlots {
            let off = bntOffset + (i * 32)
            guard off + 32 <= diskData.count else { break }
            let name = String(data: diskData[(off)..<(off + 14)], encoding: .ascii)?
                .trimmingCharacters(in: .controlCharacters)
                .trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? ""
            if name.contains("EMAX2") || name.contains("Software") {
                osEntryExists = true
                print("✅ OS catalog entry already exists")
                break
            }
        }
        
        if !osEntryExists {
            print("📝 Adding OS catalog entry at slot 0...")
            var entry = Data(count: 32)
            
            // Name: "EMAX2 Software" padded to 14 + 2 null
            let nameStr = "EMAX2 Software"
            let padded = nameStr.padding(toLength: 14, withPad: " ", startingAt: 0) + "\0\0"
            entry.replaceSubrange(0..<16, with: padded.data(using: .ascii)!)
            
            // BNT OS entry layout verified against EmaxII-02.ez2 (slot 16):
            //   +10..+11  startCluster = 0x7800 (OS special marker)
            //   +12..+13  clusterCount = 0x0001
            //   +14..+15  numPresets   = 0x0004 (from reference)
            //   +16..+17  f22          = 0x0078 (from reference)
            //   +18..+19  idx          = 0x0200 (from reference)
            //   +1A..+1B  flags        = 0x0081 (active entry)

            // startCluster = 0x7800 (OS marker)
            entry[16] = 0x00; entry[17] = 0x78
            
            // clusterCount = 1
            entry[18] = 0x01; entry[19] = 0x00
            
            // numPresets = 4 (from reference disk EmaxII-02.ez2)
            entry[20] = 0x04; entry[21] = 0x00
            
            // f22 = 0x0078 (from reference disk EmaxII-02.ez2)
            entry[22] = 0x78; entry[23] = 0x00
            
            // idx = 0x0200 (from reference disk EmaxII-02.ez2)
            entry[24] = 0x00; entry[25] = 0x02
            
            // flags = 0x0081 (active entry — 0x80=OS + 0x01=active)
            entry[26] = 0x81; entry[27] = 0x00
            
            diskData.replaceSubrange(bntOffset..<(bntOffset + 32), with: entry)
            print("✅ Added OS catalog entry at slot 0")
        }
        
        try diskData.write(to: diskURL)
        print("✅ OS installed successfully")
    }
    
    // MARK: - Identify OS
    
    static func identifyOS(on diskURL: URL) throws -> OSInfo {
        let diskData = try Data(contentsOf: diskURL)
        let geo = try parseGeo(from: diskData, fileSize: UInt64(diskData.count))
        
        // OS at cluster 1
        let osOffset = geo.clusterOffset(1)
        let readSize = min(4096, geo.clusterSize)
        guard osOffset + readSize <= diskData.count else { throw OSError.osReadFailed }
        
        let osData = diskData[osOffset..<(osOffset + readSize)]
        let osString = String(data: osData, encoding: .ascii) ?? ""
        
        var version = "Unknown"
        if osString.contains("2.14") { version = "2.14" }
        else if osString.contains("2.00") { version = "2.00" }
        else if osString.contains("2.10") { version = "2.10" }
        
        // Calculate OS size
        var osSize = geo.clusterSize
        for i in stride(from: geo.clusterSize - 1, through: 0, by: -1) {
            if diskData[osOffset + i] != 0 {
                osSize = ((i + 512) / 512) * 512
                break
            }
        }
        
        return OSInfo(version: version, size: osSize, location: "cluster 1")
    }
    
    // MARK: - Update OS
    
    static func updateOS(from emxURL: URL, on diskURLs: [URL]) throws -> Int {
        var successCount = 0
        print("🔄 Updating OS on \(diskURLs.count) disk(s)...\n")
        
        for (index, diskURL) in diskURLs.enumerated() {
            print("[\(index + 1)/\(diskURLs.count)] Updating \(diskURL.lastPathComponent)...")
            do {
                try installOS(from: emxURL, to: diskURL)
                successCount += 1
                print("✅ Success")
            } catch {
                print("❌ Failed: \(error.localizedDescription)")
            }
            print("")
        }
        return successCount
    }
}

// MARK: - Data helpers

private extension Data {
    func readU32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return withUnsafeBytes { $0.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt32.self) }
    }
    
    func readU16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return withUnsafeBytes { $0.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt16.self) }
    }
}
