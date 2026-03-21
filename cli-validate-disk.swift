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
    
    // Read boot sector
    fileHandle.seek(toFileOffset: 0)
    let bootSector = fileHandle.readData(ofLength: 512)
    
    // 1. Boot signature
    let sig1 = bootSector[0x1FE]
    let sig2 = bootSector[0x1FF]
    
    if sig1 == 0 && sig2 == 0 {
        issues.append(.bootSignatureMissing)
    } else if sig1 != 0x78 || sig2 != 0x82 {
        issues.append(.bootSignatureWrong)
    }
    
    // 2. Cluster size (should be power of 2, reasonable range)
    let clusterSize = Int(bootSector.readU32LE(at: 4))
    if clusterSize < 512 || clusterSize > 2_000_000 || (clusterSize & (clusterSize - 1)) != 0 {
        issues.append(.invalidClusterSize)
    }
    
    // 3. FAT size
    let sectorsPerFAT = Int(bootSector.readU16LE(at: 22))
    if sectorsPerFAT < 1 || sectorsPerFAT > 1000 {
        issues.append(.invalidFATSize)
    }
    
    // 4. Catalog check
    let rootEntries = Int(bootSector.readU16LE(at: 17))
    let catalogOffset = UInt64(sectorsPerFAT + 1) * 512
    fileHandle.seek(toFileOffset: catalogOffset)
    let catalogData = fileHandle.readData(ofLength: rootEntries * 32)
    
    var validEntries = 0
    for i in 0..<rootEntries {
        let entryOffset = i * 32
        let nameData = catalogData.subdata(in: entryOffset..<(entryOffset + 16))
        let name = String(data: nameData, encoding: .ascii)?
            .trimmingCharacters(in: .whitespaces.union(.controlCharacters)) ?? ""
        
        if !name.isEmpty {
            let cluster = catalogData.readU16LE(at: entryOffset + 24)
            let flags = catalogData.readU16LE(at: entryOffset + 26)
            
            // Check flags
            if flags != 0x0081 && cluster > 0 {
                issues.append(.corruptBank(name: name))
            }
            
            validEntries += 1
        }
    }
    
    if validEntries == 0 && rootEntries > 0 {
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
