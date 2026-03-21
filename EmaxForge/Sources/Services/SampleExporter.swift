import Foundation
import AVFoundation

/// Export EMAX II samples to standard audio formats (WAV, AIFF)
class SampleExporter {
    
    enum ExportFormat: String, CaseIterable {
        case wav = "WAV"
        case aiff = "AIFF"
        
        var fileExtension: String {
            switch self {
            case .wav: return "wav"
            case .aiff: return "aiff"
            }
        }
        
        var formatID: AudioFormatID {
            switch self {
            case .wav: return kAudioFormatLinearPCM
            case .aiff: return kAudioFormatLinearPCM
            }
        }
        
        var fileType: AudioFileTypeID {
            switch self {
            case .wav: return kAudioFileWAVEType
            case .aiff: return kAudioFileAIFFType
            }
        }
    }
    
    enum ExportError: LocalizedError {
        case noSampleData
        case createFileFailed
        case writeFailed(String)
        case invalidFormat
        
        var errorDescription: String? {
            switch self {
            case .noSampleData: return "No sample data to export"
            case .createFileFailed: return "Could not create output file"
            case .writeFailed(let msg): return "Write failed: \(msg)"
            case .invalidFormat: return "Invalid audio format"
            }
        }
    }
    
    /// Export result for UI feedback
    struct ExportResult {
        let sampleName: String
        let outputURL: URL
        let duration: Double
        let sampleRate: Int
        let fileSize: Int64
    }
    
    // MARK: - Single Sample Export
    
    /// Export a single sample entry to WAV or AIFF
    static func exportSample(
        _ sample: BankSampleData.SampleEntry,
        to directory: URL,
        format: ExportFormat = .wav,
        normalize: Bool = false
    ) throws -> ExportResult {
        guard !sample.pcmData.isEmpty else { throw ExportError.noSampleData }
        
        let sanitizedName = sanitizeFilename(sample.name)
        let outputURL = directory
            .appendingPathComponent(sanitizedName)
            .appendingPathExtension(format.fileExtension)
        
        var pcmData = sample.pcmData
        if normalize {
            pcmData = normalizePCM(pcmData)
        }
        
        try writePCMToFile(
            pcmData: pcmData,
            sampleRate: Double(sample.sampleRate),
            to: outputURL,
            format: format
        )
        
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
        
        return ExportResult(
            sampleName: sample.name,
            outputURL: outputURL,
            duration: sample.duration,
            sampleRate: sample.sampleRate,
            fileSize: fileSize
        )
    }
    
    // MARK: - Batch Export (all samples from a bank)
    
    /// Export all samples from a bank to a directory
    static func exportAllSamples(
        from bankSamples: BankSampleData,
        bankName: String,
        to baseDirectory: URL,
        format: ExportFormat = .wav,
        normalize: Bool = false,
        createSubfolder: Bool = true
    ) throws -> [ExportResult] {
        let outputDir: URL
        if createSubfolder {
            let folderName = sanitizeFilename(bankName)
            outputDir = baseDirectory.appendingPathComponent(folderName)
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        } else {
            outputDir = baseDirectory
        }
        
        var results = [ExportResult]()
        
        for (index, sample) in bankSamples.samples.enumerated() {
            // Prefix with index for sort order
            var entry = sample
            let numberedName = String(format: "%02d_%@", index + 1, sample.name)
            
            let sanitized = sanitizeFilename(numberedName)
            let outputURL = outputDir
                .appendingPathComponent(sanitized)
                .appendingPathExtension(format.fileExtension)
            
            var pcmData = sample.pcmData
            if normalize { pcmData = normalizePCM(pcmData) }
            
            try writePCMToFile(
                pcmData: pcmData,
                sampleRate: Double(sample.sampleRate),
                to: outputURL,
                format: format
            )
            
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
            
            results.append(ExportResult(
                sampleName: sample.name,
                outputURL: outputURL,
                duration: sample.duration,
                sampleRate: sample.sampleRate,
                fileSize: fileSize
            ))
        }
        
        return results
    }
    
    // MARK: - Export entire image (all banks → folders)
    
    /// Export all banks from an HD image to WAV
    static func exportImage(
        imageURL: URL,
        to baseDirectory: URL,
        format: ExportFormat = .wav,
        normalize: Bool = false,
        progress: ((String, Double) -> Void)? = nil
    ) throws -> [ExportResult] {
        let fs = try EmaxIIParser.parseHDImage(at: imageURL)
        var allResults = [ExportResult]()
        let userBanks = fs.userBanks
        
        for (i, bank) in userBanks.enumerated() {
            let bankProgress = Double(i) / Double(userBanks.count)
            progress?(bank.name, bankProgress)
            
            guard let bankData = EmaxIIParser.readBankData(from: imageURL, entry: bank, clusterSize: fs.clusterSize, clusterAreaStartSector: fs.clusterAreaStartSector),
                  let samples = EmaxIIParser.extractSampleData(from: bankData) else {
                continue
            }
            
            let results = try exportAllSamples(
                from: samples,
                bankName: bank.name,
                to: baseDirectory,
                format: format,
                normalize: normalize,
                createSubfolder: true
            )
            allResults.append(contentsOf: results)
        }
        
        progress?("Done", 1.0)
        return allResults
    }
    
    // MARK: - PCM Writing
    
