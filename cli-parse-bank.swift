#!/usr/bin/env swift
// EmaxForge CLI - Parse .EB2 Bank Structure
// 
// Usage:
//   swift cli-parse-bank.swift --bank SOMEBODY.EB2

import Foundation

// MARK: - Args

struct Args {
    var bank: String = ""
    var verbose: Bool = false
    var samples: Bool = false
    
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
            
            case "--samples":
                result.samples = true
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
        EmaxForge CLI - Parse .EB2 Bank
        
        Usage:
          swift cli-parse-bank.swift --bank <path> [--verbose] [--samples]
        
        Options:
          --bank <path>   Bank file (.EB2)
          --verbose, -v   Show detailed structure
          --samples       Extract sample info
          -h, --help      Show this help
        
        Examples:
          # Parse bank structure
          swift cli-parse-bank.swift --bank SOMEBODY.EB2
          
          # With sample details
          swift cli-parse-bank.swift --bank SOMEBODY.EB2 --samples --verbose
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
    
    func readString(at offset: Int, length: Int) -> String {
        let bytes = self.subdata(in: offset..<Swift.min(offset + length, count))
        return String(data: bytes, encoding: .ascii)?
            .trimmingCharacters(in: .whitespaces.union(.controlCharacters)) ?? ""
    }
}

// MARK: - Bank Structures

struct EB2Header {
    let signature: UInt16        // 0x81AD
    let pointerCount: UInt8      // First byte after signature
    let pointers: [UInt16]       // Pointer table
    let bankNameOffset: Int?     // Offset to bank name
}

struct EB2Voice {
    let name: String
    let zones: [EB2Zone]
}

struct EB2Zone {
    let sampleIndex: Int
    let keyLow: UInt8
    let keyHigh: UInt8
    let velocity: UInt8
}

struct EB2Sample {
    let name: String
    let rate: UInt16
    let length: UInt32
    let loopStart: UInt32?
    let loopEnd: UInt32?
}

// MARK: - Parser

