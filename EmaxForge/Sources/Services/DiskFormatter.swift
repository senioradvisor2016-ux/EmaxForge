import Foundation

/// Format/wipe EMAX II disk images and physical volumes
///
/// Uses EMXP-verified templates for correct disk geometry per size.
/// Header layout (from EMXP analysis, Mar 18 2026):
///   0x04: clusterSize (bytes)
///   0x08: field08
///   0x0C: fatStartSector
///   0x10: bntStartSector
///   0x14: maxBanks
///   0x18: field18 (always 2)
///   0x1C: fatSectors
///   0x20: clusterAreaStartSector
///   0x24: totalClusters
class DiskFormatter {
    
    enum FormatterError: LocalizedError {
        case notEmaxImage
        case readError
        case writeError(String)
        case permissionDenied
        case volumeBusy
        case invalidVolume
        case unknownDiskSize(Int)
        
        var errorDescription: String? {
            switch self {
            case .notEmaxImage: return "Not a valid EMAX II image"
            case .readError: return "Could not read image file"
            case .writeError(let msg): return "Write error: \(msg)"
            case .permissionDenied: return "Permission denied (need admin rights)"
            case .volumeBusy: return "Volume is busy or mounted"
            case .invalidVolume: return "Invalid volume or disk identifier"
            case .unknownDiskSize(let mb): return "Unknown disk size: \(mb) MB"
            }
        }
    }
    
    /// EMXP-verified disk geometry per size
    private struct DiskTemplate {
        let clusterSize: Int
        let field08: UInt32
        let fatStartSector: UInt32
        let bntStartSector: UInt32
        let maxBanks: UInt32
        let field18: UInt32
        let fatSectors: UInt32
        let clusterAreaStartSector: UInt32
        let totalClusters: UInt32
        let bootSig: (UInt8, UInt8)
        
        var fatOffset: Int { 0x400 }  // FAT ALWAYS at sector 2 (verified all EMXP templates)
        var fatSize: Int { Int(fatSectors) * 512 }
        var bntOffset: Int { Int(bntStartSector) * 512 }
        var clusterAreaOffset: Int { Int(clusterAreaStartSector) * 512 }
    }
    
    /// Lookup table: EMXP-verified templates (extracted from EMXP v3.11 images)
    private static let templates: [Int: DiskTemplate] = [
        // 96 MB (100528128 bytes)
        96: DiskTemplate(
            clusterSize: 196352, field08: 8, fatStartSector: 1,
            bntStartSector: 9, maxBanks: 111, field18: 2, fatSectors: 6,
            clusterAreaStartSector: 120, totalClusters: 1533,
            bootSig: (0xA1, 0x93)
        ),
        // 239 MB (250398720 bytes)
        239: DiskTemplate(
            clusterSize: 489472, field08: 6, fatStartSector: 2,
            bntStartSector: 8, maxBanks: 90, field18: 2, fatSectors: 4,
            clusterAreaStartSector: 98, totalClusters: 955,
            bootSig: (0x78, 0x82)
        ),
        // 481 MB (503900160 bytes)
        481: DiskTemplate(
            clusterSize: 984576, field08: 3, fatStartSector: 3,
            bntStartSector: 9, maxBanks: 106, field18: 2, fatSectors: 4,
            clusterAreaStartSector: 115, totalClusters: 961,
            bootSig: (0x65, 0x9F)
        ),
        // 633 MB — verified from emax2_header_633.bin binary template (May 2026)
        // Previous values were interpolated (wrong). All fields now match the binary:
        //   clusterSize=1296384 (0x13C800), field08=7, fatStartSector=4, bntStartSector=11,
        //   maxBanks=140, field18=2, fatSectors=5, caStartSector=151, totalClusters=1265.
        633: DiskTemplate(
            clusterSize: 1296384, field08: 7, fatStartSector: 4,
            bntStartSector: 11, maxBanks: 140, field18: 2, fatSectors: 5,
            clusterAreaStartSector: 151, totalClusters: 1265,
            bootSig: (0x79, 0x24)
        ),
        // 962 MB (1007765504 bytes)
        962: DiskTemplate(
            clusterSize: 1969408, field08: 6, fatStartSector: 6,
            bntStartSector: 12, maxBanks: 151, field18: 2, fatSectors: 4,
            clusterAreaStartSector: 163, totalClusters: 961,
            bootSig: (0xD7, 0xAD)
        ),
    ]
    
