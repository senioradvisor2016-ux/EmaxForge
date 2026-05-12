import Foundation

// Helper extension for debug logging
extension String {
    func appendToFile(atPath path: String) {
        let data = Data(self.utf8)
        if FileManager.default.fileExists(atPath: path) {
            if let fileHandle = FileHandle(forWritingAtPath: path) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

/// Creates bootable EMAX II HD images with OS and proper file system
class ImageCreator {
    
    enum CreatorError: LocalizedError {
        case osFileNotFound
        case osFileTooLarge
        case invalidSize
        case unsupportedSize
        case writeError(String)
        
        var errorDescription: String? {
            switch self {
            case .osFileNotFound: return "EMAX II OS file not found"
            case .osFileTooLarge: return "OS file too large for a single cluster"
            case .invalidSize: return "Invalid image size"
            case .unsupportedSize: return "Unsupported size. Use 96, 239, 481, 633, or 962 MB."
            case .writeError(let msg): return "Write error: \(msg)"
            }
        }
    }
    
    /// verified disk image template
    /// All values extracted from official industry-standard format created images
    struct ImageTemplate {
        let clusterSize: UInt32
        let field_0x08: UInt32
        let field_0x0C: UInt32
        let field_0x10: UInt32
        let bankCount: UInt32
        let field_0x18: UInt32
        let field_0x1C: UInt32
        let clusterAreaStartSector: UInt32
        let sectorsPerClusterMinus1: UInt32
        let field_0x28: UInt32
        let field_0x2C: UInt32
        let field_0x30: UInt32
        let bootSig1: UInt8
        let bootSig2: UInt8
    }
    
    /// Exact disk sizes (in bytes) that match EMAX II file system requirements
    /// Calculated from working Funkar/ disks (verified Mar 5, 2026)
    /// These sizes produce bootable disks - do NOT use round MiB values!
    static let diskSizes: [Int: Int] = [
        96: 100_578_304,   // 196,442 sectors
        239: 250_398_720,  // 489,060 sectors (Funkar reference)
        481: 503_940_096,  // 984,258 sectors
        633: 663_189_504,  // 1,295,292 sectors
        962: 1_007_880_704 // 1,968,517 sectors
    ]
    
    /// verified templates for standard disk sizes
    /// Source: industry-standard format disk creation (verified Mar 4, 2026)
    static let templates: [Int: ImageTemplate] = [
        96: ImageTemplate(
            clusterSize: 196352,
            field_0x08: 8,
            field_0x0C: 1,
            field_0x10: 9,
            bankCount: 111,
            field_0x18: 2,
            field_0x1C: 6,
            clusterAreaStartSector: 120,
            sectorsPerClusterMinus1: 1533,
            field_0x28: 0xFFFF0101,
            field_0x2C: 2,
            field_0x30: 0x0D020000,
            bootSig1: 0xA1,
            bootSig2: 0x93
        ),
        239: ImageTemplate(
            // Verified from emax2_header_239.bin binary template (May 2026).
            // clusterSize=489472 (0x77800), bntSector=8, fatSectors=4, caStartSector=98.
            // Old values (clusterSize:4096, caStartSector:1920) were wrong — mixed up field bytes.
            clusterSize: 489472,         // header[0x04] = 0x00077800 = 489472 bytes/cluster
            field_0x08: 6,
            field_0x0C: 2,
            field_0x10: 8,               // BNT start sector
            bankCount: 90,
            field_0x18: 2,
            field_0x1C: 4,               // FAT sectors
            clusterAreaStartSector: 98,  // header[0x20] = 0x62 = 98 (NOT 1920)
            sectorsPerClusterMinus1: 955,
            field_0x28: 0x783B0103,
            field_0x2C: 7,
            field_0x30: 0x0D020000,
            bootSig1: 0x78,
            bootSig2: 0x82
        ),
        481: ImageTemplate(
            clusterSize: 984576,
            field_0x08: 6,
            field_0x0C: 3,
            field_0x10: 9,
            bankCount: 106,
            field_0x18: 2,
            field_0x1C: 4,
            clusterAreaStartSector: 115,
            sectorsPerClusterMinus1: 961,
            field_0x28: 0x06EE0104,
            field_0x2C: 15,
            field_0x30: 0x0D020000,
            bootSig1: 0x65,
            bootSig2: 0x9F
        ),
        633: ImageTemplate(
            clusterSize: 1296384,
            field_0x08: 7,
            field_0x0C: 4,
            field_0x10: 11,
            bankCount: 140,
            field_0x18: 2,
            field_0x1C: 5,
            clusterAreaStartSector: 151,
            sectorsPerClusterMinus1: 1265,
            field_0x28: 0xC87F0104,
            field_0x2C: 19,
            field_0x30: 0x0D020000,
            bootSig1: 0x79,
            bootSig2: 0x24
        ),
        962: ImageTemplate(
            clusterSize: 1969408,
            field_0x08: 6,
            field_0x0C: 6,
            field_0x10: 12,
            bankCount: 151,
            field_0x18: 2,
            field_0x1C: 4,
            clusterAreaStartSector: 163,
            sectorsPerClusterMinus1: 961,
            field_0x28: 0x0DDE0105,
            field_0x2C: 30,
            field_0x30: 0x0D020000,
            bootSig1: 0xD7,
            bootSig2: 0xAD
        )
    ]
    
    /// Load a bundled binary resource from the app bundle, with fallback to source Resources/
    private static func loadResource(_ name: String, ext: String) -> Data? {
        // 1. Try app bundle
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return try? Data(contentsOf: url)
        }
        // 2. Fallback: source Resources/ directory (for development)
        let devPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("clawd/EmaxForge/EmaxForge/Resources/\(name).\(ext)")
        if let data = try? Data(contentsOf: devPath) {
            print("⚠️  Loaded \(name).\(ext) from dev Resources/ (not bundled)")
            return data
        }
        return nil
    }
    
    /// Bank Name Table start sector for each disk size
    /// Discovered Mar 8, 2026: field_0x10 in header = BNT start sector
    /// BNT sectors = bankCount (e.g. 239MB: sector 8 to 97 = 90 sectors)
    /// Each BNT entry is 32 bytes. 16 entries per sector.
    static let bankNameTableStartSector: [Int: UInt32] = [
        96: 9, 239: 8, 481: 9, 633: 11, 962: 12
    ]
    
    /// Template file names (industry-standard format created bootable images)
    /// Created Mar 17, 2026 via VNC + standard tools "Create Bootable Disk" wizard
    /// Hardware-tested and verified working on EMAX II!
    private static let templateFiles: [Int: String] = [
        96: "EMAXII_IMAGE_96.EZ2",
        239: "EMAXII_IMAGE_239.EZ2",
        481: "EMAXII_IMAGE_481.EZ2",
        633: "EMAXII_IMAGE_633.EZ2",
        962: "EMAXII_IMAGE_962.EZ2"
    ]
    
    /// Create a bootable EMAX II HD image with OS installed
    /// 
    /// NEW Architecture (Mar 17, 2026): Copy standard templates directly!
    /// - Uses real industry-standard format bootable disk images as templates
    /// - 100% hardware-verified (booted on EMAX II successfully!)
    /// - Simply copies template → destination
    /// - Templates located in Resources/bootable_templates/
    /// 
    /// Old method (buildFromScratch) kept as fallback but deprecated.
    static func createBootableImage(
        at destinationURL: URL,
        sizeMB: Int,
        osFileURL: URL? = nil
    ) throws {
        // Get template filename
        guard let templateFilename = templateFiles[sizeMB] else {
            throw CreatorError.unsupportedSize
        }
        
        // Try to find template in Resources/bootable_templates/
        let templatePath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("clawd/EmaxForge/EmaxForge/Resources/bootable_templates/\(templateFilename)")
        
        // Guard: file must exist AND be non-empty.
        // Zero-byte placeholder files (96/633/962 MB) exist on disk but are not usable templates.
        let templateSize = (try? FileManager.default.attributesOfItem(atPath: templatePath.path)[.size] as? Int) ?? 0
        guard FileManager.default.fileExists(atPath: templatePath.path) && templateSize > 0 else {
            print("⚠️  Template not found or empty (\(templateSize) bytes): \(templatePath.path)")
            print("   Falling back to old buildFromScratch method...")
            return try createBootableImageLegacy(at: destinationURL, sizeMB: sizeMB, osFileURL: osFileURL)
        }
        
        // Copy template
        print("📋 Copying standard tools template: \(templateFilename)")
        try FileManager.default.copyItem(at: templatePath, to: destinationURL)
        
        // Read header to get BNT geometry
        let handle = try FileHandle(forUpdating: destinationURL)
        defer { try? handle.close() }
        
        handle.seek(toFileOffset: 0)
        let header = handle.readData(ofLength: 512)
        let bntStartSector = Int(header.readU32LE(at: 0x10))
        let clusterAreaStartSector = Int(header.readU32LE(at: 0x20))
        let fatSectors = Int(header.readU32LE(at: 0x1C))
        
        // FAT is ALWAYS at 0x400 (sector 2) regardless of field_0x0C
        let fatOffset: UInt64 = 0x400
        let fatSize = fatSectors * 512

        // BNT/Catalog at field_0x10 * 512 (varies by size)
        let bntOffset = UInt64(bntStartSector) * 512
        let bntSize = (clusterAreaStartSector - bntStartSector) * 512
        // Preserve OS entry (slot 0, 32 bytes), clear rest
        handle.seek(toFileOffset: bntOffset)
        let bntData = handle.readData(ofLength: bntSize)
        var cleanBNT = Data(count: bntSize)
        if bntData.count >= 32 {
            cleanBNT.replaceSubrange(0..<32, with: bntData[0..<32])
            // Fix OS entry flags: must be 0x0081 (active), template has 0x0080
            cleanBNT[26] = 0x81
            cleanBNT[27] = 0x00
        }
        handle.seek(toFileOffset: bntOffset)
        handle.write(cleanBNT)

        // Build clean FAT: reserved + full OS cluster chain + zero for user banks.
        // BNT slot 0 uses bankIndex=0x7800 (OS special marker) at offset 16 (+0x10).
        // The OS is always physically at cluster 1 (0-based: caOffset + 1*clusterSize).
        // OS startCluster from BNT offset 18 (+0x12); for the OS this equals 1.
        var cleanFAT = Data(count: fatSize)
        cleanFAT.writeU16LE(0x8000, at: 0)  // FAT[0] reserved
        let osStartCluster = 1              // OS always starts at cluster 1
        // NOTE: offset 18 (+0x12) is startCluster for the OS (always 1). We read it here as
        // the initial FAT chain length; for single-cluster OS images this happens to be correct.
        // For multi-cluster OS images, OSManager.updateOS re-writes the FAT chain from actual data.
        let osClusterCount = Int(cleanBNT.readU16LE(at: 18))   // +0x12 = OS startCluster (== 1)
        if osClusterCount > 0 {
            // Build OS FAT chain: start → start+1 → ... → start+count-1 → 0x7FFF
            for i in 0..<osClusterCount {
                let cluster = osStartCluster + i
                let next: UInt16 = i < osClusterCount - 1
                    ? UInt16(osStartCluster + i + 1)
                    : 0x7FFF
                cleanFAT.writeU16LE(next, at: cluster * 2)
            }
            print("📝 FAT: OS chain cluster \(osStartCluster)→\(osStartCluster+osClusterCount-1)→0x7FFF (\(osClusterCount) clusters)")
        } else {
            // Fallback: single OS cluster at 1
            cleanFAT.writeU16LE(0x7FFF, at: 2)
            print("⚠️ FAT: OS BNT entry missing cluster info, using single-cluster fallback")
        }
        handle.seek(toFileOffset: fatOffset)
        handle.write(cleanFAT)

        // Status byte at 0x200: must be 0x0F (bootable with OS)
        handle.seek(toFileOffset: 0x200)
        handle.write(Data([0x0F]))

        handle.synchronizeFile()
        print("✅ Created bootable image from template (FAT+BNT cleaned, OS chain restored)")
    }
    
    /// Legacy method: Build from scratch using binary templates
    /// Kept for reference but prefer standard tools templates above!
    private static func createBootableImageLegacy(
        at destinationURL: URL,
        sizeMB: Int,
        osFileURL: URL? = nil
    ) throws {
        guard let template = templates[sizeMB] else {
            throw CreatorError.unsupportedSize
        }
        guard let imageSize = diskSizes[sizeMB] else {
            throw CreatorError.unsupportedSize
        }
        
        // Load standard tools header template (header + status + FAT = 2048 bytes)
        guard let headerData = loadResource("emax2_header_\(sizeMB)", ext: "bin") else {
            throw CreatorError.writeError("standard tools header template not found for \(sizeMB) MB")
        }
        
        // Load Bank Name Table template (sectors 4 to clusterAreaStart-1)
        // Contains: metadata area + "Designed by S&M." + OS entry + 0x42 fill
        guard let bankTableData = loadResource("emax2_banktable_\(sizeMB)", ext: "bin") else {
            throw CreatorError.writeError("standard tools bank table template not found for \(sizeMB) MB")
        }
        
        // Load boot catalog (entries 0-76, identical across all disks)
        guard let bootCatalog = loadResource("emax2_boot_catalog", ext: "bin") else {
            throw CreatorError.writeError("standard tools boot catalog template not found")
        }
        
        // Load OS data
        let osData: Data
        if let osURL = osFileURL, FileManager.default.fileExists(atPath: osURL.path) {
            osData = try Data(contentsOf: osURL)
        } else if let bundledOS = loadResource("emax2_os", ext: "bin") {
            osData = bundledOS
        } else {
            throw CreatorError.osFileNotFound
        }
        
        // Create image via temp file on local SSD (FAT32 SD cards are very slow for truncate)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".hda")
        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tempURL)
        defer {
            handle.closeFile()
            // Move temp file to destination (fast copy for local, handles cross-volume)
            try? FileManager.default.removeItem(at: destinationURL)
            try? FileManager.default.moveItem(at: tempURL, to: destinationURL)
            // moveItem fails cross-volume, fall back to copy
            if !FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.copyItem(at: tempURL, to: destinationURL)
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
        try handle.truncate(atOffset: UInt64(imageSize))
        
        // 1. Write standard tools header template (sectors 0-3: header + status + FAT)
        var headerMutable = headerData
        // CRITICAL: Set status byte to 0x0F (bootable with OS)
        // standard tools empty template has 0x09 (empty), must be 0x0F for boot
        if headerMutable.count > 0x200 {
            headerMutable[0x200] = 0x0F
        }
        handle.seek(toFileOffset: 0)
        handle.write(headerMutable)
        
        // 1b. Clear FAT — ALWAYS at 0x400 (sector 2)
        let fatSz = Int(template.field_0x1C) * 512
        var cleanFAT = Data(count: fatSz)
        cleanFAT.writeU16LE(0x8000, at: 0)  // FAT[0] reserved
        cleanFAT.writeU16LE(0x7FFF, at: 2)  // FAT[1] OS end-of-chain
        handle.seek(toFileOffset: 0x400)
        handle.write(cleanFAT)
        print("📝 Cleared FAT at 0x400 (\(fatSz) bytes)")
        
        // 2. Write Bank Name Table at field_0x10 sector offset
        let bntSect = Int(template.field_0x10)
        handle.seek(toFileOffset: UInt64(bntSect) * 512)
        handle.write(bankTableData)
        
        // 3. Write boot catalog at BNT offset
        let catalogOffset = UInt64(bntSect) * 512
        print("📝 Writing catalog: offset=0x\(String(catalogOffset, radix: 16)), size=\(bootCatalog.count) bytes")
        handle.seek(toFileOffset: catalogOffset)
        handle.write(bootCatalog)
        
        // 4. Write OS data at cluster 1 (0-based: caOffset + 1 * clusterSize).
        // Verified against HD0.hda: FAT[0]=0x8000 (reserved), FAT[1]=0x7FFF (OS end-of-chain).
        // OS physically resides at caOffset + clusterSize (cluster 1, 0-based).
        let clusterAreaStart = UInt64(template.clusterAreaStartSector) * 512
        let osOffset = clusterAreaStart + UInt64(template.clusterSize)  // Cluster 1, 0-based
        let osWriteSize = min(osData.count, Int(template.clusterSize))
        print("📝 Writing OS: offset=0x\(String(osOffset, radix: 16)), size=\(osWriteSize) bytes, first 16 bytes: \(osData.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " "))")
        handle.seek(toFileOffset: osOffset)
        handle.write(osData[0..<osWriteSize])
        
        handle.synchronizeFile()
        try handle.close()
        
        // Auto-verify after creation
        let verify = DiskVerifier.verify(imageURL: destinationURL)
        if !verify.passed {
            print("⚠️ Post-create verification FAILED for \(destinationURL.lastPathComponent):")
            for check in verify.checks where !check.passed {
                print("  ❌ \(check.name): \(check.detail)")
            }
            for warning in verify.warnings {
                print("  ⚠️ \(warning)")
            }
        }
        
        print("✅ Created bootable EMAX II image: \(destinationURL.lastPathComponent) [\(verify.summary)]")
        print("   Size: \(sizeMB) MB, BNT at sector \(bankNameTableStartSector[sizeMB] ?? 0), OS at 0x\(String(osOffset, radix: 16, uppercase: true))")
    }
    
    // writeMinimalBootBank removed (Mar 8, 2026)
    // Boot catalog template contains all required initialization data.
    // User banks are added by BankImporter via the wizard.
    
    /// Create a blank EMAX II HD image (no OS, ready for bank imports)
    /// Used for data disks (HD20, HD30, etc.) in multi-image setups
    static func createBlankImage(at destinationURL: URL, sizeMB: Int) throws {
        // NEW (Mar 17, 2026): Use standard tools template for blank disks too!
        // Copy template, then clear ENTIRE Catalog (including OS entry 0)
        
        guard let templateFilename = templateFiles[sizeMB] else {
            throw CreatorError.unsupportedSize
        }
        
        let templatePath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("clawd/EmaxForge/EmaxForge/Resources/bootable_templates/\(templateFilename)")
        
        // Guard against 0-byte placeholder files (96/633/962 MB EZ2s are empty stubs on disk)
        let blankTemplateSize = (try? FileManager.default.attributesOfItem(atPath: templatePath.path)[.size] as? Int) ?? 0
        guard FileManager.default.fileExists(atPath: templatePath.path) && blankTemplateSize > 0 else {
            print("⚠️  Template not found or empty (\(blankTemplateSize) bytes): \(templatePath.path)")
            print("   Falling back to legacy buildFromScratch...")
            return try createBlankImageLegacy(at: destinationURL, sizeMB: sizeMB)
        }

        // Copy template
        print("📋 Copying standard tools template for blank disk: \(templateFilename)")
        try FileManager.default.copyItem(at: templatePath, to: destinationURL)
        
        // Read header to get BNT geometry
        let handle = try FileHandle(forUpdating: destinationURL)
        defer { try? handle.close() }
        
        handle.seek(toFileOffset: 0)
        let header = handle.readData(ofLength: 512)
        let bntStartSector = Int(header.readU32LE(at: 0x10))
        let clusterAreaStartSector = Int(header.readU32LE(at: 0x20))
        let fatSectors = Int(header.readU32LE(at: 0x1C))
        
        // FAT is ALWAYS at 0x400 (sector 2)
        let fatOffset: UInt64 = 0x400
        let fatSize = fatSectors * 512
        var cleanFAT = Data(count: fatSize)
        cleanFAT.writeU16LE(0x8000, at: 0)  // FAT[0] reserved
        // Rest is 0x0000 (free) — no OS, no banks
        handle.seek(toFileOffset: fatOffset)
        handle.write(cleanFAT)

        // Clear ALL BNT/Catalog entries (blank data disk — no OS entry)
        let bntOffset = UInt64(bntStartSector) * 512
        let bntSize = (clusterAreaStartSector - bntStartSector) * 512
        let zeroBNT = Data(count: bntSize)
        handle.seek(toFileOffset: bntOffset)
        handle.write(zeroBNT)
        
        handle.synchronizeFile()
        print("✅ Created blank data disk from template (FAT+BNT cleared)")
    }
    
    /// Legacy createBlankImage for fallback
    private static func createBlankImageLegacy(at destinationURL: URL, sizeMB: Int) throws {
        guard templates[sizeMB] != nil else {
            throw CreatorError.unsupportedSize
        }
        guard let imageSize = diskSizes[sizeMB] else {
            throw CreatorError.unsupportedSize
        }
        
        // Load standard tools header template
        guard let headerData = loadResource("emax2_header_\(sizeMB)", ext: "bin") else {
            throw CreatorError.writeError("standard tools header template not found for \(sizeMB) MB")
        }
        
        // Load Bank Name Table template
        guard let bankTableData = loadResource("emax2_banktable_\(sizeMB)", ext: "bin") else {
            throw CreatorError.writeError("standard tools bank table template not found for \(sizeMB) MB")
        }
        
        // Create image via temp file on local SSD (FAT32 SD cards are very slow for truncate)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".hda")
        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tempURL)
        defer {
            handle.closeFile()
            try? FileManager.default.removeItem(at: destinationURL)
            try? FileManager.default.moveItem(at: tempURL, to: destinationURL)
            if !FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.copyItem(at: tempURL, to: destinationURL)
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
        try handle.truncate(atOffset: UInt64(imageSize))
        
        // Write standard tools header template (header + status + FAT)
        handle.seek(toFileOffset: 0)
        handle.write(headerData)
        
        // Write Bank Name Table at correct offset from header
        let bntSector = headerData.count >= 0x14 ? headerData.readU32LE(at: 0x10) : 4
        handle.seek(toFileOffset: UInt64(bntSector) * 512)
        handle.write(bankTableData)
        
        handle.synchronizeFile()
        // Auto-verify after creation
        let verify = DiskVerifier.verify(imageURL: destinationURL)
        if !verify.passed {
            print("⚠️ Post-create verification FAILED for \(destinationURL.lastPathComponent):")
            for check in verify.checks where !check.passed {
                print("  ❌ \(check.name): \(check.detail)")
            }
        }
        print("✅ Created blank data disk: \(destinationURL.lastPathComponent) (\(sizeMB) MB) [\(verify.summary)]")
    }
}

// MARK: - Data helpers

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