func parseEB2(_ url: URL, verbose: Bool) throws -> (header: EB2Header, voices: [EB2Voice], samples: [EB2Sample]) {
    let data = try Data(contentsOf: url)
    
    // 1. Read signature (last 2 bytes of header region)
    let sig = data.readU16LE(at: 0)
    guard sig == 0x81AD else {
        throw NSError(domain: "EmaxForge", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid signature: \(String(format: "0x%04X", sig))"])
    }
    
    // 2. Pointer count (byte 2)
    let pointerCount = data.readU8(at: 2)
    
    if verbose {
        print("🔍 Header Analysis:")
        print("   Signature: 0x81AD ✅")
        print("   Pointer count: \(pointerCount)")
    }
    
    // 3. Read pointer table (starts at offset 2, 2 bytes each)
    var pointers: [UInt16] = []
    for i in 0..<Swift.min(Int(pointerCount), 100) {
        let offset = 2 + (i * 2)
        if offset + 2 <= data.count {
            let ptr = data.readU16LE(at: offset)
            pointers.append(ptr)
        }
    }
    
    if verbose {
        print("   Pointers: \(pointers.count) entries")
        print("   First pointer: 0x\(String(format: "%04X", pointers.first ?? 0))")
    }
    
    // 4. Find bank name (typically around offset 0x1A0-0x1B0)
    var bankNameOffset: Int? = nil
    var bankName = "Unknown"
    
    // Helper: Check if string is valid bank name
    func isValidBankName(_ str: String) -> Bool {
        guard str.count >= 4 else { return false }
        
        // Must start with uppercase letter or digit
        guard let first = str.first, first.isUppercase || first.isNumber else {
            return false
        }
        
        // Check all chars are printable ASCII (32-126)
        for char in str {
            let scalar = char.unicodeScalars.first?.value ?? 0
            if scalar < 32 || scalar > 126 {
                return false
            }
        }
        
        // Prefer names with spaces (real names like "SOMEBODY    A")
        let hasSpace = str.contains(" ")
        
        // Reject common false positives
        if str.hasPrefix("T>") { return false }  // Control char pattern
        if str.allSatisfy({ $0 == " " }) { return false }  // All spaces
        
        return hasSpace  // Prefer names with spaces
    }
    
    // Scan for valid bank name
    var candidates: [(offset: Int, name: String, score: Int)] = []
    
    for offset in stride(from: 0x100, to: Swift.min(0x400, data.count - 16), by: 1) {
        // Read raw bytes first
        guard offset + 16 <= data.count else { break }
        let bytes = data.subdata(in: offset..<offset+16)
        
        // Try ASCII interpretation
        if let testName = String(data: bytes, encoding: .ascii) {
            let cleaned = testName.trimmingCharacters(in: .whitespaces.union(.controlCharacters))
            
            if isValidBankName(cleaned) {
                // Score candidate
                var score = 0
                if cleaned.contains(" ") { score += 10 }  // Has spaces
                if cleaned.count >= 8 { score += 5 }      // Long name
                if offset >= 0x180 && offset <= 0x1C0 { score += 20 }  // Common offset range
                
                candidates.append((offset: offset, name: cleaned, score: score))
            }
        }
    }
    
    // Pick best candidate
    if let best = candidates.max(by: { $0.score < $1.score }) {
        bankName = best.name
        bankNameOffset = best.offset
    }
    
    if verbose && bankNameOffset != nil {
        print("   Bank name: \"\(bankName)\" @ 0x\(String(format: "%X", bankNameOffset!))")
    }
    
    let header = EB2Header(
        signature: sig,
        pointerCount: pointerCount,
        pointers: pointers,
        bankNameOffset: bankNameOffset
    )
    
    // 5. Parse voices (simplified - full implementation needs reverse engineering)
    var voices: [EB2Voice] = []
    
    // Voice data typically starts after header (~0x200-0x300)
    // Each voice has:
    //   - Zone count
    //   - Zone definitions (key range, velocity, sample index)
    
    // Placeholder: Detect voice count from pointer table
    let estimatedVoices = pointers.filter { $0 != 0x8400 && $0 != 0xFFFF }.count
    
    if verbose {
        print("   Estimated voices: \(estimatedVoices)")
    }
    
    // 6. Parse samples (simplified - needs full spec)
    var samples: [EB2Sample] = []
    
    // Sample data location varies - need to walk pointer chain
    // For now, just estimate from file size
    
    return (header: header, voices: voices, samples: samples)
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
    
    print("🔍 Parsing bank: \(bankURL.lastPathComponent)")
    print("")
    
    let (header, voices, samples) = try parseEB2(bankURL, verbose: args.verbose)
    
    print("📦 Bank Structure:")
    print("   Signature: 0x\(String(format: "%04X", header.signature))")
    print("   Pointers: \(header.pointers.count)")
    
    if let nameOffset = header.bankNameOffset {
        let data = try Data(contentsOf: bankURL)
        let name = data.readString(at: nameOffset, length: 16)
        print("   Name: \"\(name)\"")
    }
    
    print("   Voices: \(voices.count) (estimated: \(header.pointers.filter { $0 != 0x8400 && $0 != 0xFFFF }.count))")
    print("   Samples: \(samples.count)")
    
    if args.samples && !samples.isEmpty {
        print("")
        print("📊 Samples:")
        for (i, sample) in samples.enumerated() {
            print("   [\(i)] \(sample.name)")
            print("       Rate: \(sample.rate) Hz")
            print("       Length: \(sample.length) samples")
            if let loopStart = sample.loopStart, let loopEnd = sample.loopEnd {
                print("       Loop: \(loopStart) - \(loopEnd)")
            }
        }
    }
    
    // JSON output
    let result: [String: Any] = [
        "success": true,
        "signature": String(format: "0x%04X", header.signature),
        "pointers": header.pointers.count,
        "bankName": header.bankNameOffset != nil ? try Data(contentsOf: bankURL).readString(at: header.bankNameOffset!, length: 16) : "Unknown",
        "voices": voices.count,
        "samples": samples.count,
        "size": try Data(contentsOf: bankURL).count
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
