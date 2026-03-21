#!/usr/bin/env swift
import Foundation

print("🧪 Testing FIXED OS Write")
print("")

let destPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Desktop/HD10-TEST.hda")
let osPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("clawd/emax-project/3. OS/Emax II FUNKAR.EMX")

// Template for 239 MB
let clusterSize = 489472
let clusterAreaStartSector = 98
let clusterAreaStart = UInt64(clusterAreaStartSector * 512)  // 0xC400
let catalogSize: UInt64 = 4896  // 0x1320
let cluster1Offset = clusterAreaStart + catalogSize  // 0xD720

print("Template values:")
print("  Cluster area start: \(clusterAreaStart) (0x\(String(clusterAreaStart, radix: 16)))")
print("  Catalog size: \(catalogSize) (0x\(String(catalogSize, radix: 16)))")
print("  Cluster 1 offset: \(cluster1Offset) (0x\(String(cluster1Offset, radix: 16)))")
print("")

// Read OS
let osData = try Data(contentsOf: osPath)
print("OS loaded: \(osData.count) bytes")
print("")

// Create file
FileManager.default.createFile(atPath: destPath.path, contents: nil)
let handle = try FileHandle(forWritingTo: destPath)

// Truncate
try handle.truncate(atOffset: 250398720)

// Write OS at CORRECT offset
print("Writing OS at 0x\(String(cluster1Offset, radix: 16))...")
handle.seek(toFileOffset: cluster1Offset)
handle.write(osData)

try handle.close()
print("Done!")
print("")

// Verify
let readHandle = try FileHandle(forReadingFrom: destPath)
readHandle.seek(toFileOffset: cluster1Offset)
let readBack = readHandle.readData(ofLength: 16)
readHandle.closeFile()

print("Verification:")
print("  Expected: b7 ce 59 ce 3a ce 31 ce 6b ce f7 ce 73 cf 09 d0")
print("  Got:      \(readBack.map { String(format: "%02x", $0) }.joined(separator: " "))")

if readBack.prefix(4) == Data([0xb7, 0xce, 0x59, 0xce]) {
    print("  ✅ SUCCESS!")
} else {
    print("  ❌ FAILED!")
}

