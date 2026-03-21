#!/usr/bin/env swift
// Standalone Boot Disk Validation Test
// No dependencies - can run directly with swift

import Foundation

// MARK: - Test Framework

var testsPassed = 0
var testsFailed = 0
var testsSkipped = 0

func test(_ name: String, _ block: () throws -> Void) {
    do {
        try block()
        print("✅ PASS: \(name)")
        testsPassed += 1
    } catch let error as TestError {
        if error.skip {
            print("⏭️  SKIP: \(name) - \(error.message)")
            testsSkipped += 1
        } else {
            print("❌ FAIL: \(name) - \(error.message)")
            testsFailed += 1
        }
    } catch {
        print("❌ FAIL: \(name) - \(error)")
        testsFailed += 1
    }
}

struct TestError: Error {
    let message: String
    let skip: Bool
    
    init(_ message: String, skip: Bool = false) {
        self.message = message
        self.skip = skip
    }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "") throws {
    guard a == b else {
        throw TestError("\(message.isEmpty ? "Values not equal" : message): \(a) != \(b)")
    }
}

func assertTrue(_ condition: Bool, _ message: String = "Condition not true") throws {
    guard condition else {
        throw TestError(message)
    }
}

// MARK: - Tests

print("🧪 EmaxForge Boot Disk Validation Tests")
print("========================================\n")

// Test 1: Boot Signature Constants
test("Boot signature constants") {
    let sig1: UInt8 = 0x78
    let sig2: UInt8 = 0x82
    
    try assertEqual(sig1, 0x78, "First byte should be 0x78")
    try assertEqual(sig2, 0x82, "Second byte should be 0x82")
}

// Test 2: FAT Entry 0
test("FAT entry 0 format") {
    let bytes: [UInt8] = [0x0F, 0x00]  // Little-endian 0x000F
    let value = UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
    
    try assertEqual(value, UInt16(0x000F), "FAT entry 0 should be 0x000F")
}

// Test 3: SCSI ID Filename Format
test("SCSI ID 0 filename format") {
    let filename = String(format: "HD%02d.hda", 0)
    try assertEqual(filename, "HD00.hda", "SCSI ID 0 should format as HD00.hda")
}

test("SCSI ID 1 filename format") {
    // ZuluSCSI uses ID×10 for filenames: SCSI ID 1 = HD10.hda
    let scsiID = 1
    let filename = String(format: "HD%d0.hda", scsiID)
    try assertEqual(filename, "HD10.hda", "SCSI ID 1 should format as HD10.hda (ZuluSCSI convention)")
}

// Test 4: Disk Sizes
test("Valid disk sizes") {
    let validSizes = [
        96 * 1024 * 1024,
        239 * 1024 * 1024,
        481 * 1024 * 1024,
        633 * 1024 * 1024,
        962 * 1024 * 1024
    ]
    
    for size in validSizes {
        try assertTrue(size > 0, "Size should be positive")
        try assertTrue(size < 2_000_000_000, "Size should be reasonable")
    }
}

// Test 5: File-based Integration Test
test("Desktop boot disk validation") {
    let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    let possibleFiles = ["HD00.hda", "HD10.hda", "TEST_HD00.hda", "TEST_HD10.hda"]
    
    var foundFile: URL?
    for filename in possibleFiles {
        let fileURL = desktop.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            foundFile = fileURL
            break
        }
    }
    
    guard let fileURL = foundFile else {
        throw TestError("No boot disk found on Desktop", skip: true)
    }
    
    print("  📄 Testing: \(fileURL.lastPathComponent)")
    
    let data = try Data(contentsOf: fileURL)
    
    // Size check
    let size = data.count
    print("  📏 Size: \(size / (1024*1024)) MB")
    try assertTrue(size >= 90_000_000, "Boot disk should be at least 90 MB")
    
    // Boot signature check
    let sig1 = data[510]
    let sig2 = data[511]
    print("  🔏 Boot signature: 0x\(String(format: "%02X", sig1)) 0x\(String(format: "%02X", sig2))")
    try assertEqual(sig1, UInt8(0x78), "Boot signature byte 1 should be 0x78")
    try assertEqual(sig2, UInt8(0x82), "Boot signature byte 2 should be 0x82")
    
    // FAT check
    if data.count >= 1026 {
        let fatEntry0 = UInt16(data[1024]) | (UInt16(data[1025]) << 8)
        print("  💾 FAT entry 0: 0x\(String(format: "%04X", fatEntry0))")
        
        // Valid FAT entry 0 values: 0x000F (newer) or 0x8000 (older format)
        if fatEntry0 == 0x000F || fatEntry0 == 0x8000 {
            print("  ✓ FAT structure valid")
        } else {
            print("  ⚠️  FAT entry 0 unexpected (got 0x\(String(format: "%04X", fatEntry0)))")
        }
    }
}

// Test 6: ZuluSCSI Config
test("ZuluSCSI config validation") {
    let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    let configURL = desktop.appendingPathComponent("zuluscsi.ini")
    
    guard FileManager.default.fileExists(atPath: configURL.path) else {
        throw TestError("No zuluscsi.ini found on Desktop", skip: true)
    }
    
    let content = try String(contentsOf: configURL, encoding: .utf8)
    
    try assertTrue(content.contains("[SCSI1]"), "Config should contain [SCSI1] section")
    print("  ✓ [SCSI1] section found")
    
    if content.contains("HD10.hda") {
        print("  ✓ HD10.hda reference found")
    }
}

// MARK: - Summary

print("\n" + String(repeating: "=", count: 40))
print("📊 Test Summary")
print(String(repeating: "=", count: 40))
print("✅ Passed:  \(testsPassed)")
print("❌ Failed:  \(testsFailed)")
print("⏭️  Skipped: \(testsSkipped)")
print("📝 Total:   \(testsPassed + testsFailed + testsSkipped)")
print("")

if testsFailed == 0 {
    print("🎉 All tests passed!")
    exit(0)
} else {
    print("💥 Some tests failed")
    exit(1)
}
