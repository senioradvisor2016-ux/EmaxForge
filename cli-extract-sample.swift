#!/usr/bin/env swift
// EmaxForge CLI - Extract Sample as WAV
// 
// Usage:
//   swift cli-extract-sample.swift --bank SOMEBODY.EB2 --output sample.wav

import Foundation
import AVFoundation

// MARK: - Args

struct Args {
    var bank: String = ""
    var output: String = "output.wav"
    var offset: Int = 0x7000  // Default sample data start
    var length: Int = 0  // 0 = auto-detect
    var rate: Int = 44100
    
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
            
            case "--output":
                guard i + 1 < args.count else { return nil }
                result.output = args[i + 1]
                i += 2
            
            case "--offset":
                guard i + 1 < args.count else { return nil }
                if let val = Int(args[i + 1], radix: 16) {
                    result.offset = val
                }
                i += 2
            
            case "--length":
                guard i + 1 < args.count else { return nil }
                result.length = Int(args[i + 1]) ?? 0
                i += 2
            
            case "--rate":
                guard i + 1 < args.count else { return nil }
                result.rate = Int(args[i + 1]) ?? 44100
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
        EmaxForge CLI - Sample Extractor
        
        Usage:
          swift cli-extract-sample.swift --bank <path> --output <wav> [options]
        
        Options:
          --bank <path>     Bank file (.EB2)
          --output <wav>    Output WAV file
          --offset <hex>    Sample data offset (default: 7000)
          --length <bytes>  Sample length (0 = auto-detect)
          --rate <hz>       Sample rate (default: 44100)
          -h, --help        Show this help
        
        Examples:
          # Extract first sample
          swift cli-extract-sample.swift --bank SOMEBODY.EB2 --output test.wav
          
          # Custom offset and length
          swift cli-extract-sample.swift --bank SOMEBODY.EB2 --output test.wav \\
            --offset 7000 --length 100000 --rate 22050
        """)
    }
}

// MARK: - WAV Writer

func writeWAV(pcmData: Data, sampleRate: Int, outputPath: String) throws {
    let numChannels: UInt16 = 1  // Mono
    let bitsPerSample: UInt16 = 16  // 16-bit
    let bytesPerSample = bitsPerSample / 8
    
    // Convert 8-bit signed to 16-bit signed
    var samples16bit = Data()
    for byte in pcmData {
        let signed8 = Int8(bitPattern: byte)
        let signed16 = Int16(signed8) * 256  // Scale to 16-bit
        
        var value = UInt16(bitPattern: signed16)
        withUnsafeBytes(of: &value) { samples16bit.append(contentsOf: $0) }
    }
    
    let dataSize = UInt32(samples16bit.count)
    let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bytesPerSample)
    let blockAlign = numChannels * bytesPerSample
    
    var wav = Data()
    
    // RIFF header
    wav.append("RIFF".data(using: .ascii)!)
    var chunkSize = UInt32(36 + dataSize)
    withUnsafeBytes(of: &chunkSize) { wav.append(contentsOf: $0) }
    wav.append("WAVE".data(using: .ascii)!)
    
    // fmt chunk
    wav.append("fmt ".data(using: .ascii)!)
    var fmtSize = UInt32(16)
    withUnsafeBytes(of: &fmtSize) { wav.append(contentsOf: $0) }
    var audioFormat = UInt16(1)  // PCM
    withUnsafeBytes(of: &audioFormat) { wav.append(contentsOf: $0) }
    var channels = numChannels
    withUnsafeBytes(of: &channels) { wav.append(contentsOf: $0) }
    var rate = UInt32(sampleRate)
    withUnsafeBytes(of: &rate) { wav.append(contentsOf: $0) }
    var brate = byteRate
    withUnsafeBytes(of: &brate) { wav.append(contentsOf: $0) }
    var align = blockAlign
    withUnsafeBytes(of: &align) { wav.append(contentsOf: $0) }
    var bits = bitsPerSample
    withUnsafeBytes(of: &bits) { wav.append(contentsOf: $0) }
    
    // data chunk
    wav.append("data".data(using: .ascii)!)
    var size = dataSize
    withUnsafeBytes(of: &size) { wav.append(contentsOf: $0) }
    wav.append(samples16bit)
    
    try wav.write(to: URL(fileURLWithPath: outputPath))
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
    
    let data = try Data(contentsOf: bankURL)
    
    print("🔍 Extracting sample from: \(bankURL.lastPathComponent)")
    print("")
    
    // Determine length
    let sampleLength: Int
    if args.length > 0 {
        sampleLength = args.length
    } else {
        // Auto-detect: read until end or low entropy
        sampleLength = Swift.min(data.count - args.offset, 500_000)  // Max 500 KB
    }
    
    guard args.offset + sampleLength <= data.count else {
        print("❌ Sample extends beyond file (offset: 0x\(String(format: "%X", args.offset)), length: \(sampleLength), file: \(data.count))")
        exit(1)
    }
    
    let sampleData = data.subdata(in: args.offset..<args.offset+sampleLength)
    
    print("📊 Sample Info:")
    print("   Offset: 0x\(String(format: "%X", args.offset)) (\(args.offset) bytes)")
    print("   Length: \(sampleLength) bytes (\(String(format: "%.2f", Double(sampleLength)/1024.0)) KB)")
    print("   Rate: \(args.rate) Hz")
    print("   Duration: \(String(format: "%.2f", Double(sampleLength) / Double(args.rate))) seconds")
    print("")
    
    try writeWAV(pcmData: sampleData, sampleRate: args.rate, outputPath: args.output)
    
    print("✅ WAV written: \(args.output)")
    print("")
    
    // JSON output
    let result: [String: Any] = [
        "success": true,
        "output": args.output,
        "offset": args.offset,
        "length": sampleLength,
        "rate": args.rate,
        "duration": Double(sampleLength) / Double(args.rate)
    ]
    
    if let jsonData = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        print("JSON_OUTPUT_START")
        print(jsonString)
        print("JSON_OUTPUT_END")
    }
    
} catch {
    print("❌ Error: \(error)")
    exit(1)
}
