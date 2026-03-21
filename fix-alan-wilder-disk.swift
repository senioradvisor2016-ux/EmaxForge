#!/usr/bin/env swift

import Foundation

// Fix AlanWilder HD10 by copying working bank catalog entry from Funkar disk
let diskPath = "/Users/senioradvisor/Desktop/AlanWilder_HD10.hda"
let workingPath = "/Users/senioradvisor/clawd/EmaxForge/SD_BOOT2/Funkar/HD00.hda"

print("🔧 Fixing AlanWilder HD10 with proper bank catalog entry")
print("")

// Load disks
guard var diskData = try? Data(contentsOf: URL(fileURLWithPath: diskPath)) else {
    print("❌ Could not load AlanWilder disk")
    exit(1)
}

guard let workingData = try? Data(contentsOf: URL(fileURLWithPath: workingPath)) else {
    print("❌ Could not load working disk")
    exit(1)
}

// Copy bank catalog entry from working disk (entry 1, offset 50200, 24 bytes)
let bankCatalogOffset = 50200
let workingBankEntry = workingData.subdata(in: bankCatalogOffset..<(bankCatalogOffset + 24))

print("📋 Copying bank catalog entry from Funkar disk:")
print(workingBankEntry.map { String(format: "%02x", $0) }.joined(separator: " "))
print("")

// Write to our disk
diskData.replaceSubrange(bankCatalogOffset..<(bankCatalogOffset + 24), with: workingBankEntry)

print("✅ Bank catalog entry written")
print("")

// Also fix FAT entry 2 to match working disk (0x0003 = chain continues to cluster 3)
let fatEntry2Offset = 1028
diskData[fatEntry2Offset] = 0x03
diskData[fatEntry2Offset + 1] = 0x00

print("✅ FAT entry 2 set to 0x0003 (bank chain)")
print("")

// Write fixed disk
do {
    try diskData.write(to: URL(fileURLWithPath: diskPath))
    print("✅ AlanWilder HD10 fixed!")
    print("")
    print("🎯 Disk now has:")
    print("   • Correct OS catalog entry (entry 0)")
    print("   • Correct bank catalog entry (entry 1, copied from Funkar)")
    print("   • Correct FAT structure")
    print("")
    print("🚀 Ready to test on EMAX II!")
} catch {
    print("❌ Could not write: \(error)")
    exit(1)
}
