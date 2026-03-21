#!/usr/bin/env swift
import Foundation

// Test: Create boot disk with SCSI ID 1 (HD10.hda)
// Simulates what BootableDiskWizard now does

let testDir = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("clawd/EmaxForge/test-output")

// Simulate wizard defaults
let scsiID = 1  // NEW DEFAULT (was 0)
let sizeMB = 239
let imageCount = 2

print("🧪 Testing Boot Disk Creation with NEW defaults")
print("📋 SCSI ID: \(scsiID) (should be 1)")
print("📋 Image count: \(imageCount)")
print("")

// Generate filenames like BootableDiskWizard does
for i in 0..<imageCount {
    let currentScsiID = imageCount > 1 ? (i + 1) : scsiID
    let filename = "HD\(currentScsiID)0.hda"
    let role = i == 0 ? "BOOT" : "DATA"
    
    print("[\(i)] \(filename) -> \(role) (SCSI ID \(currentScsiID))")
}

print("")
print("✅ Expected output:")
print("   [0] HD10.hda -> BOOT (SCSI ID 1)")
print("   [1] HD20.hda -> DATA (SCSI ID 2)")
print("")
print("❌ OLD behavior (WRONG):")
print("   [0] HD00.hda -> BOOT (SCSI ID 0)")
print("   [1] HD10.hda -> DATA (SCSI ID 1)")
