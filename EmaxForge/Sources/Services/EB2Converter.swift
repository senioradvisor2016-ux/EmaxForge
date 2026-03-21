import Foundation

/// Convert .EB2 files to native EMAX II format using standard tools via Wine/Whisky
class EB2Converter {
    
    enum ConversionError: Error, LocalizedError {
        case standardNotFound
        case wineNotFound
        case conversionFailed(String)
        case extractionFailed
        
        var errorDescription: String? {
            switch self {
            case .standardNotFound:
                return "standard tools (standardn.exe) not found. Please install standard tools in ~/clawd/standard/"
            case .wineNotFound:
                return "Wine/Whisky not found. Please install Whisky from https://getwhisky.app"
            case .conversionFailed(let msg):
                return "Conversion failed: \(msg)"
            case .extractionFailed:
                return "Failed to extract converted bank data"
            }
        }
    }
    
    private static let cacheDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".emaxforge")
        .appendingPathComponent("bank_cache")
    
    private static let standardPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("clawd")
        .appendingPathComponent("standard")
        .appendingPathComponent("standardn.exe")
    
    /// Convert .EB2 file to native format (with caching)
    static func convertToNative(eb2URL: URL, progress: @escaping (String) -> Void) throws -> Data {
        // Check cache first
        let cacheKey = try cacheKeyForFile(eb2URL)
        let cachedURL = cacheDir.appendingPathComponent("\(cacheKey).raw")
        
        if FileManager.default.fileExists(atPath: cachedURL.path) {
            progress("Using cached conversion...")
            return try Data(contentsOf: cachedURL)
        }
        
        // Ensure cache directory exists
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        // Verify standard tools exists
        guard FileManager.default.fileExists(atPath: standardPath.path) else {
            throw ConversionError.standardNotFound
        }
        
        progress("Converting \(eb2URL.lastPathComponent) via reference tools...")
        
        // Create temp workspace
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let tempDiskURL = tempDir.appendingPathComponent("temp_disk.EZ2")
        
        // Copy standard tools and bank to temp dir (Wine needs files in same directory)
        let tempEmxpURL = tempDir.appendingPathComponent("standardn.exe")
        let tempBankURL = tempDir.appendingPathComponent(eb2URL.lastPathComponent)
        
        try FileManager.default.copyItem(at: standardPath, to: tempEmxpURL)
        try FileManager.default.copyItem(at: eb2URL, to: tempBankURL)
        
        // Step 1: Create empty 239MB disk
        progress("Creating temporary disk...")
        let createResult = try runWineCommand(
            executable: tempEmxpURL.path,
            args: ["/CREATE", "239", tempDiskURL.path],
            workingDir: tempDir.path
        )
        
        guard createResult.success else {
            throw ConversionError.conversionFailed("Failed to create disk: \(createResult.error)")
        }
        
        // Step 2: Import bank into disk
        progress("Importing bank...")
        let importResult = try runWineCommand(
            executable: tempEmxpURL.path,
            args: ["/IMPORT", tempDiskURL.path, tempBankURL.path],
            workingDir: tempDir.path
        )
        
        guard importResult.success else {
            throw ConversionError.conversionFailed("Failed to import: \(importResult.error)")
        }
        
        // Step 3: Extract bank from disk
        progress("Extracting native format...")
        guard let bankData = try? extractFirstBankFromDisk(tempDiskURL) else {
            throw ConversionError.extractionFailed
        }
        
        // Cache the result
        try bankData.write(to: cachedURL)
        progress("✅ Conversion complete (cached for future use)")
        
        return bankData
    }
    
    /// Extract first bank from disk (after standard tools import)
    private static func extractFirstBankFromDisk(_ diskURL: URL) throws -> Data? {
        let banks = try BankExtractor.extractAllBanks(from: diskURL)
        return banks.first?.data
    }
    
    /// Generate cache key from file content (MD5 hash)
    private static func cacheKeyForFile(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        
        // Simple hash (MD5-style)
        var hash = 0
        for byte in data.prefix(8192) {  // Hash first 8KB for speed
            hash = (hash &* 31) &+ Int(byte)
        }
        
        return String(format: "%016x", hash)
    }
    
    /// Run Wine command and capture output
    private static func runWineCommand(
        executable: String,
        args: [String],
        workingDir: String
    ) throws -> (success: Bool, output: String, error: String) {
        
        // Try Whisky's wine binary first
        let whiskyCasks = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers")
        
        var winePath: String?
        
        // Search for Whisky wine installations
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: whiskyCasks.path) {
            for item in contents where item.contains("com.isaacmarovitz.Whisky") {
                let potentialWine = whiskyCasks
                    .appendingPathComponent(item)
                    .appendingPathComponent("Bottles")
                
                // Use first available bottle
                if let bottles = try? FileManager.default.contentsOfDirectory(atPath: potentialWine.path),
                   let firstBottle = bottles.first {
                    winePath = potentialWine
                        .appendingPathComponent(firstBottle)
                        .appendingPathComponent("drive_c/windows/system32/wine.exe")
                        .path
                    break
                }
            }
        }
        
        // Fallback: system wine
        if winePath == nil {
            winePath = "/usr/local/bin/wine"
        }
        
        guard let wine = winePath, FileManager.default.fileExists(atPath: wine) else {
            throw ConversionError.wineNotFound
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: wine)
        process.arguments = [executable] + args
        process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        return (
            success: process.terminationStatus == 0,
            output: output,
            error: error
        )
    }
}
