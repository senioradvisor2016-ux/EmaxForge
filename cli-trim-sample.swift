#!/usr/bin/env swift
// EmaxForge CLI - Trim Silence from Sample
// 
// Usage:
//   swift cli-trim-sample.swift --input sample.wav --output trimmed.wav

import Foundation

// MARK: - Args

struct Args {
    var input: String = ""
    var output: String = ""
    var threshold: Int = 5  // Silence threshold (0-255)
    var dryRun: Bool = false
    
    static func parse(_ args: [String]) -> Args? {
        var result = Args()
        var i = 1
        
        while i < args.count {
            let arg = args[i]
            
            switch arg {
            case "--input":
                guard i + 1 < args.count else { return nil }
                result.input = args[i + 1]
                i += 2
            
            case "--output":
                guard i + 1 < args.count else { return nil }
                result.output = args[i + 1]
                i += 2
            
            case "--threshold":
                guard i + 1 < args.count else { return nil }
                result.threshold = Int(args[i + 1]) ?? 5
                i += 2
            
            case "--dry-run":
                result.dryRun = true
                i += 1
            
            case "--help", "-h":
                return nil
            
            default:
                print("❌ Unknown option: \(arg)")
                return nil
            }
        }
        
        guard !result.input.isEmpty else {
            print("❌ --input required")
            return nil
        }
        
        if result.output.isEmpty {
            result.output = result.input.replacingOccurrences(of: ".wav", with: "_trimmed.wav")
        }
        
        return result
    }
    
    static func printUsage() {
        print("""
        EmaxForge CLI - Sample Trimmer
        
        Usage:
          swift cli-trim-sample.swift --input <wav> [--output <wav>] [options]
        
        Options:
          --input <wav>       Input WAV file
          --output <wav>      Output WAV file (default: input_trimmed.wav)
          --threshold <n>     Silence threshold 0-255 (default: 5)
          --dry-run          Show trim points without writing
          -h, --help          Show this help
        
        Examples:
          # Trim silence
          swift cli-trim-sample.swift --input sample.wav
          
          # Custom threshold
          swift cli-trim-sample.swift --input sample.wav --threshold 10
          
          # Preview trim points
          swift cli-trim-sample.swift --input sample.wav --dry-run
        """)
    }
}

// MARK: - WAV Parser

struct WAVFile {
    let header: Data
    let format: WAVFormat
    let samples: Data
    
    struct WAVFormat {
        let audioFormat: UInt16
        let numChannels: UInt16
        let sampleRate: UInt32
        let byteRate: UInt32
        let blockAlign: UInt16
        let bitsPerSample: UInt16
    }
}

