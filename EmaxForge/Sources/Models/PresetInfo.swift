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
        "\(SampleFilenameTemplate.midiNoteName(keyRangeLow)) - \(SampleFilenameTemplate.midiNoteName(keyRangeHigh))"
    }

    var voiceDescription: String {
        "\(voiceCount) voice\(voiceCount != 1 ? "s" : "")"
    }
    
    var sampleCount: Int {
        samples.count
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
        for bank in fs.banks where bank.bankIndex != 0x7800 { // Skip OS (OS has bankIndex=0x7800 at BNT+0x10)
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
            let offset = clusterAreaOffset + cluster * clusterSize  // 0-based
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

            // Parse zone count (exact field at +0x23) and key map (+0x24, 88 bytes).
            // keyMap[i] = sample index for MIDI key (21+i), or 0xFF = unassigned.
            // zoneCount = number of unique assigned sample indices.
            let zoneCountOffset = 0x23
            let keyMapOffset    = 0x24
            let keyMapLength    = 88
            let keyMapMidiBase  = 21

            let zoneCount = offset + zoneCountOffset < bankData.count
                ? Int(bankData[offset + zoneCountOffset]) : 0

            var sampleIndices = [Int]()
            var firstAssignedKey = -1
            var lastAssignedKey  = -1
            let keyMapStart = offset + keyMapOffset
            if keyMapStart + keyMapLength <= bankData.count {
                for k in 0..<keyMapLength {
                    let idx = Int(bankData[keyMapStart + k])
                    if idx != 0xFF {
                        if firstAssignedKey < 0 { firstAssignedKey = keyMapMidiBase + k }
                        lastAssignedKey = keyMapMidiBase + k
                        if !sampleIndices.contains(idx) { sampleIndices.append(idx) }
                    }
                }
            }

            // Resolve sample names by index
            let usedSamples: [String] = sampleIndices.compactMap { idx in
                guard idx < sampleNames.count else { return nil }
                return sampleNames[idx]
            }

            let keyLow  = firstAssignedKey >= 0 ? firstAssignedKey : 0
            let keyHigh = lastAssignedKey  >= 0 ? lastAssignedKey  : 127

            let info = PresetInfo(
                name: name,
                bankName: bank.name,
                presetIndex: i,
                voiceCount: max(1, zoneCount),
                samples: usedSamples,
                keyRangeLow: keyLow,
                keyRangeHigh: keyHigh,
                velocityLayers: 1
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
