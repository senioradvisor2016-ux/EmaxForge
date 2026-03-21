#!/usr/bin/env swift
// EmaxForge CLI - Update OS on Multiple Disks
// 
// Usage:
//   swift cli-update-os.swift --disks HD10.hda,HD20.hda,HD30.hda --os "Emax II WORKING.EMX"

import Foundation

// MARK: - Args

struct Args {
    var disks: [String] = []
    var osPath: String = ""
    var verify: Bool = false
    
    static func parse(_ args: [String]) -> Args? {
        var result = Args()
        var i = 1
        
        while i < args.count {
            let arg = args[i]
            
            switch arg {
            case "--disks":
                guard i + 1 < args.count else { return nil }
                result.disks = args[i + 1].split(separator: ",").map(String.init)
                i += 2
            
            case "--os":
                guard i + 1 < args.count else { return nil }
                result.osPath = args[i + 1]
                i += 2
            
            case "--verify":
                result.verify = true
                i += 1
            
            case "--help", "-h":
                return nil
            
            default:
                print("❌ Unknown option: \(arg)")
                return nil
            }
        }
        
        guard !result.disks.isEmpty, !result.osPath.isEmpty else {
            print("❌ --disks and --os required")
            return nil
        }
        
        return result
    }
    
    static func printUsage() {
        print("""
        EmaxForge CLI - Mass OS Update
        
        Usage:
          swift cli-update-os.swift --disks <disk1,disk2,...> --os <path> [--verify]
        
        Options:
          --disks <list>    Comma-separated disk paths
          --os <path>       OS file (.EMX)
          --verify          Verify OS after write
          -h, --help        Show this help
        
        Examples:
          # Update OS on multiple disks
          swift cli-update-os.swift --disks HD10.hda,HD20.hda --os "Emax II rev 2.14.EMX"
          
          # With verification
          swift cli-update-os.swift --disks *.hda --os os.EMX --verify
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

// MARK: - Update OS

func updateOS(disk: URL, osData: Data, verify: Bool) throws {
    let fileHandle = try FileHandle(forWritingTo: disk)
    defer { try? fileHandle.close() }
    
    // Read boot sector
    fileHandle.seek(toFileOffset: 0)
    let bootSector = fileHandle.readData(ofLength: 512)
    
    let clusterSize = Int(bootSector.readU32LE(at: 4))
    let clusterAreaStartSector = bootSector.readU32LE(at: 0x20)
    let clusterAreaStart = UInt64(clusterAreaStartSector) * 512
    
    // OS goes to cluster 1
    let osOffset = clusterAreaStart + UInt64(clusterSize)
    
    // Verify size
    guard osData.count <= clusterSize else {
        throw NSError(domain: "EmaxForge", code: 1, userInfo: [NSLocalizedDescriptionKey: "OS too large (\(osData.count) > \(clusterSize))"])
    }
    
    // Write OS
    fileHandle.seek(toFileOffset: osOffset)
    fileHandle.write(osData)
    
    // Pad to cluster size
    if osData.count < clusterSize {
        let padding = Data(count: clusterSize - osData.count)
        fileHandle.write(padding)
    }
    
    // Verify
    if verify {
        fileHandle.seek(toFileOffset: osOffset)
        let written = fileHandle.readData(ofLength: osData.count)
        
        guard written == osData else {
            throw NSError(domain: "EmaxForge", code: 2, userInfo: [NSLocalizedDescriptionKey: "Verification failed"])
        }
    }
}

// MARK: - Main

guard let args = Args.parse(CommandLine.arguments) else {
    Args.printUsage()
    exit(1)
}

do {
    let osURL = URL(fileURLWithPath: args.osPath)
    
    guard FileManager.default.fileExists(atPath: osURL.path) else {
        print("❌ OS file not found: \(osURL.path)")
        exit(1)
    }
    
    let osData = try Data(contentsOf: osURL)
    print("📀 Mass OS Update")
    print("   OS: \(osURL.lastPathComponent) (\(osData.count) bytes)")
    print("   Disks: \(args.disks.count)")
    print("")
    
    var updated: [String] = []
    var failed: [(String, Error)] = []
    
    for (idx, diskPath) in args.disks.enumerated() {
        let diskURL = URL(fileURLWithPath: diskPath)
        print("[\(idx + 1)/\(args.disks.count)] \(diskURL.lastPathComponent)...", terminator: " ")
        
        guard FileManager.default.fileExists(atPath: diskURL.path) else {
            print("❌ Not found")
            failed.append((diskPath, NSError(domain: "EmaxForge", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found"])))
            continue
        }
        
        do {
            try updateOS(disk: diskURL, osData: osData, verify: args.verify)
            print("✅")
            updated.append(diskPath)
        } catch {
            print("❌ \(error.localizedDescription)")
            failed.append((diskPath, error))
        }
    }
    
    print("")
    print("✅ Updated: \(updated.count)")
    if !failed.isEmpty {
        print("❌ Failed: \(failed.count)")
        for (disk, error) in failed {
            print("   \(disk): \(error.localizedDescription)")
        }
    }
    
    // JSON output
    let result: [String: Any] = [
        "success": failed.isEmpty,
        "updated": updated,
        "failed": failed.map { ["disk": $0.0, "error": $0.1.localizedDescription] },
        "total": args.disks.count
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
