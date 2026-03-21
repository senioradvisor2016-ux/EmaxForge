#!/usr/bin/env swift

import Foundation

// Paths
let projectRoot = "/Users/senioradvisor/clawd/EmaxForge"
let alanWilderDir = "/Users/senioradvisor/clawd/standard/EMAX2SF2/Alan Wilder - Depeche Mode [Emax II]"
let outputDir = "/Users/senioradvisor/Desktop"
let resourcesDir = "\(projectRoot)/EmaxForge/Resources"

// Configuration
let diskSize = 239 // MB
let diskSizeBytes: UInt64 = 250_398_720 // 239 MB exact

print("🎛️ Creating Alan Wilder Boot Disk")
print(String(repeating: "=", count: 50))
print("Source: \(alanWilderDir)")
print("Output: \(outputDir)")
print("Size: \(diskSize) MB")
print("")

// Step 1: Create boot disk (HD10.hda with OS)
print("📀 Step 1: Creating boot disk (HD10.hda)...")

let hd10Path = "\(outputDir)/AlanWilder_HD10.hda"
let osPath = "\(resourcesDir)/emax2_os.bin"
let templatePath = "\(resourcesDir)/emax2_header_239.bin"

// Check if OS file exists
let fm = FileManager.default
guard fm.fileExists(atPath: osPath) else {
    print("❌ ERROR: OS file not found at \(osPath)")
    exit(1)
}

guard fm.fileExists(atPath: templatePath) else {
    print("❌ ERROR: Template file not found at \(templatePath)")
    exit(1)
}

// Load template
guard let templateData = try? Data(contentsOf: URL(fileURLWithPath: templatePath)) else {
    print("❌ ERROR: Could not load template")
    exit(1)
}

guard let osData = try? Data(contentsOf: URL(fileURLWithPath: osPath)) else {
    print("❌ ERROR: Could not load OS data")
    exit(1)
}

print("  ✅ Template loaded (2048 bytes)")
print("  ✅ OS data loaded (\(osData.count) bytes)")

// Create HD10 image with template + OS
var hd10Data = Data(count: Int(diskSizeBytes))

// Copy template (first 2048 bytes)
hd10Data.replaceSubrange(0..<2048, with: templateData)

// Write OS to cluster 1 (offset from standard tools analysis)
let clusterSize = 489472
let clusterAreaStart = 98 * 512 // sector 98
let cluster1Offset = clusterAreaStart + clusterSize

if cluster1Offset + osData.count <= hd10Data.count {
    hd10Data.replaceSubrange(cluster1Offset..<(cluster1Offset + osData.count), with: osData)
    print("  ✅ OS written to cluster 1 (offset \(cluster1Offset))")
} else {
    print("❌ ERROR: OS too large for disk")
    exit(1)
}

// Add INIT BANK at cluster 2 (minimal bank for bootability)
let cluster2Offset = clusterAreaStart + (2 * clusterSize)
let initBankData = Data([0x00, 0x01]) // Minimal bank marker
hd10Data.replaceSubrange(cluster2Offset..<(cluster2Offset + 2), with: initBankData)

// Update FAT for INIT BANK
var fatOffset = 1024
hd10Data[fatOffset + 4] = 0xFF  // FAT entry 2 = 0x7FFF (end marker)
hd10Data[fatOffset + 5] = 0x7F

// Update catalog for INIT BANK
var catalogOffset = 50176 + 24 // Second catalog entry
let initBankName = "INIT BANK       ".data(using: .ascii)!
hd10Data.replaceSubrange(catalogOffset..<(catalogOffset + 16), with: initBankName)
hd10Data[catalogOffset + 22] = 0x81 // FLAGS
hd10Data[catalogOffset + 23] = 0x00

print("  ✅ INIT BANK added at cluster 2")

