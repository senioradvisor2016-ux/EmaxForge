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
    
    // Read boot sector
    fileHandle.seek(toFileOffset: 0)
    let bootSector = fileHandle.readData(ofLength: 512)
    
    let clusterSize = Int(bootSector.readU32LE(at: 4))
    let sectorsPerFAT = Int(bootSector.readU16LE(at: 22))
    let rootEntries = Int(bootSector.readU16LE(at: 17))
    
    // Read catalog
    let catalogOffset = UInt64(sectorsPerFAT + 1) * 512
    fileHandle.seek(toFileOffset: catalogOffset)
    let catalogData = fileHandle.readData(ofLength: rootEntries * 32)
    
    var banks: [BankEntry] = []
    var bankIndex = 1
    
    for i in 0..<rootEntries {
        let entryOffset = i * 32
        let nameData = catalogData.subdata(in: entryOffset..<(entryOffset + 16))
        let name = String(data: nameData, encoding: .ascii)?
            .trimmingCharacters(in: .whitespaces.union(.controlCharacters)) ?? ""
        
        guard !name.isEmpty else { continue }
        
        let cluster = Int(catalogData.readU16LE(at: entryOffset + 24))
        let flags = catalogData.readU16LE(at: entryOffset + 26)
        
        // Skip OS entry
        if cluster == 1 && flags == 0x0081 {
            continue
        }
        
        // Valid bank
        if cluster > 0 && flags == 0x0081 {
            banks.append(BankEntry(
                name: name,
                cluster: cluster,
                index: bankIndex,
                size: clusterSize
            ))
            bankIndex += 1
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
