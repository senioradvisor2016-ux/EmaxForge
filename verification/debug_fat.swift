#!/usr/bin/env swift
import Foundation

extension Data {
    func readU16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self) }
    }
    func readU32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
    }
}

let imageURL = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : NSHomeDirectory() + "/clawd/emxp/Images/EmaxII-02.EZ2")

let handle = try! FileHandle(forReadingFrom: imageURL)
defer { try? handle.close() }

// Header
handle.seek(toFileOffset: 0)
let hdr = handle.readData(ofLength: 512)

let clusterSize    = Int(hdr.readU32LE(at: 0x04))
let bntStartSector = Int(hdr.readU32LE(at: 0x10))
let maxBanks       = Int(hdr.readU32LE(at: 0x14))
let fatSectors     = Int(hdr.readU32LE(at: 0x1C))
let caStartSector  = Int(hdr.readU32LE(at: 0x20))

let caOffset  = UInt64(caStartSector) * 512
let fatSize   = fatSectors * 512
let bntOffset = UInt64(bntStartSector) * 512
let bntSize   = (caStartSector - bntStartSector) * 512

print("Header:")
print("  clusterSize:    \(clusterSize)")
print("  bntStartSector: \(bntStartSector) → 0x\(String(bntStartSector * 512, radix: 16))")
print("  maxBanks:       \(maxBanks)")
print("  fatSectors:     \(fatSectors) → fatSize=\(fatSize) bytes")
print("  caStartSector:  \(caStartSector) → 0x\(String(caStartSector * 512, radix: 16))")
print("  fatEntries:     \(fatSize / 2)")
print("")

// FAT
handle.seek(toFileOffset: 0x400)
let fatData = handle.readData(ofLength: fatSize)

// BNT
handle.seek(toFileOffset: bntOffset)
let bntData = handle.readData(ofLength: bntSize)

print("FAT entry 0: 0x\(String(format: "%04X", fatData.readU16LE(at: 0)))")
print("FAT entry 1: 0x\(String(format: "%04X", fatData.readU16LE(at: 2)))")
print("FAT entry 2: 0x\(String(format: "%04X", fatData.readU16LE(at: 4)))")
print("FAT entry 3: 0x\(String(format: "%04X", fatData.readU16LE(at: 6)))")
print("")

// Dump alla BNT entries + deras FAT chains
let maxSlots = min(maxBanks + 1, bntSize / 32)
print(String(format: "%-20s %5s %5s   FAT chain", "Name", "Start", "Cnt"))
print(String(repeating: "-", count: 70))

for i in 0..<maxSlots {
    let off = i * 32
    guard off + 32 <= bntData.count else { break }
    let entry = bntData[off..<(off+32)]
    if entry.allSatisfy({ $0 == 0 }) || entry.allSatisfy({ $0 == 0xFF }) { continue }
    
    let flags = entry.readU16LE(at: 26)
    let name = String(data: bntData[off..<(off+14)], encoding: .ascii)?
        .trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? ""
    let start = Int(entry.readU16LE(at: 18))
    let cnt   = Int(entry.readU16LE(at: 20))
    
    // Trace FAT chain
    var clusters = [Int]()
    var cur = start
    let fatEntryCount = fatSize / 2
    while cur > 0 && cur < fatEntryCount && clusters.count < 200 {
        clusters.append(cur)
        let next = Int(fatData.readU16LE(at: cur * 2))
        let nextHex = String(format: "0x%04X", next)
        if next == 0x7FFF { break }  // end-of-chain
        if next == 0x8000 { break }
        if next == 0x0000 { 
            clusters = []  // chain broken — mark as empty
            print(String(format: "  %-20s start=%-5d bnt_cnt=%-5d → FAT[%d]=0x0000 BROKEN CHAIN!", name, start, cnt, cur))
            break
        }
        if next == cur { break }
        cur = next
    }
    
    if !clusters.isEmpty {
        let chainStr = clusters.prefix(5).map { String($0) }.joined(separator: "→") + (clusters.count > 5 ? "→..." : "")
        print(String(format: "  %-20s start=%-5d bnt=%-5d fat=%-5d  %s", name, start, cnt, clusters.count, chainStr))
    }
}
