import Foundation

/// Information about a sample in a disk image
struct SampleInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bankName: String
    let sampleIndex: Int        // 0-based index within the bank
    let size: Int
    let bitDepth: Int
    let sampleRate: Int
    let duration: Double
    let hasLoop: Bool
    let loopStart: Int?
    let loopEnd: Int?
    let usedByPresets: [String]
    let pcmData: Data           // Raw 16-bit LE PCM for preview/export
    
    var isOrphan: Bool { usedByPresets.isEmpty }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let ms = Int((duration.truncatingRemainder(dividingBy: 1)) * 1000)
        if minutes > 0 {
            return String(format: "%d:%02d.%03d", minutes, seconds, ms)
        } else {
            return String(format: "%d.%03d s", seconds, ms)
        }
    }
    
    var formattedRate: String {
        "\(sampleRate) Hz"
    }
    
    var formatDescription: String {
        "\(bitDepth)-bit"
    }
}

/// Analyzer that extracts sample information from a disk image
struct SampleAnalyzer {
    
    struct AnalysisResult {
        let samples: [SampleInfo]
        let totalSize: Int64
        let orphanCount: Int
        let averageDuration: Double
        
        var formattedTotalSize: String {
            ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        }
    }
    
    /// Analyze all samples in a disk image
    func analyzeSamples(in imageURL: URL) async throws -> AnalysisResult {
        // Parse file system
        let fs = try EmaxIIParser.parseHDImage(at: imageURL)
        
        var allSamples: [SampleInfo] = []
        var totalSize: Int64 = 0
        
        // Process each bank
        for bank in fs.banks where bank.bankIndex != 0x7800 { // Skip OS (OS has bankIndex=0x7800 at BNT+0x10)
            if let bankSamples = try? extractSamplesFromBank(bank, fs: fs, imageURL: imageURL) {
                allSamples.append(contentsOf: bankSamples)
            }
        }
        
        // Calculate stats
        totalSize = allSamples.reduce(0) { $0 + Int64($1.size) }
        let orphanCount = allSamples.filter(\.isOrphan).count
        let avgDuration = allSamples.isEmpty ? 0 : allSamples.reduce(0.0) { $0 + $1.duration } / Double(allSamples.count)
        
        return AnalysisResult(
            samples: allSamples,
            totalSize: totalSize,
            orphanCount: orphanCount,
            averageDuration: avgDuration
        )
    }
    
    /// Extract sample info from a single bank
    private func extractSamplesFromBank(_ bank: BankCatalogEntry, fs: EmaxIIFileSystem, imageURL: URL) throws -> [SampleInfo] {
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
        
        // Parse bank to get samples
        guard let sampleData = EmaxIIParser.extractSampleData(from: bankData) else {
            return []
        }
        
        // Parse bank to get preset info (for "used by" tracking)
        // TODO: Use bankInfo for proper preset→sample mapping once zone structure is implemented
        _ = EmaxIIParser.parseBankData(bankData)
        let presetNames = extractPresetNames(from: bankData)
        
        // Build sample info list
        var samples: [SampleInfo] = []
        
        for sample in sampleData.samples {
            // Find which presets use this sample
            let usedBy = presetNames // TODO: Implement proper preset->sample mapping
            
            let info = SampleInfo(
                name: sample.name,
                bankName: bank.name,
                sampleIndex: sample.index,
                size: sample.pcmData.count,
                bitDepth: 16, // EMAX-II is always 16-bit
                sampleRate: sample.sampleRate,
                duration: sample.duration,
                hasLoop: sample.loopStart != nil && sample.loopEnd != nil,
                loopStart: sample.loopStart,
                loopEnd: sample.loopEnd,
                usedByPresets: usedBy,
                pcmData: sample.pcmData
            )
            
            samples.append(info)
        }
        
        return samples
    }
    
    /// Extract preset names from bank data
    private func extractPresetNames(from data: Data) -> [String] {
        var names: [String] = []
        
        // Preset area starts at 0x200, 256 presets × 256 bytes
        let presetBase = 0x200
        let presetSize = 0x100
        
        for i in 0..<256 {
            let offset = presetBase + i * presetSize
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
