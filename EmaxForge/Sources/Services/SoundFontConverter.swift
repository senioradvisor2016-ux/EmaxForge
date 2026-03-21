import Foundation
import AVFoundation

/// Convert SoundFont 2 (.sf2) files to EMAX II .EB2 banks
class SoundFontConverter {
    
    enum SoundFontError: LocalizedError {
        case invalidFile
        case unsupportedVersion
        case noPresets
        case noSamples
        case readError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidFile: return "Invalid SoundFont file"
            case .unsupportedVersion: return "Unsupported SoundFont version (only SF2.01 supported)"
            case .noPresets: return "No presets found in SoundFont"
            case .noSamples: return "No samples found in SoundFont"
            case .readError(let msg): return "Read error: \(msg)"
            }
        }
    }
    
    /// SF2 chunk identifiers
    private enum ChunkID: String {
        case riff = "RIFF"
        case sfbk = "sfbk"
        case pdta = "pdta"
        case phdr = "phdr"  // Preset headers
        case pbag = "pbag"  // Preset bags
        case pmod = "pmod"  // Preset modulators
        case pgen = "pgen"  // Preset generators
        case inst = "inst"  // Instruments
        case ibag = "ibag"  // Instrument bags
        case imod = "imod"  // Instrument modulators
        case igen = "igen"  // Instrument generators
        case shdr = "shdr"  // Sample headers
        case sdta = "sdta"
        case smpl = "smpl"  // Sample data
    }
    
    struct Preset {
        let name: String
        let bank: UInt16
        let preset: UInt16
        let presetBagIndex: UInt16
        let library: UInt32
        let genre: UInt32
        let morphology: UInt32
    }
    
    struct Sample {
        let name: String
        let start: UInt32
        let end: UInt32
        let startLoop: UInt32
        let endLoop: UInt32
        let sampleRate: UInt32
        let originalPitch: UInt8
        let pitchCorrection: Int8
        let sampleLink: UInt16
        let sampleType: UInt16
        let data: Data  // 16-bit signed PCM
    }
    
    struct Instrument {
        let name: String
        let instrumentBagIndex: UInt16
    }
    
    /// Convert SF2 file to EB2 banks
    static func convertToEB2(url: URL) throws -> [(name: String, data: Data)] {
        let fileData = try Data(contentsOf: url)
        
        // Parse SF2 structure
        let (presets, instruments, samples) = try parseSoundFont(data: fileData)
        
        guard !presets.isEmpty else {
            throw SoundFontError.noPresets
        }
        
        guard !samples.isEmpty else {
            throw SoundFontError.noSamples
        }
        
        // Convert each preset to an EB2 bank
        var banks: [(String, Data)] = []
        
        for preset in presets {
            // Find instruments for this preset
            let presetBanks = try convertPresetToEB2(
                preset: preset,
                instruments: instruments,
                samples: samples,
                presetName: preset.name
            )
            banks.append(contentsOf: presetBanks)
        }
        
        return banks
    }
    
    // MARK: - SF2 Parsing
    
    private static func parseSoundFont(data: Data) throws -> (presets: [Preset], instruments: [Instrument], samples: [Sample]) {
        guard data.count >= 12 else {
            throw SoundFontError.invalidFile
        }
        
        // Check RIFF header
        let riffID = String(data: data[0..<4], encoding: .ascii) ?? ""
        guard riffID == "RIFF" else {
            throw SoundFontError.invalidFile
        }
        
        // Check sfbk chunk
        let sfbkID = String(data: data[8..<12], encoding: .ascii) ?? ""
        guard sfbkID == "sfbk" else {
            throw SoundFontError.invalidFile
        }
        
        var offset = 12
        var presets: [Preset] = []
        var instruments: [Instrument] = []
        var samples: [Sample] = []
        var sampleData: Data?
        
        // Parse chunks
        while offset < data.count - 8 {
            let chunkID = String(data: data[offset..<(offset + 4)], encoding: .ascii) ?? ""
            let chunkSize = data.readU32LE(at: offset + 4)
            offset += 8
            
            switch chunkID {
            case "LIST":
                let listType = String(data: data[offset..<(offset + 4)], encoding: .ascii) ?? ""
                offset += 4
                let listSize = Int(chunkSize) - 4
                
                if listType == "pdta" {
                    // Parse preset data
                    let (parsedPresets, parsedInstruments) = try parsePDTA(data: data, offset: offset, size: listSize)
                    presets = parsedPresets
                    instruments = parsedInstruments
                } else if listType == "sdta" {
                    // Parse sample data
                    sampleData = try parseSDTA(data: data, offset: offset, size: listSize)
                }
                
                offset += listSize
                
            default:
                offset += Int(chunkSize)
            }
            
            // Align to even boundary
            if offset % 2 != 0 {
                offset += 1
            }
        }
        
        // Parse sample headers (from pdta)
        if let sdta = sampleData {
            samples = try parseSampleHeaders(data: data, sampleData: sdta)
        }
        
        return (presets, instruments, samples)
    }
    
    private static func parsePDTA(data: Data, offset: Int, size: Int) throws -> ([Preset], [Instrument]) {
        var pos = offset
        var presets: [Preset] = []
        var instruments: [Instrument] = []
        
        while pos < offset + size - 8 {
            let chunkID = String(data: data[pos..<(pos + 4)], encoding: .ascii) ?? ""
            let chunkSize = data.readU32LE(at: pos + 4)
            pos += 8
            
            switch chunkID {
            case "phdr":
                // Preset headers: 38 bytes each
                let count = Int(chunkSize) / 38
                for i in 0..<count {
                    let presetOffset = pos + (i * 38)
                    if presetOffset + 38 <= data.count {
                        let name = String(data: data[presetOffset..<(presetOffset + 20)], encoding: .ascii)?
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\0")) ?? ""
                        let preset = UInt16(data.readU16LE(at: presetOffset + 20))
                        let bank = UInt16(data.readU16LE(at: presetOffset + 22))
                        let presetBagIndex = UInt16(data.readU16LE(at: presetOffset + 24))
                        let library = data.readU32LE(at: presetOffset + 26)
                        let genre = data.readU32LE(at: presetOffset + 30)
                        let morphology = data.readU32LE(at: presetOffset + 34)
                        
                        presets.append(Preset(
                            name: name,
                            bank: bank,
                            preset: preset,
                            presetBagIndex: presetBagIndex,
                            library: library,
                            genre: genre,
                            morphology: morphology
                        ))
                    }
                }
                
            case "inst":
                // Instrument headers: 22 bytes each
                let count = Int(chunkSize) / 22
                for i in 0..<count {
                    let instOffset = pos + (i * 22)
                    if instOffset + 22 <= data.count {
                        let name = String(data: data[instOffset..<(instOffset + 20)], encoding: .ascii)?
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\0")) ?? ""
                        let instrumentBagIndex = UInt16(data.readU16LE(at: instOffset + 20))
                        
                        instruments.append(Instrument(
                            name: name,
                            instrumentBagIndex: instrumentBagIndex
                        ))
                    }
                }
                
            default:
                break
            }
            
            pos += Int(chunkSize)
            if pos % 2 != 0 { pos += 1 }
        }
        
        return (presets, instruments)
    }
    
    private static func parseSDTA(data: Data, offset: Int, size: Int) throws -> Data? {
        var pos = offset
        
        while pos < offset + size - 8 {
            let chunkID = String(data: data[pos..<(pos + 4)], encoding: .ascii) ?? ""
            let chunkSize = data.readU32LE(at: pos + 4)
            pos += 8
            
            if chunkID == "smpl" {
                return data[pos..<(pos + Int(chunkSize))]
            }
            
            pos += Int(chunkSize)
            if pos % 2 != 0 { pos += 1 }
        }
        
        return nil
    }
    
    private static func parseSampleHeaders(data: Data, sampleData: Data) throws -> [Sample] {
        // Find shdr chunk in pdta
        var offset = 0
        var samples: [Sample] = []
        
        while offset < data.count - 8 {
            let chunkID = String(data: data[offset..<(offset + 4)], encoding: .ascii) ?? ""
            let chunkSize = data.readU32LE(at: offset + 4)
            offset += 8
            
            if chunkID == "shdr" {
                // Sample headers: 46 bytes each
                let count = Int(chunkSize) / 46
                for i in 0..<count {
                    let shdrOffset = offset + (i * 46)
                    if shdrOffset + 46 <= data.count {
                        let name = String(data: data[shdrOffset..<(shdrOffset + 20)], encoding: .ascii)?
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\0")) ?? ""
                        let start = data.readU32LE(at: shdrOffset + 20)
                        let end = data.readU32LE(at: shdrOffset + 24)
                        let startLoop = data.readU32LE(at: shdrOffset + 28)
                        let endLoop = data.readU32LE(at: shdrOffset + 32)
                        let sampleRate = data.readU32LE(at: shdrOffset + 36)
                        let originalPitch = data[shdrOffset + 40]
                        let pitchCorrection = Int8(bitPattern: data[shdrOffset + 41])
                        let sampleLink = data.readU16LE(at: shdrOffset + 42)
                        let sampleType = data.readU16LE(at: shdrOffset + 44)
                        
                        // Extract sample data (16-bit signed PCM)
                        let sampleStart = Int(start) * 2  // 16-bit = 2 bytes per sample
                        let sampleLength = Int(end - start) * 2
                        let sampleBytes = sampleData[sampleStart..<min(sampleStart + sampleLength, sampleData.count)]
                        
                        samples.append(Sample(
                            name: name,
                            start: start,
                            end: end,
                            startLoop: startLoop,
                            endLoop: endLoop,
                            sampleRate: sampleRate,
                            originalPitch: originalPitch,
                            pitchCorrection: pitchCorrection,
                            sampleLink: sampleLink,
                            sampleType: sampleType,
                            data: Data(sampleBytes)
                        ))
                    }
                }
                break
            }
            
            offset += Int(chunkSize)
            if offset % 2 != 0 { offset += 1 }
        }
        
        return samples
    }
    
    // MARK: - EB2 Conversion
    
    private static func convertPresetToEB2(
        preset: Preset,
        instruments: [Instrument],
        samples: [Sample],
        presetName: String
    ) throws -> [(String, Data)] {
        // For now, convert first sample in preset to EB2
        // Full implementation would map all zones properly
        guard !samples.isEmpty else {
            return []
        }
        
        // Use first sample as a simple conversion
        let sample = samples[0]
        
        // Convert sample to EB2 format using SampleConverter
        let loadedSample = SampleConverter.LoadedSample(
            name: presetName.prefix(12).padding(toLength: 12, withPad: " ", startingAt: 0),
            pcmData: sample.data,
            originalSampleRate: Double(sample.sampleRate),
            lowKey: 0,
            highKey: 127,
            rootKey: sample.originalPitch
        )
        
        let bankData = try SampleConverter.buildEB2Bank(
            bankName: presetName,
            samples: [loadedSample]
        )
        
        return [(presetName, bankData)]
    }
}

// MARK: - Data Helpers

private extension Data {
    func readU16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return withUnsafeBytes { bytes in
            bytes.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt16.self).littleEndian
        }
    }
    
    func readU32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return withUnsafeBytes { bytes in
            bytes.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt32.self).littleEndian
        }
    }
}
