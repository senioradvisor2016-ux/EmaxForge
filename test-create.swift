#!/usr/bin/env swift
import Foundation

// Minimal boot disk creator for testing
let destURL = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("Desktop/TEST-BOOT-NOW.hda")

// Load the module (this won't work outside package context)
// Instead, call the built app with AppleScript or create disk manually

print("Creating test disk at: \(destURL.path)")

// Manual creation matching ImageCreator exactly
let sizeMB = 239
let sizeBytes = UInt64(sizeMB) * 1024 * 1024

// Create file
FileManager.default.createFile(atPath: destURL.path, contents: nil)
let handle = try! FileHandle(forWritingTo: destURL)
try! handle.truncate(atOffset: sizeBytes)

// Template for 239MB
let clusterSize: UInt32 = 489472
let clusterAreaStartSector: UInt32 = 98
let bootSig1: UInt8 = 0x78
let bootSig2: UInt8 = 0x82

// Helper to write LE integers
extension Data {
    mutating func writeU32LE(_ value: UInt32, at offset: Int) {
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8) & 0xFF)
        self[offset + 2] = UInt8((value >> 16) & 0xFF)
        self[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
}

// Header (ALL fields from template)
var header = Data(count: 512)
header[0] = 0x45  // E
header[1] = 0x4D  // M
header[2] = 0x58  // X
header[3] = 0x32  // 2

// All verified fields for 239MB
header.writeU32LE(489472, at: 0x04)  // clusterSize
header.writeU32LE(6, at: 0x08)       // field_0x08
header.writeU32LE(2, at: 0x0C)       // field_0x0C
header.writeU32LE(8, at: 0x10)       // field_0x10
header.writeU32LE(90, at: 0x14)      // bankCount
header.writeU32LE(2, at: 0x18)       // field_0x18
header.writeU32LE(4, at: 0x1C)       // field_0x1C
header.writeU32LE(98, at: 0x20)      // clusterAreaStartSector
header.writeU32LE(955, at: 0x24)     // sectorsPerClusterMinus1
header.writeU32LE(0x783B0103, at: 0x28)  // field_0x28
header.writeU32LE(7, at: 0x2C)       // field_0x2C
header.writeU32LE(0x0D020000, at: 0x30)  // field_0x30

// Boot signature
header[0x1FE] = bootSig1
header[0x1FF] = bootSig2

handle.seek(toFileOffset: 0)
handle.write(header)

// OS data
let osPath = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("clawd/emax-project/3. OS/Emax II FUNKAR.EMX")

if FileManager.default.fileExists(atPath: osPath.path) {
    let osData = try! Data(contentsOf: osPath)
    let clusterAreaStart = UInt64(clusterAreaStartSector) * 512
    let clusterOffset = clusterAreaStart + UInt64(clusterSize)
    
    handle.seek(toFileOffset: clusterOffset)
    handle.write(osData)
    print("✅ Wrote OS data: \(osData.count) bytes at offset \(clusterOffset)")
} else {
    print("❌ OS file not found: \(osPath.path)")
}

handle.synchronizeFile()
try! handle.close()

print("✅ Created: \(destURL.path)")
