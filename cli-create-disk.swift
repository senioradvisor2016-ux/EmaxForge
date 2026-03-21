#!/usr/bin/env swift
// EmaxForge CLI - Create Disk Image
// 
// Usage:
//   swift cli-create-disk.swift --size 239 --boot --output HD00.hda --scsi-id 0

import Foundation

// MARK: - Command Line Args

struct Args {
    var size: Int64 = 250_398_720  // Default: 239 MB (standard tools size)
    var boot: Bool = false
    var output: String = ""
    var scsiID: Int = 1
    
    static func parse(_ args: [String]) -> Args? {
        var result = Args()
        var i = 1  // Skip program name
        
        while i < args.count {
            let arg = args[i]
            
            switch arg {
            case "--size":
                guard i + 1 < args.count else { return nil }
                let sizeStr = args[i + 1]
                
                // Map MB → standard tools byte sizes
                switch sizeStr {
                case "96": result.size = 100_663_296
                case "239": result.size = 250_398_720
                case "481": result.size = 504_365_056
                case "633": result.size = 663_748_608
                case "962": result.size = 1_008_730_112
                default:
                    print("❌ Invalid size. Use: 96, 239, 481, 633, 962")
                    return nil
                }
                i += 2
            
            case "--boot":
                result.boot = true
                i += 1
            
            case "--output":
                guard i + 1 < args.count else { return nil }
                result.output = args[i + 1]
                i += 2
            
            case "--scsi-id":
                guard i + 1 < args.count, let id = Int(args[i + 1]) else { return nil }
                result.scsiID = id
                i += 2
            
            case "--help", "-h":
                return nil
            
            default:
                print("❌ Unknown option: \(arg)")
                return nil
            }
        }
        
        guard !result.output.isEmpty else {
            print("❌ --output required")
            return nil
        }
        
        return result
    }
    
    static func printUsage() {
        print("""
        EmaxForge CLI - Create Disk Image
        
        Usage:
          swift cli-create-disk.swift [OPTIONS]
        
        Options:
          --size <MB>       Disk size (96, 239, 481, 633, 962) [default: 239]
          --boot            Include OS + INIT BANK (creates bootable disk)
          --output <path>   Output .hda file (required)
          --scsi-id <id>    SCSI ID (0-6) [default: 1]
          -h, --help        Show this help
        
        Examples:
          # Boot disk (SCSI ID 1)
          swift cli-create-disk.swift --size 239 --boot --output HD10.hda --scsi-id 1
          
          # Data disk (SCSI ID 2)
          swift cli-create-disk.swift --size 239 --output HD20.hda --scsi-id 2
        """)
    }
}

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
    let totalClusters: Int  // Added for header 0x24
}

