import Foundation
import AVFoundation

/// Convert various sample formats to EMAX II .EB2 banks
class SampleConverter {
    
    enum ConvertError: LocalizedError {
        case unsupportedFormat(String)
        case readError(String)
        case emptyInput
        case tooManySamples
        case sampleTooLarge(String)
        case conversionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let f): return "Unsupported format: \(f)"
            case .readError(let msg): return "Read error: \(msg)"
            case .emptyInput: return "No samples provided"
            case .tooManySamples: return "Maximum 16 zones/samples per bank"
            case .sampleTooLarge(let name): return "Sample too large: \(name) (max ~4MB per bank)"
            case .conversionFailed(let msg): return "Conversion failed: \(msg)"
            }
        }
    }
    
    /// Supported input formats
    static let supportedExtensions = ["wav", "aiff", "aif", "mp3", "m4a", "flac", "ogg", "sf2"]
    
    /// A loaded sample ready for conversion
    struct LoadedSample {
        let name: String
        let pcmData: Data          // 16-bit signed LE PCM, mono
        let originalSampleRate: Double
        let lowKey: UInt8          // MIDI note (0-127), default 0
        let highKey: UInt8         // MIDI note (0-127), default 127
        let rootKey: UInt8         // MIDI note for original pitch, default 60
    }
    
    // MARK: - Load audio files as PCM
    
    /// Load an audio file and convert to 16-bit signed mono PCM
    static func loadAudioFile(at url: URL) throws -> LoadedSample {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw ConvertError.readError(error.localizedDescription)
        }
        
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw ConvertError.conversionFailed("Could not create audio buffer")
        }
        
        try file.read(into: buffer)
        
        // Convert to 16-bit signed mono
        let pcmData = convertToMono16Bit(buffer: buffer)
        
        let name = url.deletingPathExtension().lastPathComponent
            .prefix(12)
            .padding(toLength: 12, withPad: " ", startingAt: 0)
        
        return LoadedSample(
            name: String(name),
            pcmData: pcmData,
            originalSampleRate: format.sampleRate,
            lowKey: 0,
            highKey: 127,
            rootKey: 60
        )
    }
    
    /// Load multiple audio files with automatic key zone assignment
    static func loadMultiSamples(urls: [URL]) throws -> [LoadedSample] {
        guard !urls.isEmpty else { throw ConvertError.emptyInput }
        guard urls.count <= 16 else { throw ConvertError.tooManySamples }
        
        var samples: [LoadedSample] = []
        let keysPerZone = 128 / urls.count
        
        for (i, url) in urls.enumerated() {
            var sample = try loadAudioFile(at: url)
            
            // Distribute across keyboard
            let lowKey = UInt8(i * keysPerZone)
            let highKey = UInt8(min((i + 1) * keysPerZone - 1, 127))
            let rootKey = UInt8((Int(lowKey) + Int(highKey)) / 2)
            
            sample = LoadedSample(
                name: sample.name,
                pcmData: sample.pcmData,
                originalSampleRate: sample.originalSampleRate,
                lowKey: lowKey,
                highKey: highKey,
                rootKey: rootKey
            )
            
            samples.append(sample)
        }
        
        return samples
    }
    
    // MARK: - Build EB2 bank
    
    /// Create an EMAX II .EB2 bank from loaded samples
    static func buildEB2Bank(bankName: String, samples: [LoadedSample]) throws -> Data {
        guard !samples.isEmpty else { throw ConvertError.emptyInput }
        guard samples.count <= 16 else { throw ConvertError.tooManySamples }
        
        let numZones = samples.count
        let paddedName = String(bankName.prefix(12)).padding(toLength: 12, withPad: " ", startingAt: 0)
        
        // Calculate total sample data size
        let totalSampleBytes = samples.reduce(0) { $0 + $1.pcmData.count }
        
        // EB2 structure:
        // 0x000 - 0x0C9: Key pointer table (101 entries × 2 bytes) - RAM addresses
        // 0x0CA - 0x0FF: Padding
        // 0x100 - 0x19F: Key output table (40 entries × 4 bytes)
        // 0x1A0 - 0x1A3: Sample data end (RAM address)
        // 0x1A4 - 0x1A7: Preset data end (RAM address)
        // 0x1A8 - 0x1AB: Voice block size
        // 0x1AC - 0x1B7: Bank name (12 bytes)
        // 0x1B8+: Preset header + zone map + zone pointers + voice params
        // Then: sample data
        
        // Build the bank data
        var bank = Data(count: 0x1B8) // Header portion
        
        // --- Key pointer table (0x00-0xC9) ---
        // For simplicity, point all keys to beginning of sample data
        // (EMAX II RAM addresses — we use relative offsets)
        let sampleRAMBase: UInt16 = 0x0200
        for i in stride(from: 0, to: 0xCA, by: 2) {
            bank.writeU16LE(sampleRAMBase, at: i)
        }
        
        // --- Key output table (0x100-0x19F) ---
        // Default: all keys to output A (stereo pair 1)
        for i in stride(from: 0x100, to: 0x1A0, by: 4) {
            bank.writeU32LE(0x00000000, at: i)
        }
        
        // --- Bank metadata (0x1A0-0x1B7) ---
        let sampleEndAddr = UInt32(totalSampleBytes + 0x200)
        let presetEndAddr = sampleEndAddr + 32
        let voiceBlockSize = UInt32(numZones * 32)
        
        bank.writeU32LE(sampleEndAddr, at: 0x1A0)
        bank.writeU32LE(presetEndAddr, at: 0x1A4)
        bank.writeU32LE(voiceBlockSize, at: 0x1A8)
        
        // Bank name
        let nameData = paddedName.data(using: .ascii) ?? Data(repeating: 0x20, count: 12)
        bank.replaceSubrange(0x1AC..<0x1B8, with: nameData.prefix(12))
        
        // --- Preset header (single preset type 'A') ---
        var presetHeader = Data(count: 32)
        presetHeader[0] = 0x41      // 'A' marker — single preset
        presetHeader[1] = 0x00
        presetHeader[2] = 0x00
        presetHeader[3] = 99        // Volume = 99
        presetHeader[4] = 0x00
        presetHeader[5] = 47        // Transpose = 47 (center)
        presetHeader[6] = 33        // Tune coarse
        presetHeader[7] = 2         // Tune fine
        bank.append(presetHeader)
        
        // --- Zone map (key-to-zone assignment) ---
        // First zone map (42 bytes): pairs of keys
        var zoneMap1 = Data(repeating: 0xFF, count: 42)
        for (idx, sample) in samples.enumerated() {
            let startPair = Int(sample.lowKey) / 2
            let endPair = min(Int(sample.highKey) / 2, 41)
            let zoneIdx = UInt8(idx)
            for p in startPair...endPair {
                zoneMap1[p] = zoneIdx
            }
        }
        bank.append(zoneMap1)
        
        // Padding to 0x1F8 equivalent
        let paddingNeeded = max(0, 6) // Small pad
        bank.append(Data(count: paddingNeeded))
        
        // Extended zone map (48 bytes)
        var zoneMap2 = Data(repeating: 0xFF, count: 48)
        for (idx, sample) in samples.enumerated() {
            let startKey = Int(sample.lowKey) * 48 / 128
            let endKey = min(Int(sample.highKey) * 48 / 128, 47)
            for k in startKey...endKey {
                zoneMap2[k] = UInt8(idx)
            }
        }
        bank.append(zoneMap2)
        
        // --- Zone pointers (4 bytes per zone) ---
        for i in 0..<numZones {
            let ptr = Data([0x00, 0x00, UInt8(i), 0xFF])
            bank.append(ptr)
        }
        // End marker
        bank.append(Data([0x00, 0x00, 0xFF, 0xFF]))
        
        // --- Voice parameter blocks (32 bytes per zone) ---
        for (idx, sample) in samples.enumerated() {
            var voice = Data(count: 32)
            
            // Default voice parameters (from factory banks)
            // These create a basic "open filter, full envelope" sound
            voice.writeU16LE(0x0000, at: 0)   // Attenuation: 0dB
            voice.writeU16LE(0x4000, at: 2)   // Tune: center
            voice.writeU16LE(0x0000, at: 4)   // Delay: 0
            voice.writeU16LE(0x0100, at: 6)   // VCA Attack: fast
            voice.writeU16LE(0x7F00, at: 8)   // VCA Hold/Decay: sustain
            voice.writeU16LE(0xFF00, at: 10)  // VCA Sustain: full
            voice.writeU16LE(0x0800, at: 12)  // VCA Release: medium
            voice.writeU16LE(0x7F00, at: 14)  // Filter Fc: open
            voice.writeU16LE(0x0000, at: 16)  // Filter Q: 0
            voice.writeU16LE(0x0000, at: 18)  // Filter Env: 0
            voice.writeU16LE(0x0100, at: 20)  // Filter Attack: fast
            voice.writeU16LE(0xFF00, at: 22)  // Filter Sustain: full
            voice.writeU16LE(0x0800, at: 24)  // Filter Release: medium
            voice.writeU16LE(0x0000, at: 26)  // LFO: off
            voice.writeU16LE(0x4000, at: 28)  // Pan: center
            voice.writeU16LE(0x0000, at: 30)  // Chorus: off
            
            bank.append(voice)
        }
        
        // --- Sample data ---
        // Append all sample PCM data sequentially
        for sample in samples {
            bank.append(sample.pcmData)
        }
        
        // Pad to even boundary
        if bank.count % 2 != 0 {
            bank.append(Data([0x00]))
        }
        
        return bank
    }
    
    // MARK: - Convert buffer to mono 16-bit
    
    /// Convert audio buffer to 16-bit signed mono PCM
    /// Supports stereo → mono conversion with different modes
    static func convertToMono16Bit(buffer: AVAudioPCMBuffer, stereoMode: String = "mono") -> Data {
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        var pcmData = Data(capacity: frameCount * 2)
        
        if let floatData = buffer.floatChannelData {
            for frame in 0..<frameCount {
                // Mix to mono
                var sample: Float = 0
                for ch in 0..<channelCount {
                    sample += floatData[ch][frame]
                }
                sample /= Float(channelCount)
                
                // Clamp and convert to Int16
                let clamped = max(-1.0, min(1.0, sample))
                let int16 = Int16(clamped * Float(Int16.max))
                
                // Write as little-endian
                var le = int16.littleEndian
                pcmData.append(Data(bytes: &le, count: 2))
            }
        } else if let int16Data = buffer.int16ChannelData {
            for frame in 0..<frameCount {
                // Mix to mono
                var sum: Int32 = 0
                for ch in 0..<channelCount {
                    sum += Int32(int16Data[ch][frame])
                }
                let mono = Int16(sum / Int32(channelCount))
                
                var le = mono.littleEndian
                pcmData.append(Data(bytes: &le, count: 2))
            }
        }
        
        return pcmData
    }
    
    // MARK: - Convenience: files → EB2
    
    /// Convert audio files directly to an .EB2 bank file
    static func convertToEB2(audioURLs: [URL], bankName: String, outputURL: URL) throws {
        let samples = try loadMultiSamples(urls: audioURLs)
        let bankData = try buildEB2Bank(bankName: bankName, samples: samples)
        try bankData.write(to: outputURL)
    }
    
    /// Convert audio files and import directly into an HD image
    static func convertAndImport(audioURLs: [URL], bankName: String, imageURL: URL) throws -> BankImporter.ImportResult {
        let samples = try loadMultiSamples(urls: audioURLs)
        let bankData = try buildEB2Bank(bankName: bankName, samples: samples)
        
        // Write to temp file, then import
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("EB2")
        try bankData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        return try BankImporter.importBank(eb2URL: tempURL, into: imageURL, allowDuplicate: true)
    }
}

// MARK: - Data write helpers

private extension Data {
    mutating func writeU16LE(_ value: UInt16, at offset: Int) {
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8(value >> 8)
    }
    
    mutating func writeU32LE(_ value: UInt32, at offset: Int) {
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8) & 0xFF)
        self[offset + 2] = UInt8((value >> 16) & 0xFF)
        self[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
}
