#!/usr/bin/env swift
// EmaxForge CLI - Validate Disk Image
// 
// Usage:
//   swift cli-validate-disk.swift --disk HD10.hda

import Foundation

// MARK: - Args

struct Args {
    var disk: String = ""
    var fix: Bool = false
    
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
            
            case "--fix":
                result.fix = true
                i += 1
            
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
        EmaxForge CLI - Disk Validation
        
        Usage:
          swift cli-validate-disk.swift --disk <path> [--fix]
        
        Options:
          --disk <path>   Disk image to validate
          --fix           Auto-fix issues if possible
          -h, --help      Show this help
        
        Examples:
          # Validate disk
          swift cli-validate-disk.swift --disk HD10.hda
          
          # Validate and fix
          swift cli-validate-disk.swift --disk HD10.hda --fix
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

// MARK: - Validation

enum ValidationIssue {
    case bootSignatureMissing
    case bootSignatureWrong
    case invalidClusterSize
    case invalidFATSize
    case invalidCatalog
    case corruptBank(name: String)
    
    var description: String {
        switch self {
        case .bootSignatureMissing:
            return "Boot signature missing (0x78 0x82 at 0x1FE)"
        case .bootSignatureWrong:
            return "Boot signature wrong (expected 0x78 0x82)"
        case .invalidClusterSize:
            return "Invalid cluster size"
        case .invalidFATSize:
            return "Invalid FAT size"
        case .invalidCatalog:
            return "Corrupt catalog"
        case .corruptBank(let name):
            return "Corrupt bank: \(name)"
        }
    }
    
    var severity: String {
        switch self {
        case .bootSignatureMissing, .bootSignatureWrong:
            return "CRITICAL"
        case .invalidClusterSize, .invalidFATSize, .invalidCatalog:
            return "ERROR"
        case .corruptBank:
            return "WARNING"
        }
    }
}

func validateDisk(_ url: URL) throws -> [ValidationIssue] {
    let fileHandle = try FileHandle(forReadingFrom: url)
    defer { try? fileHandle.close() }

    var issues: [ValidationIssue] = []

    // Read header sector (EMAX II format — 512 bytes at offset 0)
    fileHandle.seek(toFileOffset: 0)
    let header = fileHandle.readData(ofLength: 512)
    guard header.count == 512 else { return [.invalidCatalog] }

    // 1. Magic: "EMX2" at [0..3]
    let magic = String(data: header[0..<4], encoding: .ascii) ?? ""
    if magic != "EMX2" {
        issues.append(.bootSignatureWrong)
    }

    // 2. Cluster size — U32 LE at offset 4
    //    EMAX II clusters are NOT required to be power-of-2 (e.g. 44032 = 86 × 512)
    let clusterSize = Int(header.readU32LE(at: 4))
    if clusterSize < 512 || clusterSize > 8_000_000 {
        issues.append(.invalidClusterSize)
    }

    // 3. FAT sectors — U32 LE at offset 0x1C
    let fatSectors = Int(header.readU32LE(at: 0x1C))
    if fatSectors < 1 || fatSectors > 4096 {
        issues.append(.invalidFATSize)
    }

    // 4. BNT (catalog) — starts at bntStartSector (U32 LE at 0x10)
    let bntStartSector  = Int(header.readU32LE(at: 0x10))
    let maxBanks        = Int(header.readU32LE(at: 0x14))
    let clusterAreaStart = Int(header.readU32LE(at: 0x20))
    let bntOffset       = UInt64(bntStartSector) * 512
    let bntSize         = (clusterAreaStart - bntStartSector) * 512

    if bntStartSector < 1 || maxBanks < 1 || bntSize <= 0 {
        issues.append(.invalidCatalog)
        return issues
    }

    fileHandle.seek(toFileOffset: bntOffset)
    let catalogData = fileHandle.readData(ofLength: min(bntSize, maxBanks * 32 + 32))

    // BNT entry layout (32 bytes):
    //   +00..+0F  name (16 bytes)
    //   +10..+11  startCluster (U16 LE)
    //   +12..+13  clusterCount (U16 LE)
    //   +14..+15  numPresets (U16 LE)
    //   +16..+17  fieldA
    //   +18..+19  bankIndex
    //   +1A..+1B  flags (0x0081 = valid bank)
    //   +1C..+1F  zeros
    var validEntries = 0
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

        let startCluster = catalogData.readU16LE(at: base + 16)
        let flags        = catalogData.readU16LE(at: base + 26)

        if startCluster != 0x7800 && flags != 0x0081 {
            issues.append(.corruptBank(name: name))
        }
        validEntries += 1
    }

    if validEntries == 0 {
        issues.append(.invalidCatalog)
    }

    return issues
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
    
    print("🔍 Validating disk: \(diskURL.lastPathComponent)")
    print("")
    
    let issues = try validateDisk(diskURL)
    
    if issues.isEmpty {
        print("✅ VALID - No issues found")
        print("")
        
        // JSON output
        let result: [String: Any] = [
            "success": true,
            "valid": true,
            "issues": []
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("JSON_OUTPUT_START")
            print(jsonString)
            print("JSON_OUTPUT_END")
        }
    } else {
        print("⚠️  ISSUES FOUND (\(issues.count)):")
        print("")
        
        for (idx, issue) in issues.enumerated() {
            print("[\(issue.severity)] \(issue.description)")
        }
        
        if args.fix {
            print("")
            print("🔧 Auto-fix not yet implemented")
            print("   (Would fix: boot signature, catalog flags)")
        }
        
        // JSON output
        let issueList = issues.map { ["severity": $0.severity, "description": $0.description] }
        let result: [String: Any] = [
            "success": true,
            "valid": false,
            "issues": issueList,
            "count": issues.count
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("\nJSON_OUTPUT_START")
            print(jsonString)
            print("JSON_OUTPUT_END")
        }
        
        exit(1)
    }
    
} catch {
    print("❌ Error: \(error)")
    exit(1)
}