func readWAV(_ url: URL) throws -> WAVFile {
    let data = try Data(contentsOf: url)
    
    // Parse RIFF header
    guard data.count >= 44 else {
        throw NSError(domain: "EmaxForge", code: 1, userInfo: [NSLocalizedDescriptionKey: "File too small"])
    }
    
    let riff = String(data: data.subdata(in: 0..<4), encoding: .ascii)
    guard riff == "RIFF" else {
        throw NSError(domain: "EmaxForge", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not a RIFF file"])
    }
    
    let wave = String(data: data.subdata(in: 8..<12), encoding: .ascii)
    guard wave == "WAVE" else {
        throw NSError(domain: "EmaxForge", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not a WAVE file"])
    }
    
    // Parse fmt chunk
    let audioFormat = data.readU16LE(at: 20)
    let numChannels = data.readU16LE(at: 22)
    let sampleRate = data.readU32LE(at: 24)
    let byteRate = data.readU32LE(at: 28)
    let blockAlign = data.readU16LE(at: 32)
    let bitsPerSample = data.readU16LE(at: 34)
    
    let format = WAVFile.WAVFormat(
        audioFormat: audioFormat,
        numChannels: numChannels,
        sampleRate: sampleRate,
        byteRate: byteRate,
        blockAlign: blockAlign,
        bitsPerSample: bitsPerSample
    )
    
    // Find data chunk
    var offset = 36
    while offset + 8 < data.count {
        let chunkID = String(data: data.subdata(in: offset..<offset+4), encoding: .ascii) ?? ""
        let chunkSize = Int(data.readU32LE(at: offset + 4))
        
        if chunkID == "data" {
            let samples = data.subdata(in: offset+8..<offset+8+chunkSize)
            let header = data.subdata(in: 0..<offset+8)
            return WAVFile(header: header, format: format, samples: samples)
        }
        
        offset += 8 + chunkSize
    }
    
    throw NSError(domain: "EmaxForge", code: 1, userInfo: [NSLocalizedDescriptionKey: "data chunk not found"])
}

// MARK: - Trimmer

func findTrimPoints(samples: Data, threshold: Int, bitsPerSample: UInt16) -> (start: Int, end: Int) {
    let bytesPerSample = Int(bitsPerSample / 8)
    let numSamples = samples.count / bytesPerSample
    
    // Find first non-silent sample
    var start = 0
    for i in 0..<numSamples {
        let offset = i * bytesPerSample
        let value: Int
        
        if bitsPerSample == 16 {
            let sample = samples.readI16LE(at: offset)
            value = abs(Int(sample))
        } else {
            let sample = Int8(bitPattern: samples[offset])
            value = abs(Int(sample))
        }
        
        if value > threshold {
            start = i
            break
        }
    }
    
    // Find last non-silent sample
    var end = numSamples - 1
    for i in stride(from: numSamples - 1, through: 0, by: -1) {
        let offset = i * bytesPerSample
        let value: Int
        
        if bitsPerSample == 16 {
            let sample = samples.readI16LE(at: offset)
            value = abs(Int(sample))
        } else {
            let sample = Int8(bitPattern: samples[offset])
            value = abs(Int(sample))
        }
        
        if value > threshold {
            end = i
            break
        }
    }
    
    return (start: start, end: end)
}

func trimSamples(samples: Data, start: Int, end: Int, bytesPerSample: Int) -> Data {
    let startByte = start * bytesPerSample
    let endByte = (end + 1) * bytesPerSample
    return samples.subdata(in: startByte..<endByte)
}

func writeWAV(format: WAVFile.WAVFormat, samples: Data, outputPath: String) throws {
    var wav = Data()
    
    let dataSize = UInt32(samples.count)
    
    // RIFF header
    wav.append("RIFF".data(using: .ascii)!)
    var chunkSize = UInt32(36 + dataSize)
    withUnsafeBytes(of: &chunkSize) { wav.append(contentsOf: $0) }
    wav.append("WAVE".data(using: .ascii)!)
    
    // fmt chunk
    wav.append("fmt ".data(using: .ascii)!)
    var fmtSize = UInt32(16)
    withUnsafeBytes(of: &fmtSize) { wav.append(contentsOf: $0) }
    var audioFormat = format.audioFormat
    withUnsafeBytes(of: &audioFormat) { wav.append(contentsOf: $0) }
    var channels = format.numChannels
    withUnsafeBytes(of: &channels) { wav.append(contentsOf: $0) }
    var rate = format.sampleRate
    withUnsafeBytes(of: &rate) { wav.append(contentsOf: $0) }
    var brate = format.byteRate
    withUnsafeBytes(of: &brate) { wav.append(contentsOf: $0) }
    var align = format.blockAlign
    withUnsafeBytes(of: &align) { wav.append(contentsOf: $0) }
    var bits = format.bitsPerSample
    withUnsafeBytes(of: &bits) { wav.append(contentsOf: $0) }
    
    // data chunk
    wav.append("data".data(using: .ascii)!)
    var size = dataSize
    withUnsafeBytes(of: &size) { wav.append(contentsOf: $0) }
    wav.append(samples)
    
    try wav.write(to: URL(fileURLWithPath: outputPath))
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
    
    func readI16LE(at offset: Int) -> Int16 {
        let unsigned = readU16LE(at: offset)
        return Int16(bitPattern: unsigned)
    }
}

// MARK: - Main

guard let args = Args.parse(CommandLine.arguments) else {
    Args.printUsage()
    exit(1)
}

do {
    let inputURL = URL(fileURLWithPath: args.input)
    
    guard FileManager.default.fileExists(atPath: inputURL.path) else {
        print("❌ Input not found: \(inputURL.path)")
        exit(1)
    }
    
    print("🔍 Analyzing: \(inputURL.lastPathComponent)")
    print("")
    
    let wav = try readWAV(inputURL)
    
    let bytesPerSample = Int(wav.format.bitsPerSample / 8)
    let numSamples = wav.samples.count / bytesPerSample
    let duration = Double(numSamples) / Double(wav.format.sampleRate)
    
    print("📊 Original:")
    print("   Samples: \(numSamples)")
    print("   Duration: \(String(format: "%.2f", duration)) seconds")
    print("   Size: \(wav.samples.count) bytes")
    print("")
    
    // Find trim points
    let (start, end) = findTrimPoints(
        samples: wav.samples,
        threshold: args.threshold,
        bitsPerSample: wav.format.bitsPerSample
    )
    
    let trimmedSamples = end - start + 1
    let trimmedDuration = Double(trimmedSamples) / Double(wav.format.sampleRate)
    let trimmedSize = trimmedSamples * bytesPerSample
    
    let removedStart = start
    let removedEnd = numSamples - end - 1
    let removedTotal = removedStart + removedEnd
    let savingsPercent = Double(removedTotal) / Double(numSamples) * 100.0
    
    print("✂️  Trim Points:")
    print("   Start: \(start) (removed \(removedStart) samples)")
    print("   End: \(end) (removed \(removedEnd) samples)")
    print("   Threshold: \(args.threshold)")
    print("")
    
    print("📊 Trimmed:")
    print("   Samples: \(trimmedSamples)")
    print("   Duration: \(String(format: "%.2f", trimmedDuration)) seconds")
    print("   Size: \(trimmedSize) bytes")
    print("")
    
    print("💾 Savings:")
    print("   Removed: \(removedTotal) samples (\(String(format: "%.1f", savingsPercent))%)")
    print("   Reduced: \(numSamples) → \(trimmedSamples) samples")
    print("")
    
    if args.dryRun {
        print("🏃 Dry run - no file written")
    } else {
        let trimmed = trimSamples(samples: wav.samples, start: start, end: end, bytesPerSample: bytesPerSample)
        try writeWAV(format: wav.format, samples: trimmed, outputPath: args.output)
        print("✅ Trimmed WAV written: \(args.output)")
    }
    
    // JSON output
    let result: [String: Any] = [
        "success": true,
        "input": args.input,
        "output": args.output,
        "original": [
            "samples": numSamples,
            "duration": duration,
            "size": wav.samples.count
        ],
        "trimmed": [
            "samples": trimmedSamples,
            "duration": trimmedDuration,
            "size": trimmedSize
        ],
        "trim": [
            "start": start,
            "end": end,
            "removedStart": removedStart,
            "removedEnd": removedEnd,
            "removedTotal": removedTotal,
            "savingsPercent": savingsPercent
        ],
        "dryRun": args.dryRun
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
