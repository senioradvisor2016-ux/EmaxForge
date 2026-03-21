#!/usr/bin/env swift

import Foundation

// Test: Import bank using EmaxForge logic (mimic BankImporter)

let diskPath = "/Users/senioradvisor/clawd/EmaxForge/test_output/TEST_DISK.hda"
let bankPath = "/Users/senioradvisor/clawd/standard/Beef_Drums.EB2"

print("🧪 Testing Bank Import...")
print("📀 Disk: \(diskPath)")
print("🎹 Bank: \(bankPath)")

// 1. Clear demo banks (entries 1-3, keep entry 0 = OS)
guard let diskHandle = FileHandle(forUpdatingAtPath: diskPath) else {
    print("❌ Can't open disk!")
    exit(1)
}

print("\n1️⃣ Clearing demo banks (entries 1-3)...")

// Clear catalog entries 1-3 (each 64 bytes)
for entryIndex in 1...3 {
    let offset = 0x1000 + (entryIndex * 64)
    diskHandle.seek(toFileOffset: UInt64(offset))
    diskHandle.write(Data(count: 64))  // Zero out entry
}

print("✅ Demo banks cleared")

// 2. Read bank file
print("\n2️⃣ Reading bank file...")

guard let bankData = try? Data(contentsOf: URL(fileURLWithPath: bankPath)) else {
    print("❌ Can't read bank file!")
    diskHandle.closeFile()
    exit(1)
}

print("✅ Bank size: \(bankData.count) bytes")

// 3. Check catalog count (should be 1 now = OS only)
print("\n3️⃣ Counting catalog entries...")

diskHandle.seek(toFileOffset: 0x1000)
var catalogCount = 0
for _ in 0..<128 {
    let entry = diskHandle.readData(ofLength: 64)
    if entry[0] == 0 {
        break
    }
    catalogCount += 1
}

print("✅ Catalog count: \(catalogCount) (should be 1 = OS only)")

// 4. Allocate clusters for bank
print("\n4️⃣ Allocating clusters...")

let clusterSize = 16384  // 16 KB (239 MB disk)
let clustersNeeded = (bankData.count + clusterSize - 1) / clusterSize

print("   Bank needs: \(clustersNeeded) clusters")

// Find free clusters (simplified - use clusters 2+)
var allocatedClusters: [Int] = []
for i in 0..<clustersNeeded {
    allocatedClusters.append(2 + i)
}

print("✅ Allocated: \(allocatedClusters)")

// 5. Write bank data to clusters
print("\n5️⃣ Writing bank data to clusters...")

let clusterAreaStart = 98 * 512  // Sector 98 (from template)

for (index, cluster) in allocatedClusters.enumerated() {
    let clusterOffset = clusterAreaStart + (cluster * clusterSize)
    let dataStart = index * clusterSize
    let dataEnd = min(dataStart + clusterSize, bankData.count)
    let chunk = bankData[dataStart..<dataEnd]
    
    diskHandle.seek(toFileOffset: UInt64(clusterOffset))
    diskHandle.write(chunk)
}

print("✅ Bank data written to \(clustersNeeded) clusters")

// 6. Update FAT chain
print("\n6️⃣ Updating FAT...")

diskHandle.seek(toFileOffset: 0x0400)  // FAT start
var fatData = diskHandle.readData(ofLength: 1024)

// Write FAT chain
for (index, cluster) in allocatedClusters.enumerated() {
    let fatOffset = cluster * 2
    if index < allocatedClusters.count - 1 {
        // Point to next cluster
        let nextCluster = allocatedClusters[index + 1]
        fatData[fatOffset] = UInt8(nextCluster & 0xFF)
        fatData[fatOffset + 1] = UInt8((nextCluster >> 8) & 0xFF)
    } else {
        // End-of-chain marker
        fatData[fatOffset] = 0xFF
        fatData[fatOffset + 1] = 0x7F
    }
}

diskHandle.seek(toFileOffset: 0x0400)
diskHandle.write(fatData)

print("✅ FAT chain updated")

// 7. Create catalog entry
print("\n7️⃣ Creating catalog entry...")

var catalogEntry = Data(count: 64)  // ✅ 64 bytes now!

// Bank name
let bankName = "Beef_Drums"
let nameData = bankName.padding(toLength: 16, withPad: " ", startingAt: 0).data(using: .ascii)!
catalogEntry.replaceSubrange(0..<16, with: nameData.prefix(16))

// Bank index: (catalogCount - 1) * 256 = (1-1)*256 = 0
let bankIndex: UInt16 = UInt16(max(0, catalogCount - 1) * 256)
catalogEntry[16] = UInt8(bankIndex & 0xFF)
catalogEntry[17] = UInt8((bankIndex >> 8) & 0xFF)

// Start cluster
let startCluster = UInt16(allocatedClusters[0])
catalogEntry[18] = UInt8(startCluster & 0xFF)
catalogEntry[19] = UInt8((startCluster >> 8) & 0xFF)

// Presets (default: 1)
catalogEntry[20] = 0x01
catalogEntry[21] = 0x00

// Field A, B (0)
catalogEntry[22] = 0x00
catalogEntry[23] = 0x00
catalogEntry[24] = 0x00
catalogEntry[25] = 0x00

// FLAGS: 0x0081
catalogEntry[26] = 0x81
catalogEntry[27] = 0x00

// Rest = zeros (already allocated as 64 bytes)

// 8. Write catalog entry
print("\n8️⃣ Writing catalog entry...")

let catalogEntryOffset = 0x1000 + (catalogCount * 64)
diskHandle.seek(toFileOffset: UInt64(catalogEntryOffset))
diskHandle.write(catalogEntry)

// Write end-of-catalog marker
diskHandle.write(Data(count: 64))

print("✅ Catalog entry written at offset 0x\(String(catalogEntryOffset, radix: 16))")

diskHandle.closeFile()

print("\n✅ SUCCESS! Bank imported!")
print("\n🔍 Verifying...")

// Verify catalog
guard let verifyHandle = FileHandle(forReadingAtPath: diskPath) else {
    print("❌ Can't open for verify")
    exit(1)
}

verifyHandle.seek(toFileOffset: UInt64(catalogEntryOffset))
let verifyEntry = verifyHandle.readData(ofLength: 64)

let verifyName = String(data: verifyEntry[0..<16], encoding: .ascii) ?? ""
let verifyIndex = UInt16(verifyEntry[16]) | (UInt16(verifyEntry[17]) << 8)
let verifyCluster = UInt16(verifyEntry[18]) | (UInt16(verifyEntry[19]) << 8)
let verifyFlags = UInt16(verifyEntry[26]) | (UInt16(verifyEntry[27]) << 8)

print("   Name: '\(verifyName)'")
print("   Index: 0x\(String(verifyIndex, radix: 16, uppercase: true))")
print("   Cluster: \(verifyCluster)")
print("   FLAGS: 0x\(String(verifyFlags, radix: 16, uppercase: true))")

if verifyFlags == 0x0081 && verifyCluster == startCluster {
    print("\n🎉 ALL CHECKS PASSED!")
} else {
    print("\n⚠️ MISMATCH DETECTED!")
}

verifyHandle.closeFile()
