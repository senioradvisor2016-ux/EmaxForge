#!/usr/bin/env swift
// EmaxForge CLI - List Banks
// 
// Usage:
//   swift cli-list-banks.swift --disk HD10.hda

import Foundation

// MARK: - Args

struct Args {
    var disk: String = ""
    
    static func parse(_ args: [String]) -> Args? {
        var result = Args()
        var i = 1
        
        while i < args.count {
            let arg = args[i]
            
            switch arg {
            case "--disk":
                guard i + 1 < args.count else { return nil }
                result.disk = args[i + 1]
                i += 2
            
            case "--help", "-h":
                return nil
            
            default:
                print("❌ Unknown option: \(arg)")
                return nil
            }
        }
        
        guard !result.disk.isEmpty else {
            print("❌ --disk required")
            return nil
        }
        
        return result
    }
    
    static func printUsage() {
        print("""
        EmaxForge CLI - List Banks
        
        Usage:
          swift cli-list-banks.swift --disk <path>
        
        Options:
          --disk <path>   Disk image (.hda)
          -h, --help      Show this help
        
        Example:
          swift cli-list-banks.swift --disk HD10.hda
        """)
    }
}

// MARK: - Helpers

extension Data {
    func readU16LE(at offset: Int) -> UInt16 {
        let low = UInt16(self[offset])
        let high = UInt16(self[offset + 1])
        return low | (high << 8)
    }
    
    func readU32LE(at offset: Int) -> UInt32 {
        let b0 = UInt32(self[offset])
        let b1 = UInt32(self[offset + 1])
        let b2 = UInt32(self[offset + 2])
        let b3 = UInt32(self[offset + 3])
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }
}

// MARK: - Bank Entry

struct BankEntry: Codable {
    let name: String
    let cluster: Int
    let index: Int
    let size: Int
}

// MARK: - List Banks

func listBanks(diskURL: URL) throws -> [BankEntry] {
    let fileHandle = try FileHandle(forReadingFrom: diskURL)
    defer { try? fileHandle.close() }

    // Read EMAX II header (512 bytes at offset 0)
    fileHandle.seek(toFileOffset: 0)
    let header = fileHandle.readData(ofLength: 512)
    guard header.count == 512 else { return [] }

    // Verify magic
    let magic = String(data: header[0..<4], encoding: .ascii) ?? ""
    guard magic == "EMX2" else {
        print("❌ Not an EMAX II disk image (magic: '\(magic)')")
        return []
    }

    // Header offsets (verified against EmaxIIFileSystem.swift)
    let clusterSize         = Int(header.readU32LE(at: 4))
    let bntStartSector      = Int(header.readU32LE(at: 0x10))
    let maxBanks            = Int(header.readU32LE(at: 0x14))
    let clusterAreaStartSec = Int(header.readU32LE(at: 0x20))

    // Read BNT (Bank Name Table / catalog)
    let bntOffset = UInt64(bntStartSector) * 512
    let bntSize   = (clusterAreaStartSec - bntStartSector) * 512
    fileHandle.seek(toFileOffset: bntOffset)
    let catalogData = fileHandle.readData(ofLength: min(bntSize, (maxBanks + 1) * 32))

    var banks: [BankEntry] = []
    let maxSlots = min(maxBanks + 1, catalogData.count / 32)

    // BNT entry layout (32 bytes each):
    //   +00..+0F  name (16 bytes ASCII)
    //   +10..+11  startCluster  (U16 LE)
    //   +12..+13  clusterCount  (U16 LE)
    //   +14..+15  numPresets    (U16 LE)
    //   +16..+17  fieldA
    //   +18..+19  bankIndex
    //   +1A..+1B  flags = 0x0081
    //   +1C..+1F  zeros
    for i in 0..<maxSlots {
        let base = i * 32
        guard base + 32 <= catalogData.count else { break }

        let nameData = catalogData.subdata(in: base..<(base + 16))
        guard !nameData.allSatisfy({ $0 == 0 || $0 == 0xFF }) else { continue }

        let name = String(data: nameData, encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? ""
        guard !name.isEmpty else { continue }

        let startCluster = Int(catalogData.readU16LE(at: base + 16))
        let flags        = catalogData.readU16LE(at: base + 26)

        // 0x7800 = OS/boot entry marker — skip it
        if startCluster == 0x7800 { continue }

        // Valid bank entry
        if flags == 0x0081 {
            banks.append(BankEntry(
                name: name,
                cluster: startCluster,
                index: banks.count + 1,
                size: clusterSize
            ))
        }
    }

    return banks
}

// MARK: - Main

guard let args = Args.parse(CommandLine.arguments) else {
    Args.printUsage()
    exit(1)
}

do {
    let diskURL = URL(fileURLWithPath: args.disk)
    
    guard FileManager.default.fileExists(atPath: diskURL.path) else {
        print("❌ Disk not found: \(diskURL.path)")
        exit(1)
    }
    
    let banks = try listBanks(diskURL: diskURL)
    
    print("📀 Banks on \(diskURL.lastPathComponent):")
    print("")
    
    if banks.isEmpty {
        print("   (no banks)")
    } else {
        for bank in banks {
            let sizeKB = bank.size / 1024
            print("   [\(bank.index)] \(bank.name)")
            print("       Cluster: \(bank.cluster), Size: \(sizeKB) KB")
        }
    }
    
    print("")
    print("Total: \(banks.count) banks")
    
    // JSON output
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    
    if let jsonData = try? encoder.encode(banks),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        print("\nJSON_OUTPUT_START")
        print(jsonString)
        print("JSON_OUTPUT_END")
    }
    
} catch {
    print("❌ Error: \(error)")
    exit(1)
}
