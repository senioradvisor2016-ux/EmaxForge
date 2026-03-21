#!/usr/bin/env swift
// EmaxForge CLI - Inspect Bank Format
// 
// Usage:
//   swift cli-inspect-bank.swift --bank SOMEBODY.EB2

import Foundation

// MARK: - Args

struct Args {
    var bank: String = ""
    var verbose: Bool = false
    
    static func parse(_ args: [String]) -> Args? {
        var result = Args()
        var i = 1
        
        while i < args.count {
            let arg = args[i]
            
            switch arg {
            case "--bank":
                guard i + 1 < args.count else { return nil }
                result.bank = args[i + 1]
                i += 2
            
            case "--verbose", "-v":
                result.verbose = true
                i += 1
            
            case "--help", "-h":
                return nil
            
            default:
                print("❌ Unknown option: \(arg)")
                return nil
            }
        }
        
        guard !result.bank.isEmpty else {
            print("❌ --bank required")
            return nil
        }
        
        return result
    }
    
    static func printUsage() {
        print("""
        EmaxForge CLI - Bank Format Inspector
        
        Usage:
          swift cli-inspect-bank.swift --bank <path> [--verbose]
        
        Options:
          --bank <path>   Bank file (.EB2)
          --verbose, -v   Show detailed hex dump
          -h, --help      Show this help
        
        Examples:
          # Inspect bank format
          swift cli-inspect-bank.swift --bank SOMEBODY.EB2
          
          # With hex dump
          swift cli-inspect-bank.swift --bank SOMEBODY.EB2 --verbose
        """)
    }
}

// MARK: - Helpers

extension Data {
    func readU8(at offset: Int) -> UInt8 {
        self[offset]
    }
    
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
    
    func hexDump(offset: Int, length: Int) -> String {
        var result = ""
        let end = Swift.min(offset + length, count)
        
        for i in stride(from: offset, to: end, by: 16) {
            result += String(format: "%08X: ", i)
            
            // Hex bytes
            for j in 0..<16 {
                if i + j < end {
                    result += String(format: "%02X ", self[i + j])
                } else {
                    result += "   "
                }
            }
            
            result += " "
            
            // ASCII
            for j in 0..<16 {
                if i + j < end {
                    let byte = self[i + j]
                    if byte >= 32 && byte <= 126 {
                        result += String(format: "%c", byte)
                    } else {
                        result += "."
                    }
                }
            }
            
            result += "\n"
        }
        
        return result
    }
}

// MARK: - Bank Inspector

struct BankInfo {
    let name: String
    let size: Int
    let header: String
    let sampleCount: Int?
    let voiceCount: Int?
    let format: String
}

func inspectBank(_ url: URL, verbose: Bool) throws -> BankInfo {
    let data = try Data(contentsOf: url)
    
    // Read first 512 bytes for header analysis
    let headerSize = Swift.min(512, data.count)
    let header = data.subdata(in: 0..<headerSize)
    
    // Try to extract name (first 16 bytes, ASCII)
    let nameData = header.subdata(in: 0..<Swift.min(16, header.count))
    let name = String(data: nameData, encoding: .ascii)?
        .trimmingCharacters(in: .whitespaces.union(.controlCharacters)) ?? "Unknown"
    
    // Detect format based on magic bytes or structure
    var format = "EMAX II Bank"
    
    // Check for common patterns
    if header.count >= 4 {
        let magic = header.readU32LE(at: 0)
        switch magic {
        case 0x00000000:
            format = "EMAX II Bank (Empty header)"
        default:
            format = "EMAX II Bank (Custom header: \(String(format: "0x%08X", magic)))"
        }
    }
    
    // Try to find sample count (varies by format)
    var sampleCount: Int? = nil
    var voiceCount: Int? = nil
    
    // EMAX II typically has sample count at offset 0x18-0x1C
    if data.count >= 0x20 {
        let possibleCount = Int(data.readU16LE(at: 0x18))
        if possibleCount > 0 && possibleCount < 256 {
            sampleCount = possibleCount
        }
        
        let possibleVoices = Int(data.readU16LE(at: 0x1A))
        if possibleVoices > 0 && possibleVoices < 256 {
            voiceCount = possibleVoices
        }
    }
    
    if verbose {
        print("\n=== Header Hex Dump (first 256 bytes) ===")
        print(data.hexDump(offset: 0, length: Swift.min(256, data.count)))
    }
    
    return BankInfo(
        name: name,
        size: data.count,
        header: String(format: "0x%08X", data.count >= 4 ? data.readU32LE(at: 0) : 0),
        sampleCount: sampleCount,
        voiceCount: voiceCount,
        format: format
    )
}

// MARK: - Main

guard let args = Args.parse(CommandLine.arguments) else {
    Args.printUsage()
    exit(1)
}

do {
    let bankURL = URL(fileURLWithPath: args.bank)
    
    guard FileManager.default.fileExists(atPath: bankURL.path) else {
        print("❌ Bank not found: \(bankURL.path)")
        exit(1)
    }
    
    print("🔍 Inspecting bank: \(bankURL.lastPathComponent)")
    print("")
    
    let info = try inspectBank(bankURL, verbose: args.verbose)
    
    print("📦 Bank Information:")
    print("   Name: \(info.name)")
    print("   Size: \(ByteCountFormatter.string(fromByteCount: Int64(info.size), countStyle: .file))")
    print("   Format: \(info.format)")
    print("   Header: \(info.header)")
    
    if let samples = info.sampleCount {
        print("   Samples: \(samples)")
    }
    
    if let voices = info.voiceCount {
        print("   Voices: \(voices)")
    }
    
    // JSON output
    let result: [String: Any] = [
        "success": true,
        "name": info.name,
        "size": info.size,
        "format": info.format,
        "header": info.header,
        "sampleCount": info.sampleCount as Any,
        "voiceCount": info.voiceCount as Any
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
