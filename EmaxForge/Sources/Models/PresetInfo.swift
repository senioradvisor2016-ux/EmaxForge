import Foundation

/// Information about a preset in a disk image
struct PresetInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bankName: String
    let presetIndex: Int
    let voiceCount: Int
    let samples: [String]
    let keyRangeLow: Int
    let keyRangeHigh: Int
    let velocityLayers: Int
    
    var keyRangeDescription: String {
        "\(midiNoteName(keyRangeLow)) - \(midiNoteName(keyRangeHigh))"
    }
    
    var voiceDescription: String {
        "\(voiceCount) voice\(voiceCount != 1 ? "s" : "")"
    }
    
    var sampleCount: Int {
        samples.count
    }
    
    private func midiNoteName(_ note: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (note / 12) - 1
        let name = names[note % 12]
        return "\(name)\(octave)"
    }
}

/// Analyzer that extracts preset information from a disk image
struct PresetAnalyzer {
    
    struct AnalysisResult {
        let presets: [PresetInfo]
        let totalPresets: Int
        let totalVoices: Int
        let averageVoicesPerPreset: Double
        
        var formattedStats: String {
            String(format: "%d presets, %d voices (avg: %.1f/preset)",
                   totalPresets, totalVoices, averageVoicesPerPreset)
        }
    }
    
    /// Analyze all presets in a disk image
    func analyzePresets(in imageURL: URL) async throws -> AnalysisResult {
        // Parse file system
        let fs = try EmaxIIParser.parseHDImage(at: imageURL)
        
        var allPresets: [PresetInfo] = []
        var totalVoices = 0
        
        // Process each bank
        for bank in fs.banks where bank.startCluster != 1 { // Skip OS
            if let bankPresets = try? extractPresetsFromBank(bank, fs: fs, imageURL: imageURL) {
                allPresets.append(contentsOf: bankPresets)
                totalVoices += bankPresets.reduce(0) { $0 + $1.voiceCount }
            }
        }
        
        let avgVoices = allPresets.isEmpty ? 0.0 : Double(totalVoices) / Double(allPresets.count)
        
        return AnalysisResult(
            presets: allPresets,
            totalPresets: allPresets.count,
            totalVoices: totalVoices,
            averageVoicesPerPreset: avgVoices
        )
    }
    
    /// Extract preset info from a single bank
    private func extractPresetsFromBank(_ bank: BankCatalogEntry, fs: EmaxIIFileSystem, imageURL: URL) throws -> [PresetInfo] {
        // Read bank data from cluster chain
        let imageData = try Data(contentsOf: imageURL)
        let clusterSize = fs.clusterSize
        let clusterAreaOffset = Int(fs.clusterAreaStartOffset)
        var bankData = Data()
        
        for cluster in bank.clusterChain {
            let offset = clusterAreaOffset + (cluster - 1) * clusterSize
            guard offset + clusterSize <= imageData.count else {
                throw AnalysisError.corruptedData
            }
            bankData.append(imageData[offset..<offset + clusterSize])
        }
        
        // Parse bank header for preset count
        guard bankData.count >= 0x200 else { return [] }
        let numPresets = Int(bankData[0x1C]) | (Int(bankData[0x1D]) << 8)
        
        // Extract samples names
        let sampleNames = extractSampleNames(from: bankData)
        
        // Parse presets
        var presets: [PresetInfo] = []
        let presetBase = 0x200
        let presetSize = 0x100
        
        for i in 0..<min(numPresets, 256) {
            let offset = presetBase + i * presetSize
            guard offset + presetSize <= bankData.count else { break }
            
            // Read preset name (16 bytes at offset)
            let nameData = bankData[offset..<offset+16]
            let name = String(data: nameData, encoding: .ascii)?
                .trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? "Preset \(i+1)"
            
            if name.isEmpty { continue }
            
            // Parse voice count and key ranges (simplified)
            let voiceCount = Int(bankData[offset + 0x20]) // Approximate
            let keyLow = Int(bankData[offset + 0x30])
            let keyHigh = Int(bankData[offset + 0x31])
            
            // TODO: Parse actual voice/zone structure for accurate sample mapping
            let usedSamples = sampleNames.prefix(min(voiceCount, sampleNames.count)).map { $0 }
            
            let info = PresetInfo(
                name: name,
                bankName: bank.name,
                presetIndex: i,
                voiceCount: max(1, voiceCount),
                samples: Array(usedSamples),
                keyRangeLow: max(0, min(127, keyLow)),
                keyRangeHigh: max(0, min(127, keyHigh)),
                velocityLayers: 1 // Simplified
            )
            
            presets.append(info)
        }
        
        return presets
    }
    
    /// Extract sample names from bank data
    private func extractSampleNames(from data: Data) -> [String] {
        var names: [String] = []
        let sampleParamBase = 0x10200
        let sampleParamSize = 0x40
        let nameOffset = 32
        
        for i in 0..<999 {
            let offset = sampleParamBase + i * sampleParamSize + nameOffset
            guard offset + 16 <= data.count else { break }
            
            let nameData = data[offset..<offset+16]
            let name = String(data: nameData, encoding: .ascii)?
                .trimmingCharacters(in: .init(charactersIn: "\0 "))
            
            if let name = name, !name.isEmpty {
                names.append(name)
            }
        }
        
        return names
    }
    
    // MARK: - Errors
    
    enum AnalysisError: LocalizedError {
        case corruptedData
        case invalidFormat
        
        var errorDescription: String? {
            switch self {
            case .corruptedData: return "Corrupted bank data"
            case .invalidFormat: return "Invalid bank format"
            }
        }
    }
}