    /// Find the closest template for a given image size
    private static func templateForSize(_ imageSize: Int) -> DiskTemplate? {
        let mb = imageSize / (1024 * 1024)
        // Try exact match first
        if let t = templates[mb] { return t }
        // Try common sizes (EMXP reports slightly different MB values)
        let sizes = [96, 239, 481, 633, 962]
        for s in sizes {
            if abs(mb - s) <= 5 { return templates[s] }
        }
        return nil
    }
    
    /// Find template from header's clusterSize field
    private static func templateFromHeader(_ header: Data) -> DiskTemplate? {
        guard header.count >= 40 else { return nil }
        let cs = header.readU32LE(at: 0x04)
        for (_, tmpl) in templates {
            if tmpl.clusterSize == Int(cs) { return tmpl }
        }
        return nil
    }
    
    struct FormatOptions {
        var keepOS: Bool = true
        var quickFormat: Bool = true
        var volumeLabel: String? = nil
    }
    
    // MARK: - Format HD Image
    
    /// Format an EMAX II .hda image (wipe banks, optionally keep OS)
    static func formatImage(at imageURL: URL, options: FormatOptions = FormatOptions()) throws {
        let handle = try FileHandle(forUpdating: imageURL)
        defer { handle.closeFile() }
        
        let fileSize = Int(handle.seekToEndOfFile())
        guard fileSize >= 0x2000 else { throw FormatterError.readError }
        
        // Read current header to get geometry
        handle.seek(toFileOffset: 0)
        let headerData = handle.readData(ofLength: 512)
        let magic = String(data: headerData[0..<4], encoding: .ascii) ?? ""
        guard magic == "EMX2" else { throw FormatterError.notEmaxImage }
        
        // Get template (from header or size)
        guard let tmpl = templateFromHeader(headerData) ?? templateForSize(fileSize) else {
            throw FormatterError.unknownDiskSize(fileSize / (1024 * 1024))
        }
        
        // Read OS data if preserving
        var osData: Data?
        if options.keepOS {
            // Read OS from cluster 1 (0-based: caOffset + 1 * clusterSize).
            // Verified against HD0.hda: FAT[1]=0x7FFF, OS data at caOffset+clusterSize.
            let clusterAreaStart = UInt64(tmpl.clusterAreaStartSector) * 512
            let osOffset = clusterAreaStart + UInt64(tmpl.clusterSize)  // cluster 1, 0-based
            handle.seek(toFileOffset: osOffset)
            let data = handle.readData(ofLength: tmpl.clusterSize)
            // Check if non-zero (OS present)
            if data.contains(where: { $0 != 0 }) {
                osData = data
            }
        }
        
        // Full format: zero everything first
        if !options.quickFormat {
            handle.seek(toFileOffset: 0)
            let zeroChunk = Data(count: 65536)
            var written = 0
            while written < fileSize {
                let chunk = min(65536, fileSize - written)
                handle.write(zeroChunk.prefix(chunk))
                written += chunk
            }
        }
        
        // Write correct header from template
        try writeFormattedStructure(handle: handle, template: tmpl, imageSize: fileSize, osData: osData)
        
        handle.synchronizeFile()
        
        // Auto-verify after format
        let verify = DiskVerifier.verify(imageURL: imageURL)
        if !verify.passed {
            print("⚠️ Post-format verification FAILED for \(imageURL.lastPathComponent):")
            for check in verify.checks where !check.passed {
                print("  ❌ \(check.name): \(check.detail)")
            }
            throw FormatterError.writeError("Verification failed: \(verify.summary)")
        }
        print("✅ Format complete: \(imageURL.lastPathComponent) [\(verify.summary)]")
    }
    
