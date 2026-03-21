#!/usr/bin/env swift

import Foundation

// Fix catalog entry 0 for OS
let diskPath = "/Users/senioradvisor/Desktop/AlanWilder_HD10.hda"
let workingDiskPath = "/Users/senioradvisor/clawd/EmaxForge/SD_BOOT2/Funkar/HD00.hda"

print("🔧 Fixing OS catalog entry in \(diskPath)")
print("")

// Load our disk
guard var diskData = try? Data(contentsOf: URL(fileURLWithPath: diskPath)) else {
    print("❌ Could not load disk")
    exit(1)
}

// Load working disk to extract correct OS catalog entry
guard let workingData = try? Data(contentsOf: URL(fileURLWithPath: workingDiskPath)) else {
    print("❌ Could not load working disk")
    exit(1)
}

// Extract OS catalog entry from working disk (offset 0xC400, 24 bytes)
let catalogOffset = 50176
let osCatalogEntry = workingData.subdata(in: catalogOffset..<(catalogOffset + 24))

print("📋 OS Catalog Entry from working disk:")
print(osCatalogEntry.map { String(format: "%02x", $0) }.joined(separator: " "))
print("")

// Write OS catalog entry to our disk
diskData.replaceSubrange(catalogOffset..<(catalogOffset + 24), with: osCatalogEntry)

print("✅ OS catalog entry written")
print("")

// Backup original
let backupPath = "/Users/senioradvisor/Desktop/AlanWilder_HD10.hda.backup"
do {
    try FileManager.default.copyItem(atPath: diskPath, toPath: backupPath)
    print("💾 Backup saved: AlanWilder_HD10.hda.backup")
} catch {
    print("⚠️  Could not create backup: \(error)")
}

// Write fixed disk
do {
    try diskData.write(to: URL(fileURLWithPath: diskPath))
    print("✅ Disk fixed and saved!")
    print("")
    print("🎯 Try booting EMAX II again!")
} catch {
    print("❌ Could not write fixed disk: \(error)")
    exit(1)
}
