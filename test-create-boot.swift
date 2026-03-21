#!/usr/bin/env swift
import Foundation

print("🧪 Testing ImageCreator.createBootableImage()")
print("")

let testPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("clawd/EmaxForge/test-output/TEST-BOOT.hda")

let osPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("clawd/emax-project/3. OS/Emax II FUNKAR.EMX")

print("Output: \(testPath.path)")
print("OS:     \(osPath.path)")
print("")

// Check if OS exists
guard FileManager.default.fileExists(atPath: osPath.path) else {
    print("❌ OS file not found!")
    exit(1)
}
print("✅ OS file exists")

// Try to create parent directory
try? FileManager.default.createDirectory(
    at: testPath.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

print("📝 Creating boot disk...")
print("")

// Simulate what ImageCreator does
let sizeMB = 239
let clusterSize = 4896
let clusterAreaStartSector = 98
let catalogOffset = UInt64(clusterAreaStartSector) * 512

print("Template values:")
print("  Size: \(sizeMB) MB")
print("  Cluster size: \(clusterSize) bytes")
print("  Cluster area start: sector \(clusterAreaStartSector)")
print("  Catalog offset: \(catalogOffset) bytes (0x\(String(catalogOffset, radix: 16)))")
print("")

// Read OS
let osData = try Data(contentsOf: osPath)
print("✅ OS loaded: \(osData.count) bytes")
print("")

// Create file
FileManager.default.createFile(atPath: testPath.path, contents: nil)
let handle = try FileHandle(forWritingTo: testPath)
defer { handle.closeFile() }

let imageSize = 250398720  // 239 MB
print("📏 Truncating to \(imageSize) bytes...")
try handle.truncate(atOffset: UInt64(imageSize))
print("✅ Truncated")
print("")

// Write header
print("📝 Writing boot sector header...")
var header = Data(count: 512)
header[0] = 0x45  // E
header[1] = 0x4D  // M
header[2] = 0x58  // X
header[3] = 0x32  // 2
header[0x1FE] = 0x78
header[0x1FF] = 0x82
handle.seek(toFileOffset: 0)
handle.write(header)
print("✅ Header written")
print("")

// Write catalog
print("📝 Writing catalog at offset \(catalogOffset)...")
var catalogEntry = Data(count: 32)
let osName = "EMAX2 Software".data(using: .ascii)!
catalogEntry.replaceSubrange(0..<osName.count, with: osName)
handle.seek(toFileOffset: catalogOffset)
handle.write(catalogEntry)
print("✅ Catalog written")
print("")

// Write OS
let clusterOffset = catalogOffset + UInt64(clusterSize)
print("📝 Writing OS at offset \(clusterOffset)...")
handle.seek(toFileOffset: clusterOffset)
handle.write(osData)
print("✅ OS written")
print("")

handle.closeFile()
print("🎉 SUCCESS!")
print("")
print("Created: \(testPath.path)")

let size = try FileManager.default.attributesOfItem(atPath: testPath.path)[.size] as! UInt64
print("Size: \(size) bytes (\(size / 1024 / 1024) MB)")
