#!/usr/bin/env swift

import Foundation

// Inline BankExtractor (can't import modules in swift scripts)

struct BankExtractor {
    struct ExtractedBank {
        let name: String
        let data: Data
        let clusterCount: Int
    }

    enum ExtractionError: Error {
        case invalidDisk(String)
        case bankNotFound(String)
        case readError(String)
    }

    static func extractAllBanks(from imageURL: URL) throws -> [ExtractedBank] {
        guard let handle = try? FileHandle(forReadingFrom: imageURL) else {
            throw ExtractionError.invalidDisk("Cannot open disk image")
        }
        defer { try? handle.close() }

        // --- Parse header ---
        handle.seek(toFileOffset: 0)
        let headerData = handle.readData(ofLength: 512)
        guard headerData.count == 512 else {
            throw ExtractionError.invalidDisk("Cannot read header")
        }

        let magic = String(data: headerData[0..<4], encoding: .ascii) ?? ""
        guard magic == "EMX2" else {
            throw ExtractionError.invalidDisk("Not an EMAX II image (missing EMX2)")
        }

        let clusterSize    = Int(headerData.readU32LE(at: 0x04))
        let bntStartSector = Int(headerData.readU32LE(at: 0x10))
        let maxBanks       = Int(headerData.readU32LE(at: 0x14))
        let fatSectors     = Int(headerData.readU32LE(at: 0x1C))
        let caStartSector  = Int(headerData.readU32LE(at: 0x20))

        let fatOffset  = UInt64(0x400)  // ALWAYS at 0x400
        let fatSize    = fatSectors * 512
        let bntOffset  = UInt64(bntStartSector) * 512
        let bntSize    = (caStartSector - bntStartSector) * 512
        let caOffset   = UInt64(caStartSector) * 512

        // --- Read FAT ---
        handle.seek(toFileOffset: fatOffset)
        let fatData = handle.readData(ofLength: fatSize)

        // --- Read BNT ---
        handle.seek(toFileOffset: bntOffset)
        let bntData = handle.readData(ofLength: bntSize)

        // --- Extract banks ---
        var banks = [ExtractedBank]()
        let maxSlots = min(maxBanks + 1, bntSize / 32)

        for i in 1..<maxSlots {  // Skip slot 0 (OS)
            let off = i * 32
            guard off + 32 <= bntData.count else { break }
            let entry = bntData[off..<(off + 32)]

            // Skip empty/deleted
            if entry.allSatisfy({ $0 == 0x00 }) { continue }
            if entry.allSatisfy({ $0 == 0xFF }) { continue }

            let flags = entry.readU16LE(at: 26)
            guard flags == 0x0081 else { continue }

            let name = String(data: bntData[off..<(off + 14)], encoding: .ascii)?
                .trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? ""
            let startCluster = Int(entry.readU16LE(at: 18))
            
            guard !name.isEmpty, startCluster > 1 else { continue }

            // Follow FAT chain
            var clusters = [Int]()
            var current = startCluster
            let fatEntryCount = fatSize / 2

            while current > 0 && current < fatEntryCount && clusters.count < 10000 {
                clusters.append(current)
                let next = Int(fatData.readU16LE(at: current * 2))
                if next == 0x7FFF || next == 0x8000 || next == 0x0000 || next == current { break }
                current = next
            }

            // Read bank data (1-based clusters)
            var bankData = Data()
            for cluster in clusters {
                let offset = caOffset + UInt64(cluster - 1) * UInt64(clusterSize)
                handle.seek(toFileOffset: offset)
                let data = handle.readData(ofLength: clusterSize)
                bankData.append(data)
            }

            banks.append(ExtractedBank(name: name, data: bankData, clusterCount: clusters.count))
        }

        return banks
    }
}

// Data helpers
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

// --- CLI Main ---

guard CommandLine.arguments.count == 3 else {
    print("Usage: export_banks_cli.swift <image.EZ2> <output_dir>")
    exit(1)
}

let imageURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputDir = URL(fileURLWithPath: CommandLine.arguments[2])

// Create output dir
try! FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

print("📦 Exporting all banks from \(imageURL.lastPathComponent)...")
let banks = try! BankExtractor.extractAllBanks(from: imageURL)
print("Found \(banks.count) banks\n")

for bank in banks {
    // Sanitize filename (replace / with _)
    let sanitizedName = bank.name.replacingOccurrences(of: "/", with: "_")
    let outputURL = outputDir.appendingPathComponent(sanitizedName + ".EB2")
    try! bank.data.write(to: outputURL)
    print("  ✅ \(bank.name.padding(toLength: 20, withPad: " ", startingAt: 0)) → \(String(format: "%7d", bank.data.count)) bytes (\(bank.clusterCount) clusters)")
}

print("\n✅ Exported \(banks.count) banks to \(outputDir.path)")