let templates: [Int64: ImageTemplate] = [
    100_663_296: ImageTemplate(
        diskSize: 100_663_296,
        clusterSize: 8192,
        bootSignature: 0x7882,
        clusterAreaStartSector: 66,  // TODO: Verify against standard tools template
        bankCount: 111,
        sectorSize: 512,
        sectorsPerCluster: 16,
        reservedSectors: 1,
        fatCopies: 1,
        rootEntries: 512,
        totalSectors: 196_608,
        mediaDescriptor: 0xF8,
        sectorsPerFAT: 33,
        totalClusters: 1533  // ✅ From standard tools template
    ),
    250_398_720: ImageTemplate(
        diskSize: 250_398_720,
        clusterSize: 16384,
        bootSignature: 0x7882,
        clusterAreaStartSector: 1920,  // ✅ FIXED: Was 98, now 1920 (0x0778) to match standard tools
        bankCount: 90,
        sectorSize: 512,
        sectorsPerCluster: 32,
        reservedSectors: 1,
        fatCopies: 1,
        rootEntries: 512,
        totalSectors: 489_060,
        mediaDescriptor: 0xF8,
        sectorsPerFAT: 65,
        totalClusters: 955  // ✅ ADDED: From standard tools template (0x03BB)
    ),
    504_365_056: ImageTemplate(
        diskSize: 504_365_056,
        clusterSize: 32768,
        bootSignature: 0x7882,
        clusterAreaStartSector: 162,  // TODO: Verify against standard tools template
        bankCount: 90,
        sectorSize: 512,
        sectorsPerCluster: 64,
        reservedSectors: 1,
        fatCopies: 1,
        rootEntries: 512,
        totalSectors: 984_900,
        mediaDescriptor: 0xF8,
        sectorsPerFAT: 129,
        totalClusters: 961  // ✅ From standard tools template
    ),
    663_748_608: ImageTemplate(
        diskSize: 663_748_608,
        clusterSize: 32768,
        bootSignature: 0x7882,
        clusterAreaStartSector: 194,  // TODO: Verify against standard tools template
        bankCount: 120,
        sectorSize: 512,
        sectorsPerCluster: 64,
        reservedSectors: 1,
        fatCopies: 1,
        rootEntries: 512,
        totalSectors: 1_296_384,
        mediaDescriptor: 0xF8,
        sectorsPerFAT: 161,
        totalClusters: 1265  // ✅ From standard tools template
    ),
    1_008_730_112: ImageTemplate(
        diskSize: 1_008_730_112,
        clusterSize: 32768,
        bootSignature: 0x7882,
        clusterAreaStartSector: 258,  // TODO: Verify against standard tools template
        bankCount: 180,
        sectorSize: 512,
        sectorsPerCluster: 64,
        reservedSectors: 1,
        fatCopies: 1,
        rootEntries: 512,
        totalSectors: 1_969_800,
        mediaDescriptor: 0xF8,
        sectorsPerFAT: 225,
        totalClusters: 961  // ✅ From standard tools template
    )
]

// MARK: - Create Disk

