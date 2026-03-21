#!/usr/bin/env swift
// EmaxForge CLI - Import existing .EB2 banks to HD image

import Foundation

print("📥 EmaxForge CLI - EB2 Bank Importer")
print("====================================\n")

// MARK: - Helpers

extension Data {
    func readU16LE(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }
    
    func readU32LE(at offset: Int) -> UInt32 {
        UInt32(self[offset]) |
        (UInt32(self[offset + 1]) << 8) |
        (UInt32(self[offset + 2]) << 16) |
        (UInt32(self[offset + 3]) << 24)
    }
    
    mutating func writeU16LE(_ value: UInt16, at offset: Int) {
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8) & 0xFF)
    }
    
    mutating func writeU32LE(_ value: UInt32, at offset: Int) {
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8) & 0xFF)
        self[offset + 2] = UInt8((value >> 16) & 0xFF)
        self[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
}

// MARK: - Disk Image Writer

func importBankToImage(bankData: Data, bankName: String, imageURL: URL) throws -> (clusters: Int, bytes: Int) {
    let handle = try FileHandle(forUpdating: imageURL)
    
    // Get original file size (don't truncate!)
    let originalSize = try handle.seekToEnd()
    
    defer {
        // Ensure file doesn't grow beyond original size
        try? handle.truncate(atOffset: originalSize)
        try? handle.close()
    }
    
    // Read header
    handle.seek(toFileOffset: 0)
    let header = handle.readData(ofLength: 512)
    
    let clusterSize = Int(header.readU32LE(at: 4))
    let clusterAreaStart = UInt64(header.readU32LE(at: 0x20)) * 512
    
    // Read FAT
    handle.seek(toFileOffset: 0x400)
    let fatSize = 1024
    var fatData = handle.readData(ofLength: fatSize)
    var fat = [UInt16]()
    for i in stride(from: 0, to: fatSize, by: 2) {
        fat.append(fatData.readU16LE(at: i))
    }
    
    // Find free clusters
    let clustersNeeded = (bankData.count + clusterSize - 1) / clusterSize
    var freeClusters = [Int]()
    for i in 2..<512 {
        if fat[i] == 0 {
            freeClusters.append(i)
        }
        if freeClusters.count >= clustersNeeded { break }
    }
    
    guard freeClusters.count >= clustersNeeded else {
        throw NSError(domain: "EmaxForge", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Not enough space (need \(clustersNeeded), have \(freeClusters.count))"
        ])
    }
    
    let allocated = Array(freeClusters.prefix(clustersNeeded))
    
    // Write bank data to clusters
    for (i, cluster) in allocated.enumerated() {
        let dataStart = i * clusterSize
        let dataEnd = min(dataStart + clusterSize, bankData.count)
        let chunk = bankData[dataStart..<dataEnd]
        
        let offset = clusterAreaStart + UInt64(cluster) * UInt64(clusterSize)
        handle.seek(toFileOffset: offset)
        handle.write(chunk)
        
        // Pad
        if chunk.count < clusterSize {
            handle.write(Data(count: clusterSize - chunk.count))
        }
    }
    
    // Update FAT
    for i in 0..<allocated.count {
        let cluster = allocated[i]
        if i < allocated.count - 1 {
            fat[cluster] = UInt16(allocated[i + 1])
        } else {
            fat[cluster] = 0x7FFF // End of chain
        }
    }
    
    // Write FAT back
    for i in 0..<fat.count {
        fatData.writeU16LE(fat[i], at: i * 2)
    }
    handle.seek(toFileOffset: 0x400)
    handle.write(fatData)
    
    // Write Catalog entry (EMAX II format)
    let catalogStart: UInt64 = 0x600 // Catalog starts at 0x600
    
    // Find free slot in catalog
    handle.seek(toFileOffset: catalogStart)
    let catalogData = handle.readData(ofLength: 90 * 32) // Max 90 entries
    
    var freeSlot: Int? = nil
    for i in 1..<90 {  // Start at 1 (slot 0 is OS)
        let offset = i * 32
        let firstByte = catalogData[offset]
        if firstByte == 0 || firstByte == 0xFF {
            freeSlot = i
            break
        }
    }
    
    guard let slot = freeSlot else {
        throw NSError(domain: "EmaxForge", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "No free catalog slots"
        ])
    }
    
    // Write Catalog entry
    var catalogEntry = Data(count: 32)
    let paddedName = bankName.prefix(14).padding(toLength: 14, withPad: " ", startingAt: 0)
    if let nameData = paddedName.data(using: .ascii) {
        catalogEntry.replaceSubrange(0..<14, with: nameData.prefix(14))
    }
    catalogEntry.writeU16LE(UInt16(allocated[0]), at: 14) // Start cluster
    catalogEntry.writeU32LE(UInt32(bankData.count), at: 16) // Size
    catalogEntry[26] = 0x81 // FLAGS (little-endian 0x8100)
    catalogEntry[27] = 0x00
    
    handle.seek(toFileOffset: catalogStart + UInt64(slot * 32))
    handle.write(catalogEntry)
    
    return (clusters: clustersNeeded, bytes: bankData.count)
}

// MARK: - Main

// Parse arguments
guard CommandLine.arguments.count >= 3 else {
    print("Usage: cli-import-eb2-banks.swift <disk.hda> <banks_directory> [max_banks]")
    print("")
    print("Example:")
    print("  swift cli-import-eb2-banks.swift HD10.hda ~/clawd/standard/Images/EMAX\\ II/Bank\\ Images/ 50")
    exit(1)
}

let imageURL = URL(fileURLWithPath: CommandLine.arguments[1])
let eb2Dir = URL(fileURLWithPath: CommandLine.arguments[2])
let maxBanks = CommandLine.arguments.count >= 4 ? Int(CommandLine.arguments[3]) ?? 10 : 10

do {
    // Find .EB2 files (filter out large files > 1.5 MB)
    let eb2Files = try FileManager.default.contentsOfDirectory(at: eb2Dir, includingPropertiesForKeys: [.fileSizeKey])
        .filter { url in
            guard url.pathExtension.uppercased() == "EB2" else { return false }
            // Only import banks < 1.5 MB to fit more on disk
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                return size < 1_500_000
            }
            return true
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
        .prefix(maxBanks)
    
    guard !eb2Files.isEmpty else {
        print("❌ No .EB2 files found in \(eb2Dir.path)")
        exit(1)
    }
    
    print("📂 Found \(eb2Files.count) .EB2 banks\n")
    
    var totalClusters = 0
    var totalBytes = 0
    var imported = 0
    
    for url in eb2Files {
        let bankData = try Data(contentsOf: url)
        let bankName = url.deletingPathExtension().lastPathComponent
        
        print("📄 Importing: \(bankName)")
        print("   Size: \(bankData.count / 1024) KB")
        
        let result = try importBankToImage(bankData: bankData, bankName: bankName, imageURL: imageURL)
        
        print("   ✅ Imported (\(result.clusters) clusters)\n")
        
        totalClusters += result.clusters
        totalBytes += result.bytes
        imported += 1
    }
    
    print("🎉 Import complete!")
    print("   Banks imported: \(imported)")
    print("   Total size: \(totalBytes / 1024) KB")
    print("   Total clusters: \(totalClusters)")
    print("\n📦 Banks on HD20.hda:")
    for (i, url) in eb2Files.enumerated() {
        print("   \(i+1). \(url.deletingPathExtension().lastPathComponent)")
    }
    
} catch {
    print("❌ Error: \(error.localizedDescription)")
    exit(1)
}
