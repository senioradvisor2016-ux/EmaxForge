#!/usr/bin/env swift
import Foundation

let testPath = "/tmp/test-catalog.hda"
let catalogBytes: [UInt8] = [
    0x00, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00,
    0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0xf0, 0x00, 0x00,
    0x00, 0x04, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x23,
    0x01, 0x00, 0x00, 0x9a, 0x00, 0x00, 0xa8, 0x01, 0x00, 0x00,
    0x00, 0x00, 0x02, 0x00, 0x00, 0x20, 0x00, 0x00, 0x00, 0x23,
    0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00
]

print("Testing exact catalog entry write...")
print("")

FileManager.default.createFile(atPath: testPath, contents: nil)
let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: testPath))

try handle.truncate(atOffset: 1024 * 1024)

let catalogOffset: UInt64 = 0xC400
handle.seek(toFileOffset: catalogOffset)
handle.write(Data(catalogBytes))

try handle.close()

print("Written catalog at 0xC400")
print("")

let readHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: testPath))
readHandle.seek(toFileOffset: catalogOffset)
let readBack = readHandle.readData(ofLength: 64)
readHandle.closeFile()

print("Verification:")
print("Expected:")
print(Data(catalogBytes).map { String(format: "%02x", $0) }.joined(separator: " "))
print("")
print("Got:")
print(readBack.map { String(format: "%02x", $0) }.joined(separator: " "))
print("")

if readBack == Data(catalogBytes) {
    print("✅ EXACT MATCH!")
} else {
    print("❌ MISMATCH!")
}

try? FileManager.default.removeItem(atPath: testPath)
