#!/usr/bin/env swift

import Foundation

// Quick script to analyze EMAX II image
let imagePath = "/Users/senioradvisor/clawd/EmaxForge/EMAXII_IMAGE_Malmo.EZ2"
let imageURL = URL(fileURLWithPath: imagePath)

print("📀 Analyserar: \(imageURL.lastPathComponent)")
print("=" * 60)

// Read basic file info
let fm = FileManager.default
if let attrs = try? fm.attributesOfItem(atPath: imagePath),
   let size = attrs[.size] as? Int64 {
    print("📏 Storlek: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
}

// Read header
guard let handle = try? FileHandle(forReadingFrom: imageURL) else {
    print("❌ Kunde inte öppna fil")
    exit(1)
}
defer { try? handle.close() }

// Read header (512 bytes)
try? handle.seek(toOffset: 0)
guard let header = try? handle.read(upToCount: 512), header.count == 512 else {
    print("❌ Kunde inte läsa header")
    exit(1)
}

// Check magic
let magic = String(data: header[0..<4], encoding: .ascii) ?? ""
print("🔍 Magic: \(magic)")

if magic != "EMX2" {
    print("❌ Inte en giltig EMAX II image (förväntade 'EMX2')")
    exit(1)
}

// Read cluster size
func readU32LE(_ data: Data, at offset: Int) -> UInt32 {
    return UInt32(data[offset]) |
           (UInt32(data[offset + 1]) << 8) |
           (UInt32(data[offset + 2]) << 16) |
           (UInt32(data[offset + 3]) << 24)
}

func readU16LE(_ data: Data, at offset: Int) -> UInt16 {
    return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
}

let clusterSize = Int(readU32LE(header, at: 4))
let clusterAreaStartSector = readU32LE(header, at: 0x20)
let bankCount = readU32LE(header, at: 0x14)

print("💾 Cluster Size: \(ByteCountFormatter.string(fromByteCount: Int64(clusterSize), countStyle: .file))")
print("📍 Cluster Area Start Sector: \(clusterAreaStartSector)")
print("📊 Bank Count (header): \(bankCount)")

// Read FAT
try? handle.seek(toOffset: 0x400)
guard let fatData = try? handle.read(upToCount: 1024), fatData.count == 1024 else {
    print("❌ Kunde inte läsa FAT")
    exit(1)
}

var fat: [UInt16] = []
for i in stride(from: 0, to: 1024, by: 2) {
    fat.append(readU16LE(fatData, at: i))
}

let usedClusters = fat.filter { $0 != 0x7FFF && $0 != 0 && $0 != 0x8000 }.count
let freeClusters = fat.filter { $0 == 0 }.count
print("📈 Använda clusters: \(usedClusters)")
print("📉 Lediga clusters: \(freeClusters)")

// Read catalog
try? handle.seek(toOffset: 0x1000)
guard let catalogData = try? handle.read(upToCount: 500 * 32) else {
    print("❌ Kunde inte läsa catalog")
    exit(1)
}

print("\n📚 Banks på disken:")
print("-" * 60)

var banks: [(name: String, bankIndex: UInt16, presets: UInt16, size: Int, isOS: Bool)] = []

for i in 0..<500 {
    let offset = i * 32
    guard offset + 32 <= catalogData.count else { break }
    
    let entry = Data(catalogData[offset..<(offset + 32)])
    let nameBytes = Data(entry[0..<16])
    
    // End of catalog
    if nameBytes.allSatisfy({ $0 == 0 || $0 == 0xFF }) { break }
    
    let name = String(data: nameBytes, encoding: .ascii)?
        .trimmingCharacters(in: .controlCharacters)
        .trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? ""
    
    guard !name.isEmpty else { break }
    
    let bankIndex = readU16LE(entry, at: 16)
    let startCluster = readU16LE(entry, at: 18)
    let numPresets = readU16LE(entry, at: 20)
    
    // Calculate size by following cluster chain
    var clusterChain: [Int] = []
    var current = Int(startCluster)
    var visited = Set<Int>()
    
    while current != 0 && current < 512 && !visited.contains(current) {
        visited.insert(current)
        clusterChain.append(current)
        
        if current < fat.count {
            let next = Int(fat[current])
            if next == 0x7FFF || next == 0x8000 { break } // END marker or reserved
            current = next
        } else {
            break
        }
    }
    
    let sizeBytes = clusterChain.count * clusterSize
    let isOS = startCluster == 1 || name.contains("Software") || name.contains("OS")
    
    banks.append((name: name, bankIndex: bankIndex, presets: numPresets, size: sizeBytes, isOS: isOS))
}

// Sort: OS first, then by bank index
banks.sort { a, b in
    if a.isOS != b.isOS { return a.isOS }
    return a.bankIndex < b.bankIndex
}

for (index, bank) in banks.enumerated() {
    let icon = bank.isOS ? "💻" : "🎵"
    let type = bank.isOS ? " (OS)" : ""
    print("\(String(format: "%2d", index + 1)). \(icon) \(bank.name)\(type)")
    print("    Bank Index: \(bank.bankIndex)")
    print("    Presets: \(bank.presets)")
    print("    Storlek: \(ByteCountFormatter.string(fromByteCount: Int64(bank.size), countStyle: .file))")
    print()
}

print("=" * 60)
print("📊 Sammanfattning:")
print("   Totala banks: \(banks.count)")
print("   OS banks: \(banks.filter { $0.isOS }.count)")
print("   Sample banks: \(banks.filter { !$0.isOS }.count)")
print("   Total använt: \(ByteCountFormatter.string(fromByteCount: Int64(banks.reduce(0) { $0 + $1.size }), countStyle: .file))")