// Write HD10 to disk
do {
    try hd10Data.write(to: URL(fileURLWithPath: hd10Path))
    print("✅ Boot disk created: AlanWilder_HD10.hda")
} catch {
    print("❌ ERROR: Could not write HD10: \(error)")
    exit(1)
}

// Step 2: Create data disk (HD20.hda empty)
print("")
print("📀 Step 2: Creating data disk (HD20.hda)...")

let hd20Path = "\(outputDir)/AlanWilder_HD20.hda"

// Create empty disk with template
var hd20Data = Data(count: Int(diskSizeBytes))
hd20Data.replaceSubrange(0..<2048, with: templateData)

do {
    try hd20Data.write(to: URL(fileURLWithPath: hd20Path))
    print("✅ Data disk created: AlanWilder_HD20.hda")
} catch {
    print("❌ ERROR: Could not write HD20: \(error)")
    exit(1)
}

// Step 3: Find and filter banks
print("")
print("🎵 Step 3: Finding Alan Wilder banks...")

let alanWilderURL = URL(fileURLWithPath: alanWilderDir)
guard let files = try? fm.contentsOfDirectory(at: alanWilderURL, includingPropertiesForKeys: [.fileSizeKey]) else {
    print("❌ ERROR: Could not read Alan Wilder directory")
    exit(1)
}

let eb2Files = files.filter { $0.pathExtension.lowercased() == "eb2" }
let filteredBanks = eb2Files.filter { url in
    guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return false }
    return size < 1_500_000 // <1.5 MB
}.sorted { $0.lastPathComponent < $1.lastPathComponent }

print("  Found: \(eb2Files.count) total banks")
print("  Filtered: \(filteredBanks.count) banks <1.5MB")
print("")

// Step 4: List banks to import
print("📋 Banks to import:")
for (i, bank) in filteredBanks.enumerated() {
    let size = (try? bank.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    let sizeMB = Double(size) / 1_048_576
    print(String(format: "  %2d. %-30s (%.2f MB)", i+1, bank.lastPathComponent, sizeMB))
}

print("")
print("⚠️  NOTE: Bank import requires EmaxForge's BankImporter class")
print("   This script creates the disks. Import banks manually via GUI:")
print("")
print("   1. Open AlanWilder_HD20.hda in EmaxForge")
print("   2. Click 'Import Banks'")
print("   3. Select the \(filteredBanks.count) banks listed above")
print("   4. Click 'Import'")
print("")

// Step 5: Create ZuluSCSI config
print("⚙️  Step 4: Creating ZuluSCSI config...")

let configPath = "\(outputDir)/zuluscsi.ini"
let configContent = """
[SCSI]
Debug=0

[SCSI1]
Type=1
Image=AlanWilder_HD10.hda

[SCSI2]
Type=1
Image=AlanWilder_HD20.hda
"""

do {
    try configContent.write(toFile: configPath, atomically: true, encoding: .utf8)
    print("✅ Config created: zuluscsi.ini")
} catch {
    print("❌ ERROR: Could not write config: \(error)")
    exit(1)
}

// Summary
print("")
print(String(repeating: "=", count: 50))
print("✅ DISK CREATION COMPLETE!")
print(String(repeating: "=", count: 50))
print("")
print("📦 Output files:")
print("   \(hd10Path)")
print("   \(hd20Path)")
print("   \(configPath)")
print("")
print("🎯 Next Steps:")
print("   1. Open EmaxForge")
print("   2. Open AlanWilder_HD20.hda")
print("   3. Import the \(filteredBanks.count) banks manually")
print("   4. Copy all files to ZuluSCSI SD card")
print("   5. Test on EMAX II!")
print("")

// Save bank list for reference
let bankListPath = "\(outputDir)/alan-wilder-banks.txt"
let bankList = filteredBanks.map { $0.lastPathComponent }.joined(separator: "\n")
try? bankList.write(toFile: bankListPath, atomically: true, encoding: .utf8)
print("📝 Bank list saved: alan-wilder-banks.txt")
print("")
