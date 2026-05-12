#!/usr/bin/env swift
// EmaxForge CLI - Export Samples to WAV
// 
// Usage:
//   swift cli-export-samples.swift --disk HD10.hda --bank 1 --output samples/
//   swift cli-export-samples.swift --disk HD10.hda --bank 1 --sample 0 --output kick.wav

import Foundation

// Load EmaxForge modules (hack: copy minimal parser code inline)

// MARK: - Args

struct Args {
    var disk: String = ""
    var bankIndex: Int = 0
    var bankName: String? = nil
    var sampleIndex: Int? = nil
    var output: String = ""
    var normalize: Bool = false
    
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
            
            case "--bank":
                guard i + 1 < args.count, let idx = Int(args[i + 1]) else { return nil }
                result.bankIndex = idx
                i += 2
            
            case "--bank-name":
                guard i + 1 < args.count else { return nil }
                result.bankName = args[i + 1]
                i += 2
            
            case "--sample":
                guard i + 1 < args.count, let idx = Int(args[i + 1]) else { return nil }
                result.sampleIndex = idx
                i += 2
            
            case "--output":
                guard i + 1 < args.count else { return nil }
                result.output = args[i + 1]
                i += 2
            
            case "--normalize":
                result.normalize = true
                i += 1
            
            case "--help", "-h":
                return nil
            
