#!/usr/bin/env swift
// EmaxForge CLI - Create Test Disks
// Uses ImageCreator + BankImporter directly

import Foundation

// MARK: - Helpers

extension Data {
    mutating func writeU32LE(_ value: UInt32, at offset: Int) {
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8) & 0xFF)
        self[offset + 2] = UInt8((value >> 16) & 0xFF)
        self[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
    
    mutating func writeU16LE(_ value: UInt16, at offset: Int) {
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8) & 0xFF)
    }
}

// MARK: - Image Templates

struct ImageTemplate {
    let diskSize: Int64
    let clusterSize: Int
    let bootSignature: UInt16
    let clusterAreaStartSector: Int
    let bankCount: Int
    let sectorSize: Int
    let sectorsPerCluster: Int
    let reservedSectors: Int
    let fatCopies: Int
    let rootEntries: Int
    let totalSectors: Int
    let mediaDescriptor: UInt8
    let sectorsPerFAT: Int
}

let templates: [Int64: ImageTemplate] = [
    // standard tools actual size: 250,398,720 bytes = 489,060 sectors (NOT 239 MB!)
    250_398_720: ImageTemplate(
        diskSize: 250_398_720,  // standard tools byte-perfect size
        clusterSize: 16384,
        bootSignature: 0x7882,
        clusterAreaStartSector: 98,
        bankCount: 90,
        sectorSize: 512,
        sectorsPerCluster: 32,
        reservedSectors: 1,
        fatCopies: 1,
        rootEntries: 512,
        totalSectors: 489_060,  // standard tools exact sector count
        mediaDescriptor: 0xF8,
        sectorsPerFAT: 65
    )
]

// MARK: - Create Boot Disk

func createBootDisk(path: String, size: Int64, includeOS: Bool) throws {
    guard let template = templates[size] else {
        throw NSError(domain: "EmaxForge", code: 1, userInfo: [NSLocalizedDescriptionKey: "No template for size \(size)"])
    }
    
    print("📀 Creating boot disk: \(path)")
    print("   Size: \(size / (1024*1024)) MB")
    
    // Create file
    let fileURL = URL(fileURLWithPath: path)
    try Data(count: Int(size)).write(to: fileURL)
    
    let fileHandle = try FileHandle(forWritingTo: fileURL)
    defer { try? fileHandle.close() }
    
    // Write boot sector using standard tools template
    var bootSector: Data
    
    // Try to load template from Resources
    let templateName = "emax2_header_\(size / (1024*1024)).bin"
    // NOTE: Bundle.main.resourceURL doesn't work in standalone scripts!
    // Always use hardcoded path for CLI tools.
    let resourcePath = "/Users/senioradvisor/clawd/EmaxForge/EmaxForge/Resources/\(templateName)"
    
    var usedTemplate = false
    
    if let templateData = try? Data(contentsOf: URL(fileURLWithPath: resourcePath)), templateData.count >= 512 {
        // Use template AS-IS - it has ALL correct standard tools values!
        bootSector = Data(templateData.prefix(512))
        
        // DEBUG: Verify cluster size from template
        let clusterSizeFromTemplate = bootSector[4] | (bootSector[5] << 8) | (bootSector[6] << 16) | (bootSector[7] << 24)
        print("   ✓ Loaded standard tools template (byte-perfect): \(templateName)")
        print("   → Template cluster size: 0x\(String(clusterSizeFromTemplate, radix: 16))")
        
        usedTemplate = true
    } else {
        // Fallback: Create minimal EMAX II header
        bootSector = Data(count: 512)
        
        // EMAX II magic "EMX2"
        bootSector[0] = 0x45  // 'E'
        bootSector[1] = 0x4D  // 'M'
        bootSector[2] = 0x58  // 'X'
        bootSector[3] = 0x32  // '2'
        
        print("   ⚠️  Template not found, using minimal EMAX II header")
        usedTemplate = false
        
        // BPB (BIOS Parameter Block) - only for fallback!
        bootSector.writeU32LE(UInt32(template.clusterSize), at: 4)
        bootSector.writeU16LE(UInt16(template.sectorSize), at: 11)
        bootSector[13] = UInt8(template.sectorsPerCluster)
        bootSector.writeU16LE(UInt16(template.reservedSectors), at: 14)
        bootSector[16] = UInt8(template.fatCopies)
        bootSector.writeU16LE(UInt16(template.rootEntries), at: 17)
        bootSector.writeU16LE(0, at: 19)
        bootSector[21] = template.mediaDescriptor
        bootSector.writeU16LE(UInt16(template.sectorsPerFAT), at: 22)
        bootSector.writeU16LE(63, at: 24)
        bootSector.writeU16LE(16, at: 26)
        bootSector.writeU32LE(0, at: 28)
        bootSector.writeU32LE(UInt32(template.totalSectors), at: 32)
        bootSector.writeU32LE(UInt32(template.clusterAreaStartSector), at: 0x20)
        
        // Boot signature
        bootSector[510] = 0x78
        bootSector[511] = 0x82
    }
    
    fileHandle.seek(toFileOffset: 0)
    fileHandle.write(bootSector)
    
    print("   ✓ Boot sector written")
    
    // Write status table (offset 0x200 = 512)
    // standard tools format: 0x0F000000 header + 0x8080 pattern fill
    var statusTable = Data(count: 512)
    
    // Header
    statusTable[0] = 0x0F
    statusTable[1] = 0x00
    statusTable[2] = 0x00
    statusTable[3] = 0x00
    
    // Fill rest with 0x80 0x80 pattern
    for i in stride(from: 4, to: 512, by: 2) {
        statusTable[i] = 0x80
        statusTable[i+1] = 0x80
    }
    
    fileHandle.seek(toFileOffset: 512)
    fileHandle.write(statusTable)
    
    print("   ✓ Status table written")
    
    // Write FAT (offset 0x400 = 1024)
    var fat = Data(count: template.sectorsPerFAT * 512)
    
    // FAT entry 0 (standard tools format!)
    fat.writeU16LE(0x8000, at: 0)  // 0x8000 = 00 80 in LE
    
    // FAT entry 1 (cluster 1 = OS, end of chain - standard tools format!)
    fat[2] = 0xFF  // Low byte
    fat[3] = 0x7F  // High byte = 0x7FFF in LE
    
    // FAT entry 2 (cluster 2 = INIT BANK, end of chain)
    if includeOS {
        fat[4] = 0xFF
        fat[5] = 0x7F
    }
    
    fileHandle.seek(toFileOffset: 1024)
    fileHandle.write(fat)
    
    print("   ✓ FAT written")
    
    // Write catalog (offset varies by template)
    let catalogOffset = UInt64(template.sectorsPerFAT + template.reservedSectors) * 512
    var catalog = Data(count: template.rootEntries * 32)
    
    if includeOS {
        // OS entry
        let osName = "EMAX2 Software  ".data(using: .ascii)!
        catalog.replaceSubrange(0..<16, with: osName)
        catalog.writeU16LE(1, at: 24) // Cluster 1
        catalog[26] = 0x81 // FLAGS
        catalog[27] = 0x00
        
        // INIT BANK entry
        let bankName = "INIT BANK       ".data(using: .ascii)!
        catalog.replaceSubrange(32..<48, with: bankName)
        catalog.writeU16LE(2, at: 32 + 24) // Cluster 2
        catalog[32 + 26] = 0x81 // FLAGS
        catalog[32 + 27] = 0x00
    }
    
    fileHandle.seek(toFileOffset: catalogOffset)
    fileHandle.write(catalog)
    
    print("   ✓ Catalog written")
    
    // Write OS data (if requested)
    if includeOS {
        let osPath = "\(FileManager.default.homeDirectoryForCurrentUser.path)/clawd/EmaxForge/EmaxForge/Resources/emax2_os.bin"
        let clusterAreaStart = UInt64(template.clusterAreaStartSector) * 512
        
        if FileManager.default.fileExists(atPath: osPath) {
            let osData = try Data(contentsOf: URL(fileURLWithPath: osPath))
            let cluster1Offset = clusterAreaStart
            
            fileHandle.seek(toFileOffset: cluster1Offset)
            fileHandle.write(osData)
            
            print("   ✓ OS written (\(osData.count) bytes)")
        } else {
            print("   ⚠️  OS file not found (disk will be blank)")
        }
        
        // Write INIT BANK (minimal bank in cluster 2)
        let cluster2Offset = clusterAreaStart + UInt64(template.clusterSize)
        var initBank = Data(count: template.clusterSize)
        
        // Minimal bank header
        let bankHeader = "INIT BANK       ".data(using: .ascii)!
        initBank.replaceSubrange(0..<16, with: bankHeader)
        
        fileHandle.seek(toFileOffset: cluster2Offset)
        fileHandle.write(initBank)
        
        print("   ✓ INIT BANK written")
    }
    
    print("✅ Boot disk created: \(path)\n")
}