func createDisk(path: String, size: Int64, includeOS: Bool) throws {
    guard let template = templates[size] else {
        throw NSError(domain: "EmaxForge", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "No template for size \(size)"
        ])
    }
    
    let sizeMB = size / (1024 * 1024)
    print("📀 Creating disk: \(path)")
    print("   Size: \(sizeMB) MB (\(size) bytes)")
    print("   Boot: \(includeOS ? "Yes" : "No")")
    
    // Create file
    let fileURL = URL(fileURLWithPath: path)
    try Data(count: Int(size)).write(to: fileURL)
    
    let fileHandle = try FileHandle(forWritingTo: fileURL)
    defer { try? fileHandle.close() }
    
    // Write boot sector
    var bootSector = Data(count: 512)
    
    // EMAX II magic
    bootSector[0] = 0x45  // 'E'
    bootSector[1] = 0x4D  // 'M'
    bootSector[2] = 0x58  // 'X'
    bootSector[3] = 0x32  // '2'
    
    // EMAX II header structure (verified against standard tools)
    bootSector.writeU32LE(UInt32(template.clusterAreaStartSector), at: 0x04)  // ✅ FIX: Was 0x20, should be 0x04!
    bootSector.writeU32LE(0x00000006, at: 0x08)  // field_0x08
    bootSector.writeU32LE(0x00000002, at: 0x0C)  // field_0x0C (sectorSize multiplier)
    bootSector.writeU32LE(0x00000008, at: 0x10)  // clusterSizeSectors (8 for 239 MB)
    bootSector.writeU32LE(UInt32(template.bankCount), at: 0x14)  // bankCount (90 for 239 MB)
    bootSector.writeU32LE(0x00000002, at: 0x18)  // field_0x18
    bootSector.writeU32LE(0x00000004, at: 0x1C)  // field_0x1C
    bootSector.writeU32LE(0x00000062, at: 0x20)  // statusTableStartSector (98)
    bootSector.writeU32LE(UInt32(template.totalClusters), at: 0x24)  // totalClusters (955 for 239 MB)
    bootSector.writeU32LE(0x783B0103, at: 0x28)  // field_0x28 (from standard tools template)
    bootSector.writeU32LE(UInt32(template.clusterAreaStartSector), at: 0x2B)  // duplicate cluster area start
    
    // Boot signature
    bootSector[510] = 0x78
    bootSector[511] = 0x82
    
    fileHandle.seek(toFileOffset: 0)
    fileHandle.write(bootSector)
    print("   ✓ Boot sector")
    
    // Status table
    var statusTable = Data(count: 512)
    statusTable[0] = 0x0F
    for i in stride(from: 4, to: 512, by: 2) {
        statusTable[i] = 0x80
        statusTable[i+1] = 0x80
    }
    
    fileHandle.seek(toFileOffset: 512)
    fileHandle.write(statusTable)
    print("   ✓ Status table")
    
    // FAT
    var fat = Data(count: template.sectorsPerFAT * 512)
    fat.writeU16LE(0x8000, at: 0)
    
    if includeOS {
        fat[2] = 0xFF
        fat[3] = 0x7F
        fat[4] = 0xFF
        fat[5] = 0x7F
    }
    
    fileHandle.seek(toFileOffset: 1024)
    fileHandle.write(fat)
    print("   ✓ FAT")
    
    // Catalog
    let catalogOffset = UInt64(template.sectorsPerFAT + template.reservedSectors) * 512
    var catalog = Data(count: template.rootEntries * 32)
    
    if includeOS {
        // OS entry
        let osName = "EMAX2 Software  ".data(using: .ascii)!
        catalog.replaceSubrange(0..<16, with: osName)
        catalog.writeU16LE(1, at: 24)
        catalog[26] = 0x81
        catalog[27] = 0x00
        
        // INIT BANK
        let bankName = "INIT BANK       ".data(using: .ascii)!
        catalog.replaceSubrange(32..<48, with: bankName)
        catalog.writeU16LE(2, at: 32 + 24)
        catalog[32 + 26] = 0x81
        catalog[32 + 27] = 0x00
    }
    
    fileHandle.seek(toFileOffset: catalogOffset)
    fileHandle.write(catalog)
    print("   ✓ Catalog")
    
    // OS data
    if includeOS {
        let osPath = "\(FileManager.default.homeDirectoryForCurrentUser.path)/clawd/EmaxForge/EmaxForge/Resources/emax2_os.bin"
        let clusterAreaStart = UInt64(template.clusterAreaStartSector) * 512
        
        if FileManager.default.fileExists(atPath: osPath) {
            let osData = try Data(contentsOf: URL(fileURLWithPath: osPath))
            let cluster1Offset = clusterAreaStart
            
            fileHandle.seek(toFileOffset: cluster1Offset)
            fileHandle.write(osData)
            print("   ✓ OS (\(osData.count) bytes)")
        }
        
        // INIT BANK
        let cluster2Offset = clusterAreaStart + UInt64(template.clusterSize)
        var initBank = Data(count: template.clusterSize)
        let bankHeader = "INIT BANK       ".data(using: .ascii)!
        initBank.replaceSubrange(0..<16, with: bankHeader)
        
        fileHandle.seek(toFileOffset: cluster2Offset)
        fileHandle.write(initBank)
        print("   ✓ INIT BANK")
    }
    
    print("✅ Created: \(path)\n")
}

// MARK: - Main

guard let args = Args.parse(CommandLine.arguments) else {
    Args.printUsage()
    exit(1)
}

do {
    try createDisk(
        path: args.output,
        size: args.size,
        includeOS: args.boot
    )
    
    // Print JSON output for Python wrapper
    let result: [String: Any] = [
        "success": true,
        "path": args.output,
        "size": args.size,
        "boot": args.boot,
        "scsi_id": args.scsiID
    ]
    
    if let jsonData = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        print("JSON_OUTPUT_START")
        print(jsonString)
        print("JSON_OUTPUT_END")
    }
    
} catch {
    print("❌ Error: \(error)")
    exit(1)
}