    private static func writeFormattedStructure(handle: FileHandle, template tmpl: DiskTemplate, imageSize: Int, osData: Data?) throws {
        // === Header (sector 0) ===
        var header = Data(count: 512)
        header[0...3] = Data([0x45, 0x4D, 0x58, 0x32])  // EMX2
        header.writeU32LE(UInt32(tmpl.clusterSize), at: 0x04)
        header.writeU32LE(tmpl.field08, at: 0x08)
        header.writeU32LE(tmpl.fatStartSector, at: 0x0C)
        header.writeU32LE(tmpl.bntStartSector, at: 0x10)
        header.writeU32LE(tmpl.maxBanks, at: 0x14)
        header.writeU32LE(tmpl.field18, at: 0x18)
        header.writeU32LE(tmpl.fatSectors, at: 0x1C)
        header.writeU32LE(tmpl.clusterAreaStartSector, at: 0x20)
        header.writeU32LE(tmpl.totalClusters, at: 0x24)
        
        handle.seek(toFileOffset: 0)
        handle.write(header)
        
        // === FAT (at fatStartSector) ===
        var fat = Data(count: tmpl.fatSize)
        // FAT[0] = 0x8000 (reserved)
        fat.writeU16LE(0x8000, at: 0)
        
        if osData != nil {
            // OS in cluster 1 (single cluster, end of chain)
            fat.writeU16LE(0x7FFF, at: 2)  // FAT[1] = end-of-chain
        }
        
        // Fill remaining with 0x0000 (free) — already zero from Data(count:)
        
        handle.seek(toFileOffset: UInt64(tmpl.fatOffset))
        handle.write(fat)
        
        // === BNT / Catalog (at bntStartSector) ===
        let bntSize = tmpl.clusterAreaOffset - tmpl.bntOffset
        var bnt = Data(count: bntSize)
        
        if osData != nil {
            // Entry 0: OS — BNT layout per EmaxIIFileSystem.swift (verified May 2026):
            //   [0-15]:  name (16 bytes)
            //   [16-17]: bankIndex = 0x7800 (OS special marker at +0x10)
            //   [18-19]: startCluster = 1 (OS is always at cluster 1, stored at +0x12)
            //   [20-21]: numPresets = 1 (from reference disks)
            //   [26-27]: flags = 0x0080 (EMXP standard for OS entry)
            let osName = "EMAX2 Software\0\0".data(using: .ascii)!  // 16 bytes
            bnt.replaceSubrange(0..<16, with: osName.prefix(16))
            bnt.writeU16LE(0x7800, at: 16) // OS special marker (not a cluster address)
            bnt.writeU16LE(1, at: 18)      // clusterCount = 1
            bnt.writeU16LE(1, at: 20)      // numPresets = 1
            bnt.writeU16LE(0x0080, at: 26) // flags (EMXP standard for OS)
        }
        
        // Fill unused BNT slots with 0x42 (EMXP convention, slots maxBanks+1 onwards)
        let firstFillSlot = Int(tmpl.maxBanks) + 1
        let maxSlots = bntSize / 32
        for slot in firstFillSlot..<maxSlots {
            let off = slot * 32
            if off + 32 <= bntSize {
                for b in off..<(off + 32) {
                    bnt[b] = 0x42
                }
            }
        }
        
        handle.seek(toFileOffset: UInt64(tmpl.bntOffset))
        handle.write(bnt)
        
        // === Write OS data to cluster 1 (0-based: ca_off + 1 * clusterSize) ===
        // OS occupies cluster 1 on all EMAX II disks (cluster 0 is reserved/first bank).
        // Verified against HD0.hda: OS FAT chain starts at FAT[1] = 0x7FFF.
        if let osData = osData {
            let clusterAreaStart = UInt64(tmpl.clusterAreaStartSector) * 512
            let cluster1Offset = clusterAreaStart + UInt64(tmpl.clusterSize)  // cluster 1, 0-based
            handle.seek(toFileOffset: cluster1Offset)
            handle.write(osData.prefix(tmpl.clusterSize))
        }
        
        // === Metadata area (between header and FAT, if space) ===
        // Some sizes have space at 0x200 for status area and at 0xC00 for metadata
        // Clear these areas
        if tmpl.fatOffset > 512 {
            let gapSize = tmpl.fatOffset - 512
            handle.seek(toFileOffset: 512)
            handle.write(Data(count: gapSize))
        }
        if tmpl.bntOffset > tmpl.fatOffset + tmpl.fatSize {
            let metaOffset = tmpl.fatOffset + tmpl.fatSize
            let metaSize = tmpl.bntOffset - metaOffset
            handle.seek(toFileOffset: UInt64(metaOffset))
            // Write "Designed by S&M" metadata (EMXP convention)
            var meta = Data(count: metaSize)
            if metaSize >= 32 {
                let designedBy = "Designed by S&M.@".data(using: .ascii)!
                meta.replaceSubrange(0..<min(designedBy.count, metaSize), with: designedBy.prefix(metaSize))
            }
            handle.write(meta)
        }
    }
    
