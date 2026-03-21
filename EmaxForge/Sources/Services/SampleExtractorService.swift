import Foundation
import AppKit

/// Service for extracting samples from banks as WAV files
actor SampleExtractorService {
    
    enum ExtractError: LocalizedError {
        case scriptNotFound
        case scriptFailed(String)
        case invalidOutput
        
        var errorDescription: String? {
            switch self {
            case .scriptNotFound:
                return "cli-extract-sample.swift not found"
            case .scriptFailed(let msg):
                return "Extraction failed: \(msg)"
            case .invalidOutput:
                return "Invalid extraction output"
            }
        }
    }
    
    /// Extract a single sample to WAV file
    /// - Parameters:
    ///   - sample: Sample data to extract
    ///   - outputURL: Where to save the WAV file
    ///   - bankURL: Path to source bank file (for .EB2 extraction)
    /// - Returns: Extraction result with file size and duration
    func extractSample(
        _ sample: BankSampleData.SampleEntry,
        to outputURL: URL,
        from bankURL: URL? = nil
    ) async throws -> ExtractionResult {
        
        // If we have PCM data already, write directly
        if !sample.pcmData.isEmpty {
            return try await extractFromPCM(sample, to: outputURL)
        }
        
        // Otherwise use CLI tool on .EB2 file
        guard let bankURL = bankURL else {
            throw ExtractError.scriptFailed("No PCM data or bank URL provided")
        }
        
        return try await extractFromBank(sample, bankURL: bankURL, to: outputURL)
    }
    
    /// Extract sample from in-memory PCM data
    private func extractFromPCM(
        _ sample: BankSampleData.SampleEntry,
        to outputURL: URL
    ) async throws -> ExtractionResult {
        
        // Build WAV file
        let wavData = buildWAVFile(
            pcmData: sample.pcmData,
            sampleRate: UInt32(sample.sampleRate),
            bitsPerSample: 16
        )
        
        try wavData.write(to: outputURL)
        
        return ExtractionResult(
            outputURL: outputURL,
            sampleRate: sample.sampleRate,
            duration: sample.duration,
            fileSize: wavData.count
        )
    }
    
    /// Extract sample using CLI tool
    private func extractFromBank(
        _ sample: BankSampleData.SampleEntry,
        bankURL: URL,
        to outputURL: URL
    ) async throws -> ExtractionResult {
        
        let scriptPath = findCLIScript()
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            throw ExtractError.scriptNotFound
        }
        
        // Run cli-extract-sample.swift
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = [
            scriptPath,
            "--bank", bankURL.path,
            "--output", outputURL.path,
            "--rate", "\(sample.sampleRate)",
            "--length", "\(sample.pcmData.count)"
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ExtractError.scriptFailed(output)
        }
        
        // Parse JSON output
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if let json = parseJSONOutput(output) {
            return ExtractionResult(
                outputURL: outputURL,
                sampleRate: json["rate"] as? Int ?? sample.sampleRate,
                duration: json["duration"] as? Double ?? sample.duration,
                fileSize: json["length"] as? Int ?? sample.pcmData.count
            )
        }
        
        // Fallback: file exists, return basic info
        if FileManager.default.fileExists(atPath: outputURL.path) {
            let attrs = try FileManager.default.attributesOfItem(atPath: outputURL.path)
            let size = attrs[.size] as? Int ?? 0
            
            return ExtractionResult(
                outputURL: outputURL,
                sampleRate: sample.sampleRate,
                duration: sample.duration,
                fileSize: size
            )
        }
        
        throw ExtractError.invalidOutput
    }
    
    /// Build WAV file from PCM data
    private func buildWAVFile(
        pcmData: Data,
        sampleRate: UInt32,
        bitsPerSample: UInt16
    ) -> Data {
        
        var wav = Data()
        
        // Convert 8-bit to 16-bit if needed
        let samples16bit: Data
        if bitsPerSample == 8 {
            var converted = Data()
            for byte in pcmData {
                let signed8 = Int8(bitPattern: byte)
                let signed16 = Int16(signed8) * 256
                var value = UInt16(bitPattern: signed16)
                withUnsafeBytes(of: &value) { converted.append(contentsOf: $0) }
            }
            samples16bit = converted
        } else {
            samples16bit = pcmData
        }
        
        let dataSize = UInt32(samples16bit.count)
        let numChannels: UInt16 = 1
        let bytesPerSample: UInt16 = 2
        let byteRate = sampleRate * UInt32(numChannels) * UInt32(bytesPerSample)
        let blockAlign = numChannels * bytesPerSample
        
        // RIFF header
        wav.append("RIFF".data(using: .ascii)!)
        var chunkSize = UInt32(36 + dataSize)
        withUnsafeBytes(of: &chunkSize) { wav.append(contentsOf: $0) }
        wav.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        wav.append("fmt ".data(using: .ascii)!)
        var fmtSize = UInt32(16)
        withUnsafeBytes(of: &fmtSize) { wav.append(contentsOf: $0) }
        var audioFormat: UInt16 = 1  // PCM
        withUnsafeBytes(of: &audioFormat) { wav.append(contentsOf: $0) }
        var channels = numChannels
        withUnsafeBytes(of: &channels) { wav.append(contentsOf: $0) }
        var rate = sampleRate
        withUnsafeBytes(of: &rate) { wav.append(contentsOf: $0) }
        var brate = byteRate
        withUnsafeBytes(of: &brate) { wav.append(contentsOf: $0) }
        var align = blockAlign
        withUnsafeBytes(of: &align) { wav.append(contentsOf: $0) }
        var bits: UInt16 = 16
        withUnsafeBytes(of: &bits) { wav.append(contentsOf: $0) }
        
        // data chunk
        wav.append("data".data(using: .ascii)!)
        var size = dataSize
        withUnsafeBytes(of: &size) { wav.append(contentsOf: $0) }
        wav.append(samples16bit)
        
        return wav
    }
    
    /// Find CLI script location
    private func findCLIScript() -> String {
        // Try common locations
        let candidates = [
            // Workspace root
            FileManager.default.currentDirectoryPath + "/cli-extract-sample.swift",
            // Parent directory
            FileManager.default.currentDirectoryPath + "/../cli-extract-sample.swift",
            // EmaxForge directory
            FileManager.default.homeDirectoryForCurrentUser.path + "/clawd/EmaxForge/cli-extract-sample.swift"
        ]
        
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return candidates.last!
    }
    
    /// Parse JSON output from CLI tool
    private func parseJSONOutput(_ output: String) -> [String: Any]? {
        guard let startRange = output.range(of: "JSON_OUTPUT_START"),
              let endRange = output.range(of: "JSON_OUTPUT_END") else {
            return nil
        }
        
        let jsonStart = output.index(after: startRange.upperBound)
        let jsonEnd = endRange.lowerBound
        let jsonString = String(output[jsonStart..<jsonEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        return json
    }
    
    // MARK: - Result
    
    struct ExtractionResult {
        let outputURL: URL
        let sampleRate: Int
        let duration: Double
        let fileSize: Int
        
        var formattedSize: String {
            let kb = Double(fileSize) / 1024.0
            return String(format: "%.1f KB", kb)
        }
        
        var formattedDuration: String {
            String(format: "%.2f s", duration)
        }
    }
}
