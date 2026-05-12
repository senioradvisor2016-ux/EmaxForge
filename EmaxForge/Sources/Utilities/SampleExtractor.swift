import Foundation

/// Extracts samples from EMAX-II banks to WAV files
struct SampleExtractor {
    
    // MARK: - Extraction Result
    
    struct ExtractionResult {
        let samplesExtracted: Int
        let totalSize: Int64
        let destinationURL: URL
        let errors: [String]
        
        var success: Bool { errors.isEmpty }
        var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        }
    }
    
    // MARK: - Public Interface
    
    /// Extract all samples from a bank file on disk to individual WAV files
    func extractAllSamples(
        from bankURL: URL,
        to destinationURL: URL,
        progress: @escaping (String, Double) -> Void
    ) async throws -> ExtractionResult {
        
        // Read bank data
        let bankData = try Data(contentsOf: bankURL)
        
        // Parse bank samples
        guard let sampleData = EmaxIIParser.extractSampleData(from: bankData) else {
            throw ExtractionError.invalidBankFormat
        }
        
        var extractedCount = 0
        var totalSize: Int64 = 0
        var errors: [String] = []
        
        // Extract each sample
        for (index, sampleEntry) in sampleData.samples.enumerated() {
            let progressValue = Double(index) / Double(sampleData.samples.count)
            progress("Extracting \(sampleEntry.name)...", progressValue)
            
            do {
                let wavData = try generateWAV(from: sampleEntry)
                let filename = sanitizeFilename(sampleEntry.name) + ".wav"
                let fileURL = destinationURL.appendingPathComponent(filename)
                
                try wavData.write(to: fileURL)
                
                extractedCount += 1
                totalSize += Int64(wavData.count)
                
            } catch {
                errors.append("Failed to extract \(sampleEntry.name): \(error.localizedDescription)")
            }
        }
        
        progress("Complete!", 1.0)
        
        return ExtractionResult(
            samplesExtracted: extractedCount,
            totalSize: totalSize,
            destinationURL: destinationURL,
            errors: errors
        )
    }
    
    /// Extract samples from an image's bank (via cluster chain)
    func extractSamplesFromImage(
        imageURL: URL,
        bankName: String,
        to destinationURL: URL,
        progress: @escaping (String, Double) -> Void
    ) async throws -> ExtractionResult {
        
        // Parse file system
        let fs = try EmaxIIParser.parseHDImage(at: imageURL)
        
        // Read image data
        let imageData = try Data(contentsOf: imageURL)
        
        // Find bank
        guard let bank = fs.banks.first(where: { $0.name == bankName }) else {
            throw ExtractionError.bankNotFound(bankName)
        }
        
        // Read bank data from cluster chain
        let clusterSize = fs.clusterSize
        let clusterAreaOffset = Int(fs.clusterAreaStartOffset)
        var bankData = Data()
        
        for cluster in bank.clusterChain {
            let offset = clusterAreaOffset + cluster * clusterSize  // 0-based
            guard offset + clusterSize <= imageData.count else {
                throw ExtractionError.corruptedClusterChain
            }
            bankData.append(imageData[offset..<offset + clusterSize])
        }
        
        // Parse bank samples
        guard let sampleData = EmaxIIParser.extractSampleData(from: bankData) else {
            throw ExtractionError.invalidBankFormat
        }
        
        // Extract samples (same as above)
        var extractedCount = 0
        var totalSize: Int64 = 0
        var errors: [String] = []
        
        for (index, sampleEntry) in sampleData.samples.enumerated() {
            let progressValue = Double(index) / Double(sampleData.samples.count)
            progress("Extracting \(sampleEntry.name)...", progressValue)
            
            do {
                let wavData = try generateWAV(from: sampleEntry)
                let filename = sanitizeFilename(sampleEntry.name) + ".wav"
                let fileURL = destinationURL.appendingPathComponent(filename)
                
                try wavData.write(to: fileURL)
                
                extractedCount += 1
                totalSize += Int64(wavData.count)
                
            } catch {
                errors.append("Failed to extract \(sampleEntry.name): \(error.localizedDescription)")
            }
        }
        
        progress("Complete!", 1.0)
        
        return ExtractionResult(
            samplesExtracted: extractedCount,
            totalSize: totalSize,
            destinationURL: destinationURL,
            errors: errors
        )
    }
    
    // MARK: - WAV Generation
    
    /// Generate WAV file data from sample entry
    private func generateWAV(from sample: BankSampleData.SampleEntry) throws -> Data {
        var wavData = Data()
        
        let sampleRate = UInt32(sample.sampleRate)
        let numChannels: UInt16 = 1  // Mono
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = UInt32(sample.pcmData.count)
        
        // RIFF header
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: dataSize + 36) { Data($0) })  // File size - 8
        wavData.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: UInt32(16)) { Data($0) })  // fmt chunk size
        wavData.append(withUnsafeBytes(of: UInt16(1)) { Data($0) })   // Audio format (1 = PCM)
        wavData.append(withUnsafeBytes(of: numChannels) { Data($0) })
        wavData.append(withUnsafeBytes(of: sampleRate) { Data($0) })
        wavData.append(withUnsafeBytes(of: byteRate) { Data($0) })
        wavData.append(withUnsafeBytes(of: blockAlign) { Data($0) })
        wavData.append(withUnsafeBytes(of: bitsPerSample) { Data($0) })
        
        // data chunk
        wavData.append("data".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: dataSize) { Data($0) })
        wavData.append(sample.pcmData)
        
        // Optional: Add smpl chunk for loop points
        if let loopStart = sample.loopStart, let loopEnd = sample.loopEnd, loopStart < loopEnd {
            wavData.append(createSmplChunk(
                sampleRate: sampleRate,
                rootKey: UInt32(sample.rootKey),
                loopStart: UInt32(loopStart),
                loopEnd: UInt32(loopEnd)
            ))
        }
        
        return wavData
    }
    
    /// Create smpl chunk for loop metadata
    private func createSmplChunk(sampleRate: UInt32, rootKey: UInt32, loopStart: UInt32, loopEnd: UInt32) -> Data {
        var chunk = Data()
        
        chunk.append("smpl".data(using: .ascii)!)
        chunk.append(withUnsafeBytes(of: UInt32(60)) { Data($0) })  // Chunk size
        
        // smpl chunk data
        chunk.append(withUnsafeBytes(of: UInt32(0)) { Data($0) })   // Manufacturer
        chunk.append(withUnsafeBytes(of: UInt32(0)) { Data($0) })   // Product
        chunk.append(withUnsafeBytes(of: UInt32(1_000_000_000 / sampleRate)) { Data($0) })  // Sample period
        chunk.append(withUnsafeBytes(of: rootKey) { Data($0) })     // MIDI unity note
        chunk.append(withUnsafeBytes(of: UInt32(0)) { Data($0) })   // MIDI pitch fraction
        chunk.append(withUnsafeBytes(of: UInt32(0)) { Data($0) })   // SMPTE format
        chunk.append(withUnsafeBytes(of: UInt32(0)) { Data($0) })   // SMPTE offset
        chunk.append(withUnsafeBytes(of: UInt32(1)) { Data($0) })   // Num sample loops
        chunk.append(withUnsafeBytes(of: UInt32(0)) { Data($0) })   // Sampler data
        
        // Loop 0
        chunk.append(withUnsafeBytes(of: UInt32(0)) { Data($0) })   // Cue point ID
        chunk.append(withUnsafeBytes(of: UInt32(0)) { Data($0) })   // Type (0 = forward)
        chunk.append(withUnsafeBytes(of: loopStart) { Data($0) })   // Start
        chunk.append(withUnsafeBytes(of: loopEnd) { Data($0) })     // End
        chunk.append(withUnsafeBytes(of: UInt32(0)) { Data($0) })   // Fraction
        chunk.append(withUnsafeBytes(of: UInt32(0)) { Data($0) })   // Play count (0 = infinite)
        
        return chunk
    }
    
    // MARK: - Helpers
    
    /// Sanitize filename for file system
    private func sanitizeFilename(_ name: String) -> String {
        var sanitized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove invalid characters
        let invalidChars = CharacterSet(charactersIn: "/:*?\"<>|\\")
        sanitized = sanitized.components(separatedBy: invalidChars).joined(separator: "_")
        
        // Replace multiple spaces/underscores
        while sanitized.contains("  ") {
            sanitized = sanitized.replacingOccurrences(of: "  ", with: " ")
        }
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }
        
        // Limit length
        if sanitized.count > 64 {
            sanitized = String(sanitized.prefix(64))
        }
        
        // Default if empty
        if sanitized.isEmpty {
            sanitized = "Sample"
        }
        
        return sanitized
    }
    
    // MARK: - Errors
    
    enum ExtractionError: LocalizedError {
        case invalidBankFormat
        case invalidImageFormat
        case bankNotFound(String)
        case corruptedClusterChain
        case writeError(URL)
        
        var errorDescription: String? {
            switch self {
            case .invalidBankFormat:
                return "Invalid bank format - cannot parse EB2 structure"
            case .invalidImageFormat:
                return "Invalid image format - cannot parse EMAX-II file system"
            case .bankNotFound(let name):
                return "Bank '\(name)' not found in image"
            case .corruptedClusterChain:
                return "Corrupted cluster chain - bank data is incomplete"
            case .writeError(let url):
                return "Failed to write to \(url.path)"
            }
        }
    }
}
