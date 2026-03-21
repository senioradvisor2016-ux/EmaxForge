#!/usr/bin/env swift
// EmaxForge CLI - Clone Disk (Bit-for-Bit Copy)
// 
// Usage:
//   swift cli-clone-disk.swift --source HD10.hda --output HD20.hda

import Foundation

// MARK: - Args

struct Args {
    var source: String = ""
    var output: String = ""
    var verify: Bool = false
    
    static func parse(_ args: [String]) -> Args? {
        var result = Args()
        var i = 1
        
        while i < args.count {
            let arg = args[i]
            
            switch arg {
            case "--source":
                guard i + 1 < args.count else { return nil }
                result.source = args[i + 1]
                i += 2
            
            case "--output":
                guard i + 1 < args.count else { return nil }
                result.output = args[i + 1]
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
        
        guard !result.source.isEmpty, !result.output.isEmpty else {
            print("❌ --source and --output required")
            return nil
        }
        
        return result
    }
    
    static func printUsage() {
        print("""
        EmaxForge CLI - Clone Disk
        
        Usage:
          swift cli-clone-disk.swift --source <path> --output <path> [--verify]
        
        Options:
          --source <path>   Source disk image
          --output <path>   Output disk image
          --verify          Verify clone after copy
          -h, --help        Show this help
        
        Examples:
          # Clone disk
          swift cli-clone-disk.swift --source HD10.hda --output HD20.hda
          
          # Clone with verification
          swift cli-clone-disk.swift --source HD10.hda --output HD20.hda --verify
        """)
    }
}

// MARK: - Clone

func cloneDisk(source: URL, output: URL, verify: Bool) throws {
    let fileManager = FileManager.default
    
    // Get source size
    let attr = try fileManager.attributesOfItem(atPath: source.path)
    guard let fileSize = attr[.size] as? Int64 else {
        throw NSError(domain: "EmaxForge", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot determine file size"])
    }
    
    print("📀 Cloning disk...")
    print("   Source: \(source.lastPathComponent)")
    print("   Output: \(output.lastPathComponent)")
    print("   Size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
    print("")
    
    // Read source
    print("📖 Reading source...")
    let data = try Data(contentsOf: source)
    print("   ✅ Read \(data.count) bytes")
    
    // Write output
    print("💾 Writing clone...")
    try data.write(to: output)
    print("   ✅ Wrote \(data.count) bytes")
    
    // Verify
    if verify {
        print("🔍 Verifying clone...")
        let cloneData = try Data(contentsOf: output)
        
        if data == cloneData {
            print("   ✅ Verification passed - clone is identical")
        } else {
            throw NSError(domain: "EmaxForge", code: 2, userInfo: [NSLocalizedDescriptionKey: "Verification failed - clone differs from source"])
        }
    }
    
    print("")
    print("✅ Clone complete!")
}

// MARK: - Main

guard let args = Args.parse(CommandLine.arguments) else {
    Args.printUsage()
    exit(1)
}

do {
    let sourceURL = URL(fileURLWithPath: args.source)
    let outputURL = URL(fileURLWithPath: args.output)
    
    guard FileManager.default.fileExists(atPath: sourceURL.path) else {
        print("❌ Source not found: \(sourceURL.path)")
        exit(1)
    }
    
    if FileManager.default.fileExists(atPath: outputURL.path) {
        print("⚠️  Output already exists: \(outputURL.path)")
        print("   Overwrite? (y/n): ", terminator: "")
        guard let response = readLine()?.lowercased(), response == "y" else {
            print("❌ Cancelled")
            exit(0)
        }
    }
    
    try cloneDisk(source: sourceURL, output: outputURL, verify: args.verify)
    
    // JSON output
    let result: [String: Any] = [
        "success": true,
        "source": sourceURL.path,
        "output": outputURL.path,
        "verified": args.verify
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
