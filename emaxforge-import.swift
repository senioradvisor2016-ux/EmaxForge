#!/usr/bin/swift
/// emaxforge-import.swift
/// Mirrors BankImporter.swift exactly — correct offsets, correct FAT at 0x400, correct cluster formula.
/// Usage: swift emaxforge-import.swift <disk.hda> <bank1.EB2> [bank2.EB2 ...]
/// Output: disk.hda is modified in-place.

import Foundation

// MARK: - Data helpers

extension Data {
    func readU16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return withUnsafeBytes { $0.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt16.self) }
    }
    func readU32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return withUnsafeBytes { $0.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt32.self) }
    }
    mutating func writeU16LE(_ value: UInt16, at offset: Int) {
        self[offset]     = UInt8(value & 0xFF)
        self[offset + 1] = UInt8(value >> 8)
    }
}

// MARK: - Disk geometry (mirrors BankImporter.DiskGeometry)

struct DiskGeometry {
    let clusterSize:            Int
    let fatSectors:             UInt32
    let bntStartSector:         UInt32
    let maxBanks:               Int
    let clusterAreaStartSector: UInt32
    let totalClusters:          Int

    var fatOffset:        UInt64 { 0x400 }                             // ALWAYS
    var fatSize:          Int    { Int(fatSectors) * 512 }
    var fatEntryCount:    Int    { fatSize / 2 }
    var bntOffset:        UInt64 { UInt64(bntStartSector) * 512 }
    var clusterAreaOffset:UInt64 { UInt64(clusterAreaStartSector) * 512 }

    /// cluster n → clusterAreaOffset + n * clusterSize  (1-based, cluster 1 = OS)
    func clusterOffset(_ cluster: Int) -> UInt64 {
        clusterAreaOffset + UInt64(cluster) * UInt64(clusterSize)
    }
}

func parseGeometry(header: Data) throws -> DiskGeometry {
    guard header.count >= 40 else { throw NSError(domain:"emaxforge", code:1, userInfo:[NSLocalizedDescriptionKey:"Header too small"]) }
    guard String(data: header[0..<4], encoding: .ascii) == "EMX2" else {
        throw NSError(domain:"emaxforge", code:2, userInfo:[NSLocalizedDescriptionKey:"Not an EMAX II image (no EMX2 magic)"])
    }
    return DiskGeometry(
        clusterSize:            Int(header.readU32LE(at: 0x04)),
        fatSectors:             header.readU32LE(at: 0x1C),
        bntStartSector:         header.readU32LE(at: 0x10),
        maxBanks:               Int(header.readU32LE(at: 0x14)),
        clusterAreaStartSector: header.readU32LE(at: 0x20),
        totalClusters:          Int(header.readU32LE(at: 0x24))
    )
}

// MARK: - Import one bank

