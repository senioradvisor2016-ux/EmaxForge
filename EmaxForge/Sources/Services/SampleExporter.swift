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

    /// Export a single sample entry to WAV or AIFF.
    ///
    /// - Parameters:
    ///   - sample: The sample to export.
    ///   - directory: Destination directory URL.
    ///   - format: Audio format (.wav / .aiff).
    ///   - normalize: Maximize amplitude before writing.
    ///   - filenameTemplate: Optional naming template (default: just the sample name).
    ///   - bankName: Bank name for template variables (default: empty).
    ///   - sampleIndex: 1-based sample index for `{index}` variable (default: 1).
    ///   - bankIndex: 1-based bank index on disk for `{bankindex}` variable (default: 1).
    static func exportSample(
        _ sample: BankSampleData.SampleEntry,
        to directory: URL,
        format: ExportFormat = .wav,
        normalize: Bool = false,
        filenameTemplate: SampleFilenameTemplate = .default,
        bankName: String = "",
        sampleIndex: Int = 1,
        bankIndex: Int = 1
    ) throws -> ExportResult {
        guard !sample.pcmData.isEmpty else { throw ExportError.noSampleData }

        let context = SampleFilenameTemplate.Context(
            bankName: bankName.isEmpty ? "UNKNOWN" : bankName,
            sampleName: sample.name,
            sampleIndex: sampleIndex,
            bankIndex: bankIndex,
            date: Date(),
            rootKey: sample.rootKey
        )
        let resolvedName = filenameTemplate.resolve(context: context)
        let outputURL = directory
            .appendingPathComponent(resolvedName)
            .appendingPathExtension(format.fileExtension)
        
        var pcmData = sample.pcmData
        if normalize {
            pcmData = normalizePCM(pcmData)
        }

        try writePCMToFile(
            pcmData: pcmData,
            sampleRate: Double(sample.sampleRate),
            to: outputURL,
            format: format,
            loopStart: sample.loopStart,
            loopEnd: sample.loopEnd,
            rootKey: sample.rootKey
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

    /// Export all samples from a bank to a directory.
    ///
    /// - Parameters:
    ///   - bankSamples:      Sample data parsed from the bank.
    ///   - bankName:         Bank name used for the subfolder and template variable `{bank}`.
    ///   - baseDirectory:    Root destination directory.
    ///   - format:           Audio format (.wav / .aiff).
    ///   - normalize:        Maximize amplitude before writing.
    ///   - createSubfolder:  When `true`, creates `<bankName>/` under `baseDirectory`.
    ///   - filenameTemplate: Naming template for each sample file (default: `{sample}`).
    ///   - bankIndex:        1-based bank index on the disk (for `{bankindex}` variable).
    static func exportAllSamples(
        from bankSamples: BankSampleData,
        bankName: String,
        to baseDirectory: URL,
        format: ExportFormat = .wav,
        normalize: Bool = false,
        createSubfolder: Bool = true,
        filenameTemplate: SampleFilenameTemplate = .default,
        bankIndex: Int = 1
    ) throws -> [ExportResult] {
        let outputDir: URL
        if createSubfolder {
            let folderName = sanitizeFilename(bankName)
            outputDir = baseDirectory.appendingPathComponent(folderName)
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        } else {
            outputDir = baseDirectory
        }

        let exportDate = Date()
        var results = [ExportResult]()

        for (index, sample) in bankSamples.samples.enumerated() {
            let context = SampleFilenameTemplate.Context(
                bankName: bankName.isEmpty ? "UNKNOWN" : bankName,
                sampleName: sample.name,
                sampleIndex: index + 1,
                bankIndex: bankIndex,
                date: exportDate,
                rootKey: sample.rootKey
            )
            let resolvedName = filenameTemplate.resolve(context: context)
            let outputURL = outputDir
                .appendingPathComponent(resolvedName)
                .appendingPathExtension(format.fileExtension)

            var pcmData = sample.pcmData
            if normalize { pcmData = normalizePCM(pcmData) }

            try writePCMToFile(
                pcmData: pcmData,
                sampleRate: Double(sample.sampleRate),
                to: outputURL,
                format: format,
                loopStart: sample.loopStart,
                loopEnd: sample.loopEnd,
                rootKey: sample.rootKey
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

    /// Write 16-bit LE PCM data to a WAV or AIFF file.
    ///
    /// For WAV output, if `loopStart` and `loopEnd` are provided a `smpl` chunk is appended
    /// so that the loop points round-trip through any sampler that reads standard WAV metadata.
    private static func writePCMToFile(
        pcmData: Data,
        sampleRate: Double,
        to url: URL,
        format: ExportFormat,
        loopStart: Int? = nil,
        loopEnd: Int? = nil,
        rootKey: Int = 60
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
        
        // Write data, then close before we patch in the smpl chunk
        if format == .wav {
            // WAV uses little-endian 16-bit — our data is already LE
            var numBytes = UInt32(pcmData.count)
            let writeStatus = pcmData.withUnsafeBytes { rawBuf in
                AudioFileWriteBytes(file, false, 0, &numBytes, rawBuf.baseAddress!)
            }
            AudioFileClose(file)
            guard writeStatus == noErr else {
                throw ExportError.writeFailed("AudioFileWriteBytes failed: \(writeStatus)")
            }
            // Append smpl chunk so loop points survive into any sampler that reads WAV metadata
            if let ls = loopStart, let le = loopEnd, ls < le {
                appendSmplChunkToWAV(at: url, rootKey: rootKey, loopStart: ls, loopEnd: le,
                                     sampleRate: UInt32(sampleRate))
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
            AudioFileClose(file)
            guard writeStatus == noErr else {
                throw ExportError.writeFailed("AudioFileWriteBytes failed: \(writeStatus)")
            }
        }
    }

    /// Append a `smpl` chunk to an existing WAV file and update the RIFF size field.
    ///
    /// The smpl chunk encodes the MIDI root key and a single forward loop so that
    /// DAWs and samplers can reconstruct the loop after round-tripping through WAV.
    private static func appendSmplChunkToWAV(
        at url: URL,
        rootKey: Int,
        loopStart: Int,
        loopEnd: Int,
        sampleRate: UInt32
    ) {
        guard var wavData = try? Data(contentsOf: url) else { return }

        // Build smpl chunk body (36 header bytes + 24 loop bytes = 60 bytes)
        func le32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }

        var body = Data()
        body += le32(0)                          // manufacturer
        body += le32(0)                          // product
        body += le32(sampleRate > 0 ? 1_000_000_000 / sampleRate : 0)  // sample period (ns)
        body += le32(UInt32(max(0, min(127, rootKey))))  // MIDI unity note
        body += le32(0)                          // MIDI pitch fraction
        body += le32(0)                          // SMPTE format
        body += le32(0)                          // SMPTE offset
        body += le32(1)                          // num sample loops
        body += le32(0)                          // sampler data bytes
        // Loop 0
        body += le32(0)                          // cue point ID
        body += le32(0)                          // type (0 = forward)
        body += le32(UInt32(loopStart))          // start sample frame
        body += le32(UInt32(loopEnd))            // end sample frame
        body += le32(0)                          // fraction
        body += le32(0)                          // play count (0 = infinite)

        var smplChunk = Data()
        smplChunk += "smpl".data(using: .ascii)!
        smplChunk += le32(UInt32(body.count))
        smplChunk += body

        wavData += smplChunk

        // Update RIFF size at bytes 4–7 (total file size minus the "RIFF" tag + size field = size - 8)
        let newRIFFSize = UInt32(wavData.count - 8)
        wavData.withUnsafeMutableBytes { ptr in
            ptr.storeBytes(of: newRIFFSize.littleEndian, toByteOffset: 4, as: UInt32.self)
        }

        try? wavData.write(to: url)
    }
    
    // MARK: - Raw PCM Export (used by SampleBrowserView)

    /// Export raw 16-bit LE PCM data directly to a WAV or AIFF file.
    /// Suitable for single-sample export from contexts that already hold PCM bytes
    /// (e.g. `SampleInfo.pcmData`) without needing a full `BankSampleData.SampleEntry`.
    static func exportPCMData(
        _ pcmData: Data,
        name: String,
        sampleRate: Double,
        to url: URL,
        format: ExportFormat = .wav
    ) throws {
        guard !pcmData.isEmpty else { throw ExportError.noSampleData }
        try writePCMToFile(pcmData: pcmData, sampleRate: sampleRate, to: url, format: format)
    }

    // MARK: - Stereo file creation (EMXP: "Create a STEREO file from the...")

    /// Interleave two mono 16-bit LE PCM buffers into a stereo PCM buffer.
    ///
    /// The EMAX II hardware produces mono samples. This function combines a left-channel and
    /// right-channel sample into a single interleaved stereo buffer: L₀ R₀ L₁ R₁ …
    /// If the buffers differ in length the shorter one is zero-padded.
    ///
    /// - Parameters:
    ///   - leftPCM:  Raw 16-bit LE mono PCM (left channel)
    ///   - rightPCM: Raw 16-bit LE mono PCM (right channel)
    /// - Returns: Interleaved stereo PCM (2 × max(len(L), len(R)) bytes)
    static func interleaveToStereo(leftPCM: Data, rightPCM: Data) -> Data {
        let leftFrames  = leftPCM.count  / 2
        let rightFrames = rightPCM.count / 2
        let frameCount  = max(leftFrames, rightFrames)
        var result = Data(count: frameCount * 4)  // 2 channels × 2 bytes

        result.withUnsafeMutableBytes { dst in
            let dstPtr = dst.bindMemory(to: UInt16.self)
            leftPCM.withUnsafeBytes { lSrc in
                let lPtr = lSrc.bindMemory(to: UInt16.self)
                rightPCM.withUnsafeBytes { rSrc in
                    let rPtr = rSrc.bindMemory(to: UInt16.self)
                    for i in 0..<frameCount {
                        dstPtr[i * 2]     = i < leftFrames  ? lPtr[i] : 0
                        dstPtr[i * 2 + 1] = i < rightFrames ? rPtr[i] : 0
                    }
                }
            }
        }
        return result
    }

    /// Create a stereo WAV or AIFF file by merging two mono samples.
    ///
    /// Matches EMXP's "Create a STEREO file from the…" feature. Both samples should
    /// share the same sample rate; if they differ, `leftSampleRate` is used and the
    /// caller is responsible for rate-matching beforehand.
    ///
    /// - Parameters:
    ///   - leftPCM:        Mono 16-bit LE PCM for the left channel
    ///   - rightPCM:       Mono 16-bit LE PCM for the right channel
    ///   - leftSampleRate: Sample rate of the left channel (used for the output file)
    ///   - outputURL:      Destination file URL
    ///   - format:         Output format (.wav / .aiff)
    static func createStereoFile(
        leftPCM: Data,
        rightPCM: Data,
        sampleRate: Double,
        to outputURL: URL,
        format: ExportFormat = .wav
    ) throws {
        guard !leftPCM.isEmpty || !rightPCM.isEmpty else { throw ExportError.noSampleData }
        let stereoPCM = interleaveToStereo(leftPCM: leftPCM, rightPCM: rightPCM)
        try writeStereoToFile(pcmData: stereoPCM, sampleRate: sampleRate, to: outputURL, format: format)
    }

    /// Write interleaved stereo 16-bit LE PCM to a WAV or AIFF file.
    private static func writeStereoToFile(
        pcmData: Data,
        sampleRate: Double,
        to url: URL,
        format: ExportFormat
    ) throws {
        let frameCount = pcmData.count / 4  // 2 channels × 2 bytes per channel
        guard frameCount > 0 else { throw ExportError.noSampleData }

        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: format == .wav
                ? (kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked)
                : (kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagIsBigEndian),
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 16,
            mReserved: 0
        )

        var audioFile: AudioFileID?
        let createStatus = AudioFileCreateWithURL(url as CFURL, format.fileType, &asbd, .eraseFile, &audioFile)
        guard createStatus == noErr, let file = audioFile else { throw ExportError.createFileFailed }
        defer { AudioFileClose(file) }

        let writeData: Data
        if format == .aiff {
            // AIFF: byte-swap each 16-bit word
            var beData = Data(count: pcmData.count)
            pcmData.withUnsafeBytes { src in
                beData.withUnsafeMutableBytes { dst in
                    let s = src.bindMemory(to: UInt8.self)
                    let d = dst.bindMemory(to: UInt8.self)
                    for i in stride(from: 0, to: pcmData.count - 1, by: 2) {
                        d[i] = s[i + 1]; d[i + 1] = s[i]
                    }
                }
            }
            writeData = beData
        } else {
            writeData = pcmData  // WAV is already LE
        }

        var numBytes = UInt32(writeData.count)
        let writeStatus = writeData.withUnsafeBytes { rawBuf in
            AudioFileWriteBytes(file, false, 0, &numBytes, rawBuf.baseAddress!)
        }
        guard writeStatus == noErr else {
            throw ExportError.writeFailed("AudioFileWriteBytes failed: \(writeStatus)")
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
                format: internalFormat,
                loopStart: sample.loopStart,
                loopEnd: sample.loopEnd,
                rootKey: sample.rootKey
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