// MARK: - Create Data Disk

func createDataDisk(path: String, size: Int64) throws {
    print("💾 Creating data disk: \(path)")
    
    // Same as boot disk but without OS
    try createBootDisk(path: path, size: size, includeOS: false)
}

// MARK: - Main

print("🔨 EmaxForge CLI - Test Disk Creator")
print("====================================\n")

let desktop = "\(FileManager.default.homeDirectoryForCurrentUser.path)/Desktop"
// Use standard tools byte-perfect size: 250,398,720 bytes = 489,060 sectors
let diskSize: Int64 = 250_398_720

do {
    // Create HD10 (boot disk)
    try createBootDisk(
        path: "\(desktop)/HD10.hda",
        size: diskSize,
        includeOS: true
    )
    
    // Create HD20 (data disk)
    try createDataDisk(
        path: "\(desktop)/HD20.hda",
        size: diskSize
    )
    
    // Create zuluscsi.ini
    let config = """
[SCSI1]
Type=1
IMG=HD10.hda

[SCSI2]
Type=1
IMG=HD20.hda
"""
    
    try config.write(toFile: "\(desktop)/zuluscsi.ini", atomically: true, encoding: .utf8)
    print("📝 ZuluSCSI config created: zuluscsi.ini\n")
    
    print("✅ Setup complete!")
    print("\nCreated files:")
    print("  • HD10.hda (boot disk with OS + INIT BANK)")
    print("  • HD20.hda (data disk for samples)")
    print("  • zuluscsi.ini (ZuluSCSI config)")
    print("\nTest samples ready at:")
    print("  ~/Desktop/TestSamples/ (10 WAV files)")
    print("\nNext: Import samples to HD20 using EmaxForge GUI")
    
} catch {
    print("❌ Error: \(error)")
    exit(1)
}
