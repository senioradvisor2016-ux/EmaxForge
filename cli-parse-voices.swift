#!/usr/bin/env swift
// EmaxForge CLI - Parse Voice/Zone Structure
// 
// Usage:
//   swift cli-parse-voices.swift --bank SOMEBODY.EB2

import Foundation

// MARK: - Args

struct Args {
    var bank: String = ""
    var verbose: Bool = false
    var maxVoices: Int = 10
    
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
            
            case "--max":
                guard i + 1 < args.count else { return nil }
                result.maxVoices = Int(args[i + 1]) ?? 10
                i += 2
            
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
        EmaxForge CLI - Voice/Zone Parser
        
        Usage:
          swift cli-parse-voices.swift --bank <path> [--verbose] [--max N]
        
        Options:
          --bank <path>   Bank file (.EB2)
          --verbose, -v   Show detailed hex dumps
          --max N         Max voices to show (default: 10)
          -h, --help      Show this help
        
        Examples:
          # Parse first 10 voices
          swift cli-parse-voices.swift --bank SOMEBODY.EB2
          
          # Show all voices with hex
          swift cli-parse-voices.swift --bank SOMEBODY.EB2 --max 100 --verbose
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
    
    func hexString(offset: Int, length: Int) -> String {
        let end = Swift.min(offset + length, count)
        let bytes = self[offset..<end]
        return bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

// MARK: - Structures

struct Voice {
    let index: Int
    let offset: Int
    let keyLow: UInt8
    let keyHigh: UInt8
    let velLow: UInt8
    let velHigh: UInt8
    let sampleIndex: UInt16
    let volume: UInt8
    let pan: UInt8
    let raw: Data
}

// MARK: - Parser

func parseVoices(_ url: URL, maxVoices: Int, verbose: Bool) throws -> [Voice] {
    let data = try Data(contentsOf: url)
    
    // Voice data starts around 0x260
    let voiceDataStart = 0x260
    let voiceSize = 16  // Each voice is 16 bytes
    
    var voices: [Voice] = []
    
    for i in 0..<maxVoices {
        let offset = voiceDataStart + (i * voiceSize)
        
        guard offset + voiceSize <= data.count else { break }
        
        let voiceData = data.subdata(in: offset..<offset+voiceSize)
        
        // Parse structure (hypothesis from SOMEBODY.EB2)
        let keyLow = voiceData[0]
        let keyHigh = voiceData[1]
        let velLow = voiceData[2]
        let velHigh = voiceData[3]
        
        // Sample index might be at offset 11-12 (2 bytes LE)
        let sampleIdx = UInt16(voiceData[11]) | (UInt16(voiceData[12]) << 8)
        
        // Volume at offset 10?
        let volume = voiceData[10]
        
        // Pan at offset 8?
        let pan = voiceData[8]
        
        let voice = Voice(
            index: i,
            offset: offset,
            keyLow: keyLow,
            keyHigh: keyHigh,
            velLow: velLow,
            velHigh: velHigh,
            sampleIndex: sampleIdx,
            volume: volume,
            pan: pan,
            raw: voiceData
        )
        
        voices.append(voice)
        
        if verbose {
            let hexStr = data.hexString(offset: offset, length: 16)
            print("[\(String(format: "%2d", i))] @0x\(String(format: "%04X", offset)): \(hexStr)")
        }
    }
    
    return voices
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
    
    print("🔍 Parsing voices: \(bankURL.lastPathComponent)")
    print("")
    
    let voices = try parseVoices(bankURL, maxVoices: args.maxVoices, verbose: args.verbose)
    
    if args.verbose {
        print("")
    }
    
    print("📊 Voice Structure (first \(Swift.min(args.maxVoices, voices.count)) voices):")
    print("")
    print("Idx  Key Range   Vel Range   Sample  Vol  Pan")
    print("---  ----------  ----------  ------  ---  ---")
    
    for voice in voices.prefix(args.maxVoices) {
        let idx = String(format: "%3d", voice.index)
        let keyLow = String(format: "%3d", voice.keyLow)
        let keyHigh = String(format: "%3d", voice.keyHigh)
        let velLow = String(format: "%3d", voice.velLow)
        let velHigh = String(format: "%3d", voice.velHigh)
        let sample = String(format: "%4d", voice.sampleIndex)
        let vol = String(format: "%3d", voice.volume)
        let pan = String(format: "%3d", voice.pan)
        
        print("\(idx)  \(keyLow)-\(keyHigh)      \(velLow)-\(velHigh)      \(sample)  \(vol)  \(pan)")
    }
    
    print("")
    print("Total voices found: \(voices.count)")
    
    // JSON output
    let result: [String: Any] = [
        "success": true,
        "voices": voices.count,
        "voiceData": voices.map { voice in
            [
                "index": voice.index,
                "keyLow": voice.keyLow,
                "keyHigh": voice.keyHigh,
                "velLow": voice.velLow,
                "velHigh": voice.velHigh,
                "sampleIndex": voice.sampleIndex,
                "volume": voice.volume,
                "pan": voice.pan,
                "hex": voice.raw.map { String(format: "%02X", $0) }.joined(separator: " ")
            ]
        }
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
