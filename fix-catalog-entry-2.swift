#!/usr/bin/env swift

import Foundation

// Fix: Remove INIT BANK catalog entry (zero it out)
// EMAX II should boot with just OS, no bank needed

let diskPath = "/Users/senioradvisor/Desktop/AlanWilder_HD10.hda"

print("🔧 Fixing catalog entry 1 (removing INIT BANK)")
print("")

// Load disk
guard var diskData = try? Data(contentsOf: URL(fileURLWithPath: diskPath)) else {
    print("❌ Could not load disk")
    exit(1)
}

// Catalog entry 1 offset
let entry1Offset = 50200

print("📋 BEFORE: Catalog entry 1")
let before = diskData.subdata(in: entry1Offset..<(entry1Offset + 24))
print(before.map { String(format: "%02x", $0) }.joined(separator: " "))
print("")

// Zero out catalog entry 1
let zeroEntry = Data(repeating: 0, count: 24)
diskData.replaceSubrange(entry1Offset..<(entry1Offset + 24), with: zeroEntry)

print("📋 AFTER: Catalog entry 1 (zeroed)")
let after = diskData.subdata(in: entry1Offset..<(entry1Offset + 24))
print(after.map { String(format: "%02x", $0) }.joined(separator: " "))
print("")

// Also fix FAT entry 2 (should be 0x0000 for unused, not 0x7FFF)
let fatEntry2Offset = 1028
diskData[fatEntry2Offset] = 0x00
diskData[fatEntry2Offset + 1] = 0x00

print("✅ FAT entry 2 set to 0x0000 (unused)")
print("")

// Write fixed disk
do {
    try diskData.write(to: URL(fileURLWithPath: diskPath))
    print("✅ Disk fixed!")
    print("")
    print("🎯 NOW: Boot disk has only OS (no INIT BANK)")
    print("   This should match standard tools's boot-only disk format")
} catch {
    print("❌ Could not write: \(error)")
    exit(1)
}