    /// Write 16-bit LE PCM data to a WAV or AIFF file
    private static func writePCMToFile(
        pcmData: Data,
        sampleRate: Double,
        to url: URL,
        format: ExportFormat
    ) throws {
        let frameCount = pcmData.count / 2  // 16-bit = 2 bytes per frame
        guard frameCount > 0 else { throw ExportError.noSampleData }
        
        // Create audio format description
        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: format == .wav
                ? (kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked)
                : (kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagIsBigEndian),
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        
        // Create audio file
        var audioFile: AudioFileID?
        let createStatus = AudioFileCreateWithURL(
            url as CFURL,
            format.fileType,
            &asbd,
            .eraseFile,
            &audioFile
        )
        
        guard createStatus == noErr, let file = audioFile else {
            throw ExportError.createFileFailed
        }
        
        defer { AudioFileClose(file) }
        
        // Write data
        if format == .wav {
            // WAV uses little-endian 16-bit — our data is already LE
            var numBytes = UInt32(pcmData.count)
            let writeStatus = pcmData.withUnsafeBytes { rawBuf in
                AudioFileWriteBytes(file, false, 0, &numBytes, rawBuf.baseAddress!)
            }
            guard writeStatus == noErr else {
                throw ExportError.writeFailed("AudioFileWriteBytes failed: \(writeStatus)")
            }
        } else {
            // AIFF uses big-endian — need to byte-swap
            var beData = Data(count: pcmData.count)
            pcmData.withUnsafeBytes { src in
                beData.withUnsafeMutableBytes { dst in
                    let srcBytes = src.bindMemory(to: UInt8.self)
                    let dstBytes = dst.bindMemory(to: UInt8.self)
                    for i in stride(from: 0, to: pcmData.count - 1, by: 2) {
                        dstBytes[i] = srcBytes[i + 1]
                        dstBytes[i + 1] = srcBytes[i]
                    }
                }
            }
            var numBytes = UInt32(beData.count)
            let writeStatus = beData.withUnsafeBytes { rawBuf in
                AudioFileWriteBytes(file, false, 0, &numBytes, rawBuf.baseAddress!)
            }
            guard writeStatus == noErr else {
                throw ExportError.writeFailed("AudioFileWriteBytes failed: \(writeStatus)")
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Normalize PCM data to use full dynamic range
    private static func normalizePCM(_ data: Data) -> Data {
        let frameCount = data.count / 2
        guard frameCount > 0 else { return data }
        
        // Find peak
        var peak: Int16 = 0
        data.withUnsafeBytes { buf in
            let samples = buf.bindMemory(to: Int16.self)
            for i in 0..<frameCount {
                let s = Int16(littleEndian: samples[i])
                let abs = s == Int16.min ? Int16.max : Swift.abs(s)
                if abs > peak { peak = abs }
            }
        }
        
        guard peak > 0 else { return data }
        let scale = Double(Int16.max) / Double(peak)
        guard scale > 1.01 else { return data } // Already near max
        
        var normalized = Data(count: data.count)
        data.withUnsafeBytes { src in
            normalized.withUnsafeMutableBytes { dst in
                let srcSamples = src.bindMemory(to: Int16.self)
                let dstSamples = dst.bindMemory(to: Int16.self)
                for i in 0..<frameCount {
                    let s = Int16(littleEndian: srcSamples[i])
                    let scaled = Int16(clamping: Int(Double(s) * scale))
                    dstSamples[i] = scaled.littleEndian
                }
            }
        }
        
        return normalized
    }
    
    /// Make a filename safe for the filesystem
    static func sanitizeFilename(_ name: String) -> String {
        var safe = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|")
        safe = safe.unicodeScalars.filter { !forbidden.contains($0) }.map(String.init).joined()
        if safe.isEmpty { safe = "untitled" }
        return safe
    }

    // MARK: - Issue #2: Extract samples from bank file

    /// Audio format for extractSamples API
    enum AudioFormat: String, CaseIterable {
        case aiff = "AIFF"
        case wav  = "WAV"
    }

    /// Metadata for an exported sample file
    struct ExportedSample {
        let name: String
        let path: URL
        let sampleRate: Int
        let bitDepth: Int
        let channels: Int
        let duration: Double
    }

    /// Extract individual samples from an EMAX II bank file (.EB2 / EMX) and write as audio files.
    ///
    /// - Parameters:
    ///   - bankURL:   Path to the bank file
    ///   - outputDir: Directory to write audio files (created if it does not exist)
    ///   - format:    Output format — `.wav` or `.aiff`
    /// - Returns: Array of `ExportedSample` with metadata for each written file
    /// - Throws: `ExportError` if the file cannot be read or contains no audio
    static func extractSamples(
        from bankURL: URL,
        outputDir: URL,
        format: AudioFormat
    ) throws -> [ExportedSample] {
        let bankData = try Data(contentsOf: bankURL)
        guard bankData.count >= EmaxIIFormat.headerSize else { throw ExportError.noSampleData }

        guard let bankSamples = EmaxIIParser.extractSampleData(from: bankData) else {
            throw ExportError.noSampleData
        }
        guard !bankSamples.samples.isEmpty else { throw ExportError.noSampleData }

        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let internalFormat: ExportFormat = (format == .aiff) ? .aiff : .wav
        var results = [ExportedSample]()

        for (index, sample) in bankSamples.samples.enumerated() {
            guard !sample.pcmData.isEmpty else { continue }

            let numberedName = String(format: "%02d_%@", index + 1, sample.name)
            let sanitized = sanitizeFilename(numberedName)
            let outputURL = outputDir
                .appendingPathComponent(sanitized)
                .appendingPathExtension(internalFormat.fileExtension)

            try writePCMToFile(
                pcmData: sample.pcmData,
                sampleRate: Double(sample.sampleRate),
                to: outputURL,
                format: internalFormat
            )

            results.append(ExportedSample(
                name: sample.name,
                path: outputURL,
                sampleRate: sample.sampleRate,
                bitDepth: 16,
                channels: 1,
                duration: sample.duration
            ))
        }

        return results
    }
}
