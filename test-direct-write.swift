#!/usr/bin/env swift
import Foundation

let testPath = "/tmp/test-os-write.bin"
let osPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("clawd/emax-project/3. OS/Emax II FUNKAR.EMX")

print("📝 Testing Direct OS Write")
print("")

// Read OS
let osData = try Data(contentsOf: osPath)
print("OS loaded: \(osData.count) bytes")
print("First 16 bytes: \(osData.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " "))")
print("")

// Create test file
FileManager.default.createFile(atPath: testPath, contents: nil)
let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: testPath))

// Truncate to 1 MB
try handle.truncate(atOffset: 1024 * 1024)
print("Truncated to 1 MB")
print("")

// Write OS at offset 0xD720 (55072)
let offset: UInt64 = 0xD720
print("Writing OS to offset 0x\(String(offset, radix: 16)) (\(offset))...")
handle.seek(toFileOffset: offset)
handle.write(osData)
print("Written!")
print("")

// Sync and close
handle.synchronizeFile()
try handle.close()
print("Closed")
print("")

// Verify
let readHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: testPath))
readHandle.seek(toFileOffset: offset)
let readBack = readHandle.readData(ofLength: 16)
readHandle.closeFile()

print("Verification - First 16 bytes at 0x\(String(offset, radix: 16)):")
print("  Written: \(osData.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " "))")
print("  Read back: \(readBack.map { String(format: "%02x", $0) }.joined(separator: " "))")

if readBack == osData.prefix(16) {
    print("  ✅ MATCH!")
} else {
    print("  ❌ MISMATCH!")
}

try? FileManager.default.removeItem(atPath: testPath)