func importBank(bankURL: URL, into imageURL: URL) throws {
    let bankData = try Data(contentsOf: bankURL)
    guard bankData.count >= 512 else {
        throw NSError(domain:"emaxforge", code:3, userInfo:[NSLocalizedDescriptionKey:"Bank file too small"])
    }

    var bankName = bankURL.deletingPathExtension().lastPathComponent
    if bankName.count > 14 { bankName = String(bankName.prefix(14)) }

    let handle = try FileHandle(forUpdating: imageURL)
    defer { handle.closeFile() }

    handle.seek(toFileOffset: 0)
    let headerData = handle.readData(ofLength: 512)
    let geo = try parseGeometry(header: headerData)

    // Read FAT
    handle.seek(toFileOffset: geo.fatOffset)
    let fatRaw = handle.readData(ofLength: geo.fatSize)
    var fat = [UInt16]()
    fat.reserveCapacity(geo.fatEntryCount)
    for i in stride(from: 0, to: min(geo.fatSize, fatRaw.count), by: 2) {
        fat.append(fatRaw.readU16LE(at: i))
    }

    let clustersNeeded = (bankData.count + geo.clusterSize - 1) / geo.clusterSize

    // Free clusters: skip 0 (header magic) and 1 (OS)
    var free = [Int]()
    for i in 2..<min(fat.count, geo.totalClusters + 2) {
        if fat[i] == 0x0000 { free.append(i); if free.count >= clustersNeeded { break } }
    }
    guard free.count >= clustersNeeded else {
        let totalFree = (2..<min(fat.count, geo.totalClusters + 2)).filter { fat[$0] == 0x0000 }.count
        throw NSError(domain:"emaxforge", code:4, userInfo:[NSLocalizedDescriptionKey:"No space: need \(clustersNeeded) clusters, \(totalFree) free"])
    }

    let alloc = Array(free.prefix(clustersNeeded))

    // Write bank data cluster by cluster
    for (i, cluster) in alloc.enumerated() {
        let start = i * geo.clusterSize
        let end   = min(start + geo.clusterSize, bankData.count)
        var chunk = Data(bankData[start..<end])
        if chunk.count < geo.clusterSize { chunk.append(Data(count: geo.clusterSize - chunk.count)) }
        handle.seek(toFileOffset: geo.clusterOffset(cluster))
        handle.write(chunk)
    }

    // Update FAT
    for i in 0..<alloc.count {
        fat[alloc[i]] = i < alloc.count - 1 ? UInt16(alloc[i + 1]) : 0x7FFF
    }
    var newFat = Data(count: geo.fatSize)
    for i in 0..<fat.count {
        newFat[i * 2]     = UInt8(fat[i] & 0xFF)
        newFat[i * 2 + 1] = UInt8(fat[i] >> 8)
    }
    handle.seek(toFileOffset: geo.fatOffset)
    handle.write(newFat)

    // Find free BNT slot (slot 0 = OS, skip it)
    let bntTotalSize = Int(geo.clusterAreaStartSector - geo.bntStartSector) * 512
    handle.seek(toFileOffset: geo.bntOffset)
    let bntRaw = handle.readData(ofLength: bntTotalSize)
    let maxSlots = min(geo.maxBanks + 1, bntTotalSize / 32)
    var slotIndex = -1
    for i in 1..<maxSlots {
        let s = i * 32; let e = s + 32
        guard e <= bntRaw.count else { break }
        let slot = bntRaw[s..<e]
        // Free slot: all zeros OR all 0x42 (EMXP placeholder "BBBBBBB..." entries)
        let isFree = slot.allSatisfy({ $0 == 0x00 }) || slot.allSatisfy({ $0 == 0x42 })
        if isFree { slotIndex = i; break }
    }
    guard slotIndex >= 0 else {
        throw NSError(domain:"emaxforge", code:5, userInfo:[NSLocalizedDescriptionKey:"BNT full (no free bank slot)"])
    }

    // Build 32-byte BNT entry
    var entry = Data(count: 32)
    let paddedName = bankName.padding(toLength: 14, withPad: " ", startingAt: 0)
    let nameData   = (paddedName + "\0\0").data(using: .ascii) ?? Data(count: 16)
    entry.replaceSubrange(0..<16, with: nameData.prefix(16))
    entry.writeU16LE(UInt16((slotIndex - 1) * 0x0200), at: 16)  // idx (0x0200 per bank, matches EMAX II preset addressing)
    entry.writeU16LE(UInt16(alloc[0]),                 at: 18)  // start cluster
    entry.writeU16LE(UInt16(alloc.count),              at: 20)  // cluster count
    entry.writeU16LE(0x0000,                           at: 22)  // f22
    entry.writeU16LE(0x0000,                           at: 24)  // f24
    entry.writeU16LE(0x0081,                           at: 26)  // flags

    handle.seek(toFileOffset: geo.bntOffset + UInt64(slotIndex * 32))
    handle.write(entry)
    handle.synchronizeFile()

    let kb = bankData.count / 1024
    print("  ✅ '\(bankName)' → \(alloc.count) clusters, \(kb) KB, BNT slot \(slotIndex), cluster \(alloc[0])")
}

// MARK: - Main

guard CommandLine.argc >= 3 else {
    print("Usage: swift emaxforge-import.swift <disk.hda> <bank1.EB2> [bank2.EB2 ...]")
    print("  disk.hda must be a valid EMAX II image (EMX2 magic)")
    print("  Tip: rename output to HD10.hda for ZuluSCSI SCSI ID 1")
    exit(1)
}

let diskPath  = CommandLine.arguments[1]
let bankPaths = Array(CommandLine.arguments.dropFirst(2))
let diskURL   = URL(fileURLWithPath: diskPath)

// Quick header check
guard let header = try? FileHandle(forReadingFrom: diskURL) else {
    print("❌ Cannot open \(diskPath)"); exit(1)
}
let magic = header.readData(ofLength: 4)
header.closeFile()
guard String(data: magic, encoding: .ascii) == "EMX2" else {
    print("❌ \(diskPath) is not a valid EMAX II image (no EMX2 magic)"); exit(1)
}

print("📀 EmaxForge Import — \(diskPath)")
print("   Banks to import: \(bankPaths.count)")
print("")

var ok = 0; var fail = 0
for path in bankPaths {
    let url = URL(fileURLWithPath: path)
    print("  → \(url.lastPathComponent)")
    do {
        try importBank(bankURL: url, into: diskURL)
        ok += 1
    } catch {
        print("  ❌ \(error.localizedDescription)")
        fail += 1
    }
}

print("")
print("Done: \(ok) imported, \(fail) failed")
if fail == 0 { print("✅ All banks imported — rename to HD10.hda for ZuluSCSI") }
