import Foundation

/// Service for trimming silence from samples
actor SampleTrimmerService {
    
    enum TrimError: LocalizedError {
        case scriptNotFound
        case scriptFailed(String)
        case invalidOutput
        
        var errorDescription: String? {
            switch self {
            case .scriptNotFound:
                return "cli-trim-sample.swift not found"
            case .scriptFailed(let msg):
                return "Trim failed: \(msg)"
            case .invalidOutput:
                return "Invalid trim output"
            }
        }
    }
    
    /// Trim silence from a WAV file
    /// - Parameters:
    ///   - inputURL: Input WAV file
    ///   - outputURL: Output WAV file (optional, defaults to input_trimmed.wav)
    ///   - threshold: Silence threshold 0-255 (default: 5)
    ///   - dryRun: Preview trim points without writing
    /// - Returns: Trim result with statistics
    func trimSample(
        input inputURL: URL,
        output outputURL: URL? = nil,
        threshold: Int = 5,
        dryRun: Bool = false
    ) async throws -> TrimResult {
        
        let scriptPath = findCLIScript()
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            throw TrimError.scriptNotFound
        }
        
        let actualOutput = outputURL ?? inputURL.deletingPathExtension()
            .appendingPathExtension("trimmed.wav")
        
        // Run cli-trim-sample.swift
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        
        var args = [
            scriptPath,
            "--input", inputURL.path,
            "--output", actualOutput.path,
            "--threshold", "\(threshold)"
        ]
        
        if dryRun {
            args.append("--dry-run")
        }
        
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TrimError.scriptFailed(output)
        }
        
        // Parse JSON output
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        guard let json = parseJSONOutput(output) else {
            throw TrimError.invalidOutput
        }
        
        return try parseTrimResult(json, outputURL: actualOutput, dryRun: dryRun)
    }
    
    /// Parse trim result from JSON
    private func parseTrimResult(
        _ json: [String: Any],
        outputURL: URL,
        dryRun: Bool
    ) throws -> TrimResult {
        
        guard let original = json["original"] as? [String: Any],
              let trimmed = json["trimmed"] as? [String: Any],
              let trim = json["trim"] as? [String: Any] else {
            throw TrimError.invalidOutput
        }
        
        return TrimResult(
            outputURL: outputURL,
            originalSamples: original["samples"] as? Int ?? 0,
            originalDuration: original["duration"] as? Double ?? 0,
            originalSize: original["size"] as? Int ?? 0,
            trimmedSamples: trimmed["samples"] as? Int ?? 0,
            trimmedDuration: trimmed["duration"] as? Double ?? 0,
            trimmedSize: trimmed["size"] as? Int ?? 0,
            trimStart: trim["start"] as? Int ?? 0,
            trimEnd: trim["end"] as? Int ?? 0,
            removedStart: trim["removedStart"] as? Int ?? 0,
            removedEnd: trim["removedEnd"] as? Int ?? 0,
            savingsPercent: trim["savingsPercent"] as? Double ?? 0,
            dryRun: dryRun
        )
    }
    
    /// Find CLI script location
    private func findCLIScript() -> String {
        let candidates = [
            FileManager.default.currentDirectoryPath + "/cli-trim-sample.swift",
            FileManager.default.currentDirectoryPath + "/../cli-trim-sample.swift",
            FileManager.default.homeDirectoryForCurrentUser.path + "/clawd/EmaxForge/cli-trim-sample.swift"
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
    
    struct TrimResult {
        let outputURL: URL
        let originalSamples: Int
        let originalDuration: Double
        let originalSize: Int
        let trimmedSamples: Int
        let trimmedDuration: Double
        let trimmedSize: Int
        let trimStart: Int
        let trimEnd: Int
        let removedStart: Int
        let removedEnd: Int
        let savingsPercent: Double
        let dryRun: Bool
        
        var formattedSavings: String {
            String(format: "%.1f%%", savingsPercent)
        }
        
        var formattedOriginalSize: String {
            formatBytes(originalSize)
        }
        
        var formattedTrimmedSize: String {
            formatBytes(trimmedSize)
        }
        
        private func formatBytes(_ bytes: Int) -> String {
            let kb = Double(bytes) / 1024.0
            return String(format: "%.1f KB", kb)
        }
        
        var summary: String {
            if dryRun {
                return "Would remove \(removedStart + removedEnd) samples (\(formattedSavings))"
            } else {
                return "Removed \(removedStart + removedEnd) samples (\(formattedSavings) savings)"
            }
        }
    }
}
