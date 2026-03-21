#!/usr/bin/swift
import Foundation

// MARK: - Import Banks to EMAX II Disk Image (CLI)

struct BankImporter {
    static func importBanks(diskPath: String, bankFiles: [String]) throws {
        print("🔧 Importing \(bankFiles.count) banks to \(diskPath)...")
        
        // Read disk image
        let diskURL = URL(fileURLWithPath: diskPath)
        guard let diskData = try? Data(contentsOf: diskURL) else {
            throw ImportError.cannotReadDisk
        }
        
        var mutableDisk = diskData
        
        // Parse disk header
        let header = try parseHeader(data: diskData)
        print("📊 Disk info:")
        print("   Size: \(diskData.count / (1024*1024)) MB")
        print("   Cluster size: \(header.clusterSize) bytes")
        print("   Free clusters: \(header.freeClusters)")
        print("   Banks on disk: \(header.bankCount)")
        print("")
        
        // Import each bank
        var importedCount = 0
        var nextCluster = findFirstFreeCluster(data: diskData, header: header)
        
        for (index, bankPath) in bankFiles.enumerated() {
            let bankURL = URL(fileURLWithPath: bankPath)
            let bankName = bankURL.deletingPathExtension().lastPathComponent
            
            print("[\(index+1)/\(bankFiles.count)] Importing \(bankName)...")
            
            guard let bankData = try? Data(contentsOf: bankURL) else {
                print("   ⚠️  Skipping (cannot read)")
                continue
            }
            
            // Calculate clusters needed
            let clustersNeeded = (bankData.count + header.clusterSize - 1) / header.clusterSize
            
            if nextCluster + clustersNeeded > header.totalClusters {
                print("   ❌ Disk full! Imported \(importedCount) banks.")
                break
            }
            
            // Write bank data to clusters
            let clusterAreaStart = header.clusterAreaStartSector * 512
            let dataOffset = clusterAreaStart + (nextCluster * header.clusterSize)
            
            mutableDisk.replaceSubrange(dataOffset..<dataOffset+bankData.count, with: bankData)
            
            // Update FAT
            try updateFAT(
                disk: &mutableDisk,
                header: header,
                startCluster: nextCluster,
                clusterCount: clustersNeeded
            )
            
            // Update catalog
            try updateCatalog(
                disk: &mutableDisk,
                header: header,
                index: header.bankCount + importedCount,
                name: bankName,
                startCluster: nextCluster,
                size: bankData.count
            )
            
            print("   ✅ Imported (\(clustersNeeded) clusters, \(bankData.count/1024) KB)")
            
            nextCluster += clustersNeeded
            importedCount += 1
        }
        
        // Update header (bank count)
        let newBankCount = header.bankCount + importedCount
        mutableDisk.writeU32LE(UInt32(newBankCount), at: 0x14)
        
        // Write updated disk
        try mutableDisk.write(to: diskURL)
        
        print("")
        print("========================================")
        print("✅ Import Complete!")
        print("========================================")
        print("Banks imported: \(importedCount)")
        print("Total banks on disk: \(newBankCount)")
        print("")
    }
    
    // MARK: - Helpers
    
    static func parseHeader(data: Data) throws -> DiskHeader {
        guard data.count > 512 else { throw ImportError.invalidDisk }
        
        let clusterSize = Int(data.readU16LE(at: 0x0B))
        let clusterAreaStartSector = Int(data.readU16LE(at: 0x0E))
        let totalClusters = Int(data.readU32LE(at: 0x10))
        let bankCount = Int(data.readU32LE(at: 0x14))
        let freeClusters = Int(data.readU32LE(at: 0x18))
        
        return DiskHeader(
            clusterSize: clusterSize,
            clusterAreaStartSector: clusterAreaStartSector,
            totalClusters: totalClusters,
            bankCount: bankCount,
            freeClusters: freeClusters
        )
    }
    
    static func findFirstFreeCluster(data: Data, header: DiskHeader) -> Int {
        // FAT starts at sector 1 (offset 512)
        let fatStart = 512
        
        // Skip cluster 0 (OS), cluster 1 (INIT BANK)
        for cluster in 2..<header.totalClusters {
            let fatEntry = data.readU16LE(at: fatStart + (cluster * 2))
            if fatEntry == 0x0000 {  // Free cluster
                return cluster
            }
        }
        
        return header.totalClusters  // Disk full
    }
    
    static func updateFAT(disk: inout Data, header: DiskHeader, startCluster: Int, clusterCount: Int) throws {
        let fatStart = 512
        
        for i in 0..<clusterCount {
            let cluster = startCluster + i
            let nextCluster = (i == clusterCount - 1) ? 0x7FFF : (startCluster + i + 1)
            disk.writeU16LE(UInt16(nextCluster), at: fatStart + (cluster * 2))
        }
    }
    
    static func updateCatalog(disk: inout Data, header: DiskHeader, index: Int, name: String, startCluster: Int, size: Int) throws {
        // Catalog starts at sector 33 (offset 16896)
        let catalogStart = 33 * 512
        let entrySize = 32
        let entryOffset = catalogStart + (index * entrySize)
        
        // Write name (14 bytes, space-padded)
        var nameBytes = Data(count: 14)
        let truncatedName = String(name.prefix(14))
        for (i, char) in truncatedName.enumerated() {
            nameBytes[i] = char.asciiValue ?? 0x20
        }
        // Pad with spaces
        for i in truncatedName.count..<14 {
            nameBytes[i] = 0x20
        }
        
        disk.replaceSubrange(entryOffset..<entryOffset+14, with: nameBytes)
        
        // Write cluster pointer (offset +14)
        disk.writeU16LE(UInt16(startCluster), at: entryOffset + 14)
        
        // Write size (offset +16, 4 bytes)
        disk.writeU32LE(UInt32(size), at: entryOffset + 16)
        
        // Write flags (offset +26, 2 bytes) - 0x0081 for bank
        disk.writeU16LE(0x0081, at: entryOffset + 26)
    }
    
    struct DiskHeader {
        let clusterSize: Int
        let clusterAreaStartSector: Int
        let totalClusters: Int
        let bankCount: Int
        let freeClusters: Int
    }
    
    enum ImportError: Error {
        case cannotReadDisk
        case invalidDisk
        case diskFull
    }
}

// MARK: - Data Extensions

extension Data {
    func readU16LE(at offset: Int) -> UInt16 {
        guard offset + 1 < count else { return 0 }
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }
    
    func readU32LE(at offset: Int) -> UInt32 {
        guard offset + 3 < count else { return 0 }
        return UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }
    
    mutating func writeU16LE(_ value: UInt16, at offset: Int) {
        guard offset + 1 < count else { return }
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8) & 0xFF)
    }
    
    mutating func writeU32LE(_ value: UInt32, at offset: Int) {
        guard offset + 3 < count else { return }
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8) & 0xFF)
        self[offset + 2] = UInt8((value >> 16) & 0xFF)
        self[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
}

// MARK: - Main

guard CommandLine.argc >= 3 else {
    print("Usage: \(CommandLine.arguments[0]) <disk.hda> <bank1.EB2> [bank2.EB2 ...]")
    print("")
    print("Example:")
    print("  swift cli-import-banks.swift HD10.hda ~/banks/*.EB2")
    exit(1)
}

let diskPath = CommandLine.arguments[1]
let bankFiles = Array(CommandLine.arguments.dropFirst(2))

do {
    try BankImporter.importBanks(diskPath: diskPath, bankFiles: bankFiles)
} catch {
    print("❌ Import failed: \(error)")
    exit(1)
}