            default:
                print("❌ Unknown option: \(arg)")
                return nil
            }
        }
        
        guard !result.disk.isEmpty, !result.output.isEmpty, result.bankIndex > 0 else {
            print("❌ --disk, --bank, and --output required")
            return nil
        }
        
        return result
    }
    
    static func printUsage() {
        print("""
        EmaxForge CLI - Export Samples
        
        Usage:
          swift cli-export-samples.swift --disk <path> --bank <n> --output <dir>
          swift cli-export-samples.swift --disk <path> --bank <n> --sample <n> --output <file>
        
        Options:
          --disk <path>       Source disk image (.hda)
          --bank <n>          Bank index (1-based)
          --bank-name <name>  Bank name (alternative)
          --sample <n>        Export only sample N (0-based, optional)
          --output <path>     Output directory (all) or file (single)
          --normalize         Normalize PCM levels
          -h, --help          Show this help
        
        Examples:
          # Export all samples from bank 1
          swift cli-export-samples.swift --disk HD10.hda --bank 1 --output samples/
          
          # Export single sample
          swift cli-export-samples.swift --disk HD10.hda --bank 1 --sample 0 --output kick.wav
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
    
    mutating func writeU16LE(_ value: UInt16, at offset: Int) {
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8) & 0xFF)
    }
    
    mutating func writeU32LE(_ value: UInt32, at offset: Int) {
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8) & 0xFF)
        self[offset + 2] = UInt8((value >> 16) & 0xFF)
        self[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
}

// MARK: - Simplified Bank Parser

struct BankEntry {
    let name: String
    let cluster: UInt16
    let index: Int
}

func findBank(diskURL: URL, index: Int) throws -> (BankEntry, Int, UInt64) {
    let fileHandle = try FileHandle(forReadingFrom: diskURL)
    defer { try? fileHandle.close() }

    // Read EMAX II header (512 bytes at offset 0)
    fileHandle.seek(toFileOffset: 0)
    let header = fileHandle.readData(ofLength: 512)
    guard header.count == 512,
          String(data: header[0..<4], encoding: .ascii) == "EMX2" else {
        throw NSError(domain: "EmaxForge", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Not an EMAX II disk image"])
    }

    // Header offsets (verified against EmaxIIFileSystem.swift)
    let clusterSize         = Int(header.readU32LE(at: 4))
    let bntStartSector      = Int(header.readU32LE(at: 0x10))
    let maxBanks            = Int(header.readU32LE(at: 0x14))
    let clusterAreaStartSec = Int(header.readU32LE(at: 0x20))
    let clusterAreaStart    = UInt64(clusterAreaStartSec) * 512

    // Read BNT (Bank Name Table / catalog)
    let bntOffset = UInt64(bntStartSector) * 512
    let bntSize   = (clusterAreaStartSec - bntStartSector) * 512
    fileHandle.seek(toFileOffset: bntOffset)
    let catalogData = fileHandle.readData(ofLength: min(bntSize, (maxBanks + 1) * 32))

    var bankIndex = 1
    let maxSlots = min(maxBanks + 1, catalogData.count / 32)

    // BNT entry layout: name[0..15], startCluster(U16) at +16, flags at +26
    for i in 0..<maxSlots {
        let base = i * 32
        guard base + 32 <= catalogData.count else { break }

        let nameData = catalogData.subdata(in: base..<(base + 16))
        guard !nameData.allSatisfy({ $0 == 0 || $0 == 0xFF }) else { continue }

        let name = String(data: nameData, encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? ""
        guard !name.isEmpty else { continue }

        let bankIdx      = catalogData.readU16LE(at: base + 16)  // +0x10: bankIndex (0x7800=OS)
        let startCluster = catalogData.readU16LE(at: base + 18)  // +0x12: actual FAT start cluster
        let flags        = catalogData.readU16LE(at: base + 26)

        // 0x7800 = OS/boot entry — skip
        if bankIdx == 0x7800 { continue }
        guard flags == 0x0081 else { continue }

        let entry = BankEntry(name: name, cluster: startCluster, index: bankIndex)
        if bankIndex == index {
            return (entry, clusterSize, clusterAreaStart)
        }
        bankIndex += 1
    }

    throw NSError(domain: "EmaxForge", code: 404, userInfo: [NSLocalizedDescriptionKey: "Bank \(index) not found"])
}

// MARK: - WAV Writer

func writeWAV(pcmData: Data, sampleRate: UInt32, outputURL: URL) throws {
    var wav = Data()
    
    // RIFF header
    wav.append("RIFF".data(using: .ascii)!)
    var temp = Data(count: 4); temp.writeU32LE(UInt32(36 + pcmData.count), at: 0); wav.append(temp)
    wav.append("WAVE".data(using: .ascii)!)
    
    // fmt chunk
    wav.append("fmt ".data(using: .ascii)!)
    temp = Data(count: 4); temp.writeU32LE(16, at: 0); wav.append(temp)
    temp = Data(count: 2); temp.writeU16LE(1, at: 0); wav.append(temp)  // PCM
    temp = Data(count: 2); temp.writeU16LE(1, at: 0); wav.append(temp)  // mono
    temp = Data(count: 4); temp.writeU32LE(sampleRate, at: 0); wav.append(temp)
    temp = Data(count: 4); temp.writeU32LE(sampleRate * 2, at: 0); wav.append(temp)
    temp = Data(count: 2); temp.writeU16LE(2, at: 0); wav.append(temp)
    temp = Data(count: 2); temp.writeU16LE(16, at: 0); wav.append(temp)
    
    // data chunk
    wav.append("data".data(using: .ascii)!)
    temp = Data(count: 4); temp.writeU32LE(UInt32(pcmData.count), at: 0); wav.append(temp)
    wav.append(pcmData)
    
    try wav.write(to: outputURL)
}

// MARK: - Main

guard let args = Args.parse(CommandLine.arguments) else {
    Args.printUsage()
    exit(1)
}

print("🎵 EmaxForge Sample Export")
print("")
print("⚠️  NOTE: This is a SIMPLIFIED implementation")
print("⚠️  For full sample extraction, use EmaxForge.app or integrate SampleExporter.swift")
print("")
print("Current capability: Placeholder export (generates silence)")
print("Full implementation requires: BankParser + SampleExporter integration")
print("")

// Placeholder: Find bank, "export" silence
do {
    let diskURL = URL(fileURLWithPath: args.disk)
    let (bank, clusterSize, _) = try findBank(diskURL: diskURL, index: args.bankIndex)
    
    print("Found bank: \(bank.name)")
    print("Cluster size: \(clusterSize / 1024) KB")
    print("")
    
    if let sampleIdx = args.sampleIndex {
        // Single sample (placeholder)
        let outputURL = URL(fileURLWithPath: args.output)
        let silence = Data(count: 44100 * 2)  // 1 sec silence, 16-bit
        try writeWAV(pcmData: silence, sampleRate: 44100, outputURL: outputURL)
        print("✅ Exported (placeholder): \(outputURL.path)")
    } else {
        // All samples (placeholder)
        try FileManager.default.createDirectory(atPath: args.output, withIntermediateDirectories: true)
        
        for i in 0..<8 {  // Placeholder: 8 samples
            let filename = String(format: "%02d_sample.wav", i + 1)
            let outputURL = URL(fileURLWithPath: args.output).appendingPathComponent(filename)
            let silence = Data(count: 22050 * 2)  // 0.5 sec
            try writeWAV(pcmData: silence, sampleRate: 44100, outputURL: outputURL)
        }
        
        print("✅ Exported 8 placeholder samples to: \(args.output)")
    }
    
    // JSON output
    let result: [String: Any] = [
        "success": true,
        "note": "Placeholder implementation - exports silence",
        "bank_name": bank.name,
        "output": args.output,
        "full_implementation_needed": "Integrate SampleExporter.swift from EmaxForge/Sources/Services/"
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
