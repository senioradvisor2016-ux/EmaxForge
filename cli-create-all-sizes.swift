#!/usr/bin/env swift
import Foundation

// Helper extensions
extension Data {
    mutating func writeU16LE(_ value: UInt16, at offset: Int) {
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8) & 0xFF)
    }
    
    mutating func writeU32LE(_ value: UInt32, at offset: Int) {
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8) & 0xFF)
        self[offset + 2] = UInt8((value >> 16) & 0xFF)
        self[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
}

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

// verified disk sizes (exact byte counts from standard tools)
let templates: [String: ImageTemplate] = [
    "96": ImageTemplate(
        diskSize: 100_663_296,
        clusterSize: 8192,
        bootSignature: 0x7882,
        clusterAreaStartSector: 98,
        bankCount: 47,
        sectorSize: 512,
        sectorsPerCluster: 16,
        reservedSectors: 1,
        fatCopies: 1,
        rootEntries: 512,
        totalSectors: 196_608,
        mediaDescriptor: 0xF8,
        sectorsPerFAT: 65
    ),
    "238": ImageTemplate(
        diskSize: 250_398_720,
        clusterSize: 16384,
        bootSignature: 0x7882,
        clusterAreaStartSector: 98,
        bankCount: 90,
        sectorSize: 512,
        sectorsPerCluster: 32,
        reservedSectors: 1,
        fatCopies: 1,
        rootEntries: 512,
        totalSectors: 489_060,
        mediaDescriptor: 0xF8,
        sectorsPerFAT: 65
    ),
    "481": ImageTemplate(
        diskSize: 504_365_056,
        clusterSize: 32768,
        bootSignature: 0x7882,
        clusterAreaStartSector: 98,
        bankCount: 90,
        sectorSize: 512,
        sectorsPerCluster: 64,
        reservedSectors: 1,
        fatCopies: 1,
        rootEntries: 512,
        totalSectors: 985_088,
        mediaDescriptor: 0xF8,
        sectorsPerFAT: 65
    ),
    "633": ImageTemplate(
        diskSize: 663_846_912,
        clusterSize: 65536,
        bootSignature: 0x7882,
        clusterAreaStartSector: 98,
        bankCount: 90,
        sectorSize: 512,
        sectorsPerCluster: 128,
        reservedSectors: 1,
        fatCopies: 1,
        rootEntries: 512,
        totalSectors: 1_296_576,
        mediaDescriptor: 0xF8,
        sectorsPerFAT: 65
    ),
    "962": ImageTemplate(
        diskSize: 1_009_057_792,
        clusterSize: 32768,
        bootSignature: 0x7882,
        clusterAreaStartSector: 98,
        bankCount: 90,
        sectorSize: 512,
        sectorsPerCluster: 64,
        reservedSectors: 1,
        fatCopies: 1,
        rootEntries: 512,
        totalSectors: 1_970_816,
        mediaDescriptor: 0xF8,
        sectorsPerFAT: 65
    )
]

func createBootDisk(sizeName: String, outputPath: String) throws {
    guard let template = templates[sizeName] else {
        print("❌ Unknown size: \(sizeName)")
        return
    }
    
    print("Creating \(sizeName) MB boot disk...")
    
    // Use standard tools template if available
    let templateName = "emax2_header_\(sizeName).bin"
    let resourcePath = "/Users/senioradvisor/clawd/EmaxForge/EmaxForge/Resources/\(templateName)"
    
    var bootSector: Data
    
    if let templateData = try? Data(contentsOf: URL(fileURLWithPath: resourcePath)), templateData.count >= 512 {
        bootSector = Data(templateData.prefix(512))
        print("   ✓ Loaded standard tools template: \(templateName)")
    } else {
        print("   ⚠️  Template not found, using minimal header")
        bootSector = Data(count: 512)
        bootSector[0] = 0x45  // 'E'
        bootSector[1] = 0x4D  // 'M'
        bootSector[2] = 0x58  // 'X'
        bootSector[3] = 0x32  // '2'
        bootSector[510] = 0x78
        bootSector[511] = 0x82
    }
    
    // Create file with correct size
    let fileURL = URL(fileURLWithPath: outputPath)
    try Data(count: Int(template.diskSize)).write(to: fileURL)
    
    let fileHandle = try FileHandle(forWritingTo: fileURL)
    defer { try? fileHandle.close() }
    
    // Write boot sector
    try fileHandle.seek(toOffset: 0)
    try fileHandle.write(contentsOf: bootSector)
    
    // Write status table
    var statusTable = Data(count: 512)
    statusTable[0] = 0x0F
    for i in stride(from: 4, to: 512, by: 2) {
        statusTable[i] = 0x80
        statusTable[i+1] = 0x80
    }
    try fileHandle.seek(toOffset: 512)
    try fileHandle.write(contentsOf: statusTable)
    
    // Write FAT
    var fat = Data(count: template.sectorsPerFAT * 512)
    fat.writeU16LE(0x8000, at: 0)
    fat[2] = 0xFF
    fat[3] = 0x7F
    try fileHandle.seek(toOffset: 1024)
    try fileHandle.write(contentsOf: fat)
    
    print("✅ Created: \(outputPath)")
    
    // Verify
    let actualSize = try FileManager.default.attributesOfItem(atPath: outputPath)[.size] as! UInt64
    let sizeMB = Double(actualSize) / 1024 / 1024
    print("   Size: \(String(format: "%.1f", sizeMB)) MB (\(actualSize) bytes)")
}

// Main
print("╔═══════════════════════════════════════════════════════════╗")
print("║     standard tools-Compatible Disk Creator - All Sizes            ║")
print("╚═══════════════════════════════════════════════════════════╝")
print("")

let desktop = "\(FileManager.default.homeDirectoryForCurrentUser.path)/Desktop"

for sizeName in ["96", "238", "481", "633", "962"] {
    let outputPath = "\(desktop)/HD_\(sizeName)MB.hda"
    
    do {
        try createBootDisk(sizeName: sizeName, outputPath: outputPath)
        print("")
    } catch {
        print("❌ Error: \(error)")
    }
}

print("✅ All disk images created on Desktop!")
