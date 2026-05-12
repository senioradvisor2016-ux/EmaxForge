#!/usr/bin/env swift
// EmaxForge CLI - Export Bank
// 
// Usage:
//   swift cli-export-bank.swift --disk HD10.hda --index 1 --output Piano.EB2

import Foundation

// MARK: - Args

struct Args {
    var disk: String = ""
    var index: Int = 0
    var name: String? = nil
    var output: String = ""
    
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
            
            case "--index":
                guard i + 1 < args.count, let idx = Int(args[i + 1]) else { return nil }
                result.index = idx
                i += 2
            
            case "--name":
                guard i + 1 < args.count else { return nil }
                result.name = args[i + 1]
                i += 2
            
            case "--output":
                guard i + 1 < args.count else { return nil }
                result.output = args[i + 1]
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
        
        guard !result.output.isEmpty else {
            print("❌ --output required")
            return nil
        }
        
        guard result.index > 0 || result.name != nil else {
            print("❌ Either --index or --name required")
            return nil
        }
        
        return result
    }
    
    static func printUsage() {
        print("""
        EmaxForge CLI - Export Bank
        
        Usage:
          swift cli-export-bank.swift --disk <path> --index <n> --output <path>
          swift cli-export-bank.swift --disk <path> --name <name> --output <path>
        
        Options:
          --disk <path>      Source disk image (.hda)
          --index <n>        Bank index (1-based)
          --name <name>      Bank name (alternative to --index)
          --output <path>    Output .EB2 file
          -h, --help         Show this help
        
        Examples:
          # Export by index
          swift cli-export-bank.swift --disk HD10.hda --index 1 --output Piano.EB2
          
          # Export by name
          swift cli-export-bank.swift --disk HD10.hda --name "PIANO" --output Piano.EB2
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

// MARK: - Image Parser

struct BankEntry {
    let name: String
    let cluster: UInt16
    let index: Int
}

func parseBanks(diskURL: URL) throws -> (banks: [BankEntry], clusterSize: Int, clusterAreaStart: UInt64) {
    let fileHandle = try FileHandle(forReadingFrom: diskURL)
    defer { try? fileHandle.close() }

    // Read EMAX II header (512 bytes at offset 0)
    fileHandle.seek(toFileOffset: 0)
    let header = fileHandle.readData(ofLength: 512)
    guard header.count == 512,
          String(data: header[0..<4], encoding: .ascii) == "EMX2" else {
        throw NSError(domain: "EmaxForge", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Not an EMAX II disk image"])
    }

    // Header offsets (verified against EmaxIIFileSystem.swift)
    let clusterSize         = Int(header.readU32LE(at: 4))
    let bntStartSector      = Int(header.readU32LE(at: 0x10))
    let maxBanks            = Int(header.readU32LE(at: 0x14))
    let clusterAreaStartSec = Int(header.readU32LE(at: 0x20))
    let clusterAreaStart    = UInt64(clusterAreaStartSec) * 512

    // Read BNT (Bank Name Table / catalog)
    let bntOffset = UInt64(bntStartSector) * 512
    let bntSize   = (clusterAreaStartSec - bntStartSector) * 512
    fileHandle.seek(toFileOffset: bntOffset)
    let catalogData = fileHandle.readData(ofLength: min(bntSize, (maxBanks + 1) * 32))

    var banks: [BankEntry] = []
    let maxSlots = min(maxBanks + 1, catalogData.count / 32)

    for i in 0..<maxSlots {
        let base = i * 32
        guard base + 32 <= catalogData.count else { break }
        let nameData = catalogData.subdata(in: base..<(base + 16))
        guard !nameData.allSatisfy({ $0 == 0 || $0 == 0xFF }) else { continue }

        let name = String(data: nameData, encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? ""
        guard !name.isEmpty else { continue }

        let startCluster = catalogData.readU16LE(at: base + 16)  // +10
        let flags        = catalogData.readU16LE(at: base + 26)  // +1A

        // 0x7800 = OS/boot entry — skip
        if startCluster == 0x7800 { continue }
        guard flags == 0x0081 else { continue }

        banks.append(BankEntry(name: name, cluster: startCluster, index: banks.count + 1))
    }

    return (banks, clusterSize, clusterAreaStart)
}

// MARK: - Export

func exportBank(diskURL: URL, bankEntry: BankEntry, outputURL: URL, clusterSize: Int, clusterAreaStart: UInt64) throws {
    let fileHandle = try FileHandle(forReadingFrom: diskURL)
    defer { try? fileHandle.close() }
    
    // Read bank data (0-based cluster addressing, matching EmaxIIFileSystem.swift)
    let bankOffset = clusterAreaStart + UInt64(bankEntry.cluster) * UInt64(clusterSize)
    fileHandle.seek(toFileOffset: bankOffset)
    let bankData = fileHandle.readData(ofLength: clusterSize)
    
    // Write .EB2 file (raw bank data)
    try bankData.write(to: outputURL)
    
    print("✅ Exported: \(bankEntry.name)")
    print("   From: \(diskURL.lastPathComponent)")
    print("   To: \(outputURL.path)")
    print("   Size: \(bankData.count) bytes")
}

// MARK: - Main

guard let args = Args.parse(CommandLine.arguments) else {
    Args.printUsage()
    exit(1)
}

do {
    let diskURL = URL(fileURLWithPath: args.disk)
    let outputURL = URL(fileURLWithPath: args.output)
    
    guard FileManager.default.fileExists(atPath: diskURL.path) else {
        print("❌ Disk not found: \(diskURL.path)")
        exit(1)
    }
    
    print("📀 Parsing disk: \(diskURL.lastPathComponent)")
    let (banks, clusterSize, clusterAreaStart) = try parseBanks(diskURL: diskURL)
    
    print("   Found \(banks.count) banks")
    
    // Find target bank
    var targetBank: BankEntry?
    
    if let name = args.name {
        targetBank = banks.first { $0.name.lowercased().contains(name.lowercased()) }
        if targetBank == nil {
            print("❌ Bank not found: \(name)")
            print("Available banks:")
            for bank in banks {
                print("  [\(bank.index)] \(bank.name)")
            }
            exit(1)
        }
    } else {
        guard args.index > 0 && args.index <= banks.count else {
            print("❌ Invalid index: \(args.index) (valid: 1-\(banks.count))")
            exit(1)
        }
        targetBank = banks[args.index - 1]
    }
    
    guard let bank = targetBank else {
        print("❌ Bank not found")
        exit(1)
    }
    
    // Export
    try exportBank(
        diskURL: diskURL,
        bankEntry: bank,
        outputURL: outputURL,
        clusterSize: clusterSize,
        clusterAreaStart: clusterAreaStart
    )
    
    // JSON output
    let result: [String: Any] = [
        "success": true,
        "bank_name": bank.name,
        "bank_index": bank.index,
        "output": outputURL.path,
        "size": clusterSize
    ]
    
    if let jsonData = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        print("\nJSON_OUTPUT_START")
        print(jsonString)
        print("JSON_OUTPUT_END")
    }
    
} catch {
    print("❌ Error: \(error)")
    exit(1)
}
