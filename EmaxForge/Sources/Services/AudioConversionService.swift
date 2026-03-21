import Foundation

/// Audio conversion service using CLI-Anything backend
class AudioConversionService {
    
    enum ConversionError: LocalizedError {
        case conversionFailed(String)
        case invalidInput
        case cliNotFound
        
        var errorDescription: String? {
            switch self {
            case .conversionFailed(let msg): return "Conversion failed: \(msg)"
            case .invalidInput: return "Invalid input file"
            case .cliNotFound: return "CLI tool not found"
            }
        }
    }
    
    struct ConversionOptions {
        var targetRate: Int = 42000  // EMAX II standard
        var convertToMono: Bool = true
        var normalize: Bool = true
        
        static let emaxStandard = ConversionOptions()
    }
    
    struct ConversionResult {
        let inputPath: String
        let outputPath: String
        let inputRate: Int
        let outputRate: Int
        let channels: Int
        let frames: Int
    }
    
    /// Convert audio file to EMAX II compatible format
    func convertAudio(
        inputURL: URL,
        outputURL: URL,
        options: ConversionOptions = .emaxStandard
    ) async throws -> ConversionResult {
        
        // Find CLI tool
        let cliPath = findCLIPath()
        guard FileManager.default.fileExists(atPath: cliPath) else {
            throw ConversionError.cliNotFound
        }
        
        // Build arguments
        var args = [
            "convert-audio",
            inputURL.path,
            outputURL.path,
            "--rate", "\(options.targetRate)",
            "--json"
        ]
        
        if options.convertToMono {
            args.append("--mono")
        }
        
        if options.normalize {
            args.append("--normalize")
        }
        
        // Execute
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = args
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ConversionError.conversionFailed(errorMsg)
        }
        
        // Parse JSON output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        
        guard let json = try? JSONSerialization.jsonObject(with: outputData) as? [String: Any],
              let success = json["success"] as? Bool, success,
              let input = json["input"] as? String,
              let output = json["output"] as? String,
              let inputRate = json["input_rate"] as? Int,
              let outputRate = json["output_rate"] as? Int,
              let channels = json["channels"] as? Int,
              let frames = json["frames"] as? Int
        else {
            throw ConversionError.conversionFailed("Invalid JSON response")
        }
        
        return ConversionResult(
            inputPath: input,
            outputPath: output,
            inputRate: inputRate,
            outputRate: outputRate,
            channels: channels,
            frames: frames
        )
    }
    
    /// Batch convert multiple audio files
    func batchConvert(
        files: [URL],
        outputDirectory: URL,
        options: ConversionOptions = .emaxStandard,
        progress: @escaping (Int, Int) -> Void
    ) async throws -> [ConversionResult] {
        
        var results: [ConversionResult] = []
        
        for (index, file) in files.enumerated() {
            let outputURL = outputDirectory
                .appendingPathComponent(file.deletingPathExtension().lastPathComponent)
                .appendingPathExtension("wav")
            
            let result = try await convertAudio(
                inputURL: file,
                outputURL: outputURL,
                options: options
            )
            
            results.append(result)
            progress(index + 1, files.count)
        }
        
        return results
    }
    
    // MARK: - Private
    
    private func findCLIPath() -> String {
        let paths = [
            "/usr/local/bin/cli-anything-emaxforge",
            "\(NSHomeDirectory())/bin/cli-anything-emaxforge",
            "\(NSHomeDirectory())/.local/bin/cli-anything-emaxforge"
        ]
        
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return "/usr/local/bin/cli-anything-emaxforge"  // Default
    }
}