    // MARK: - Format Physical Volume (SD/USB)
    
    /// Format a physical volume (SD card, USB drive) to FAT32
    /// ⚠️ DESTRUCTIVE - erases entire volume
    static func formatVolume(at volumeURL: URL, fileSystem: VolumeFileSystem = .fat32, volumeName: String = "ZULUSCI") throws {
        guard let bsdName = getBSDName(for: volumeURL) else {
            throw FormatterError.invalidVolume
        }
        
        let unmountResult = shell("diskutil unmountDisk \(bsdName)")
        guard unmountResult.status == 0 else {
            throw FormatterError.volumeBusy
        }
        
        let fsType = fileSystem == .fat32 ? "FAT32" : "ExFAT"
        let formatCmd = "diskutil eraseDisk \(fsType) \(volumeName) \(bsdName)"
        
        let result = shell(formatCmd)
        guard result.status == 0 else {
            throw FormatterError.writeError(result.output)
        }
    }
    
    enum VolumeFileSystem {
        case fat32
        case exfat
    }
    
    private static func getBSDName(for volumeURL: URL) -> String? {
        let result = shell("diskutil info '\(volumeURL.path)' | grep 'Device Node' | awk '{print $3}'")
        let bsdName = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return bsdName.isEmpty ? nil : bsdName
    }
    
    private static func shell(_ command: String) -> (output: String, status: Int32) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", command]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (output, task.terminationStatus)
        } catch {
            return ("", -1)
        }
    }
    
    // MARK: - Create Blank Floppy
    
    /// Create a blank EMAX I/II floppy disk image (.HFE format)
    static func createBlankFloppy(at destinationURL: URL, density: FloppyDensity = .doubleDensity) throws {
        var header = Data(count: 512)
        let sig = "HXCPICFE".data(using: .ascii)!
        header.replaceSubrange(0..<8, with: sig)
        header[8] = 0x00
        
        let numTracks: UInt16 = 80
        let numSides: UInt8 = 2
        header.writeU16LE(numTracks, at: 9)
        header[11] = numSides
        header[12] = 0x00  // ISOIBM_MFM
        
        let bitRate: UInt16 = density == .doubleDensity ? 250 : 500
        header.writeU16LE(bitRate, at: 14)
        header.writeU16LE(300, at: 16)
        header[18] = 0x07  // Generic SHUGART
        header.writeU16LE(0x0001, at: 20)
        header[22] = 0xFF
        
        FileManager.default.createFile(atPath: destinationURL.path, contents: header)
        
        let handle = try FileHandle(forUpdating: destinationURL)
        defer { handle.closeFile() }
        
        var trackTable = Data(count: 512)
        var currentOffset: UInt16 = 0x0001
        for _ in 0..<Int(numTracks) {
            trackTable.writeU16LE(currentOffset, at: Int(currentOffset) * 2)
            currentOffset += 1
        }
        
        handle.seek(toFileOffset: 0x200)
        handle.write(trackTable)
        
        let trackDataSize = density == .doubleDensity ? 6250 : 12500
        let totalTracks = Int(numTracks) * Int(numSides)
        let blankTrack = Data(count: trackDataSize)
        for _ in 0..<totalTracks {
            handle.write(blankTrack)
        }
        
        handle.synchronizeFile()
    }
    
    enum FloppyDensity {
        case singleDensity
        case doubleDensity
        case highDensity
    }
}

// MARK: - Data helpers

private extension Data {
    func readU32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return withUnsafeBytes { buf in
            buf.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt32.self)
        }
    }
    
    mutating func writeU16LE(_ value: UInt16, at offset: Int) {
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8(value >> 8)
    }
    
    mutating func writeU32LE(_ value: UInt32, at offset: Int) {
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8) & 0xFF)
        self[offset + 2] = UInt8((value >> 16) & 0xFF)
        self[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
}
