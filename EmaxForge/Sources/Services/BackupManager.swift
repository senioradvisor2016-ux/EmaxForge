import Foundation
import Compression

/// Manages full SD card backups and restores for ZuluSCSI volumes
class BackupManager {
    
    enum BackupError: LocalizedError {
        case volumeNotFound
        case noImagesToBackup
        case backupFailed(String)
        case restoreFailed(String)
        case invalidArchive
        case insufficientSpace
        
        var errorDescription: String? {
            switch self {
            case .volumeNotFound: return "Volume not found"
            case .noImagesToBackup: return "No images to backup"
            case .backupFailed(let msg): return "Backup failed: \(msg)"
            case .restoreFailed(let msg): return "Restore failed: \(msg)"
            case .invalidArchive: return "Invalid or corrupted backup archive"
            case .insufficientSpace: return "Insufficient space on destination volume"
            }
        }
    }
    
    struct BackupInfo: Codable {
        let timestamp: Date
        let volumeName: String
        let deviceType: String
        let imageCount: Int
        let totalSize: Int64
        let emaxForgeVersion: String
        let fileList: [String]
        
        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: timestamp)
        }
    }
    
    struct BackupResult {
        let archiveURL: URL
        let backupInfo: BackupInfo
        let compressedSize: Int64
        let compressionRatio: Double
    }
    
    struct RestoreResult {
        let restoredFiles: [String]
        let totalSize: Int64
    }
    
    // MARK: - Backup
    
    /// Create a full backup of a ZuluSCSI volume
    static func createBackup(
        volumeURL: URL,
        volumeName: String,
        deviceType: DeviceType,
        images: [DiskImage],
        destinationURL: URL,
        progressHandler: ((Double, String) -> Void)? = nil
    ) throws -> BackupResult {
        
        guard !images.isEmpty else { throw BackupError.noImagesToBackup }
        
        let fm = FileManager.default
        
        progressHandler?(0.1, "Preparing backup...")
        
        // Create temp directory for staging
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }
        
        // Copy all images to temp
        var fileList: [String] = []
        var totalSize: Int64 = 0
        
        for (index, image) in images.enumerated() {
            let progress = 0.1 + (0.4 * Double(index) / Double(images.count))
            progressHandler?(progress, "Copying \(image.filename)...")
            
            let destURL = tempDir.appendingPathComponent(image.filename)
            try fm.copyItem(at: image.url, to: destURL)
            
            fileList.append(image.filename)
            totalSize += image.fileSize
        }
        
        // Copy zuluscsi.ini if exists
        let configURL = volumeURL.appendingPathComponent("zuluscsi.ini")
        if fm.fileExists(atPath: configURL.path) {
            let destConfig = tempDir.appendingPathComponent("zuluscsi.ini")
            try fm.copyItem(at: configURL, to: destConfig)
            fileList.append("zuluscsi.ini")
        }
        
        progressHandler?(0.5, "Creating backup archive...")
        
        // Create backup info
        let backupInfo = BackupInfo(
            timestamp: Date(),
            volumeName: volumeName,
            deviceType: deviceType.rawValue,
            imageCount: images.count,
            totalSize: totalSize,
            emaxForgeVersion: "0.2",
            fileList: fileList
        )
        
        // Write backup info JSON
        let infoURL = tempDir.appendingPathComponent("backup-info.json")
        let infoData = try JSONEncoder().encode(backupInfo)
        try infoData.write(to: infoURL)
        
        progressHandler?(0.6, "Compressing archive...")
        
        // Create ZIP archive
        let archiveURL = destinationURL
        try zipDirectory(tempDir, to: archiveURL, progressHandler: { progress in
            progressHandler?(0.6 + (0.3 * progress), "Compressing...")
        })
        
        progressHandler?(0.95, "Verifying backup...")
        
        // Get compressed size
        let attrs = try fm.attributesOfItem(atPath: archiveURL.path)
        let compressedSize = attrs[.size] as? Int64 ?? 0
        let compressionRatio = Double(compressedSize) / Double(totalSize)
        
        progressHandler?(1.0, "Backup complete!")
        
        return BackupResult(
            archiveURL: archiveURL,
            backupInfo: backupInfo,
            compressedSize: compressedSize,
            compressionRatio: compressionRatio
        )
    }
    
    // MARK: - Restore
    
    /// Restore a backup archive to a volume
    static func restoreBackup(
        archiveURL: URL,
        destinationURL: URL,
        overwriteExisting: Bool = false,
        progressHandler: ((Double, String) -> Void)? = nil
    ) throws -> RestoreResult {
        
        let fm = FileManager.default
        
        guard fm.fileExists(atPath: archiveURL.path) else {
            throw BackupError.invalidArchive
        }
        
        progressHandler?(0.1, "Reading backup archive...")
        
        // Create temp directory for extraction
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }
        
        progressHandler?(0.2, "Extracting archive...")
        
        // Extract ZIP
        try unzipArchive(archiveURL, to: tempDir, progressHandler: { progress in
            progressHandler?(0.2 + (0.4 * progress), "Extracting...")
        })
        
        // Read backup info
        let infoURL = tempDir.appendingPathComponent("backup-info.json")
        guard fm.fileExists(atPath: infoURL.path) else {
            throw BackupError.invalidArchive
        }
        
        let infoData = try Data(contentsOf: infoURL)
        let backupInfo = try JSONDecoder().decode(BackupInfo.self, from: infoData)
        
        progressHandler?(0.6, "Validating backup...")
        
        // Check if files exist
        var missingFiles: [String] = []
        for filename in backupInfo.fileList {
            let fileURL = tempDir.appendingPathComponent(filename)
            if !fm.fileExists(atPath: fileURL.path) {
                missingFiles.append(filename)
            }
        }
        
        if !missingFiles.isEmpty {
            throw BackupError.restoreFailed("Missing files: \(missingFiles.joined(separator: ", "))")
        }
        
        progressHandler?(0.7, "Copying files to destination...")
        
        // Copy files to destination
        var restoredFiles: [String] = []
        var totalSize: Int64 = 0
        
        for (index, filename) in backupInfo.fileList.enumerated() {
            let progress = 0.7 + (0.25 * Double(index) / Double(backupInfo.fileList.count))
            progressHandler?(progress, "Restoring \(filename)...")
            
            let sourceURL = tempDir.appendingPathComponent(filename)
            let destURL = destinationURL.appendingPathComponent(filename)
            
            // Check if file already exists
            if fm.fileExists(atPath: destURL.path) {
                if overwriteExisting {
                    try fm.removeItem(at: destURL)
                } else {
                    continue  // Skip existing files
                }
            }
            
            try fm.copyItem(at: sourceURL, to: destURL)
            
            let attrs = try fm.attributesOfItem(atPath: destURL.path)
            let size = attrs[.size] as? Int64 ?? 0
            totalSize += size
            
            restoredFiles.append(filename)
        }
        
        progressHandler?(1.0, "Restore complete!")
        
        return RestoreResult(
            restoredFiles: restoredFiles,
            totalSize: totalSize
        )
    }
    
    // MARK: - Info
    
    /// Read backup info from an archive without extracting everything
    static func readBackupInfo(from archiveURL: URL) throws -> BackupInfo {
        let fm = FileManager.default
        
        guard fm.fileExists(atPath: archiveURL.path) else {
            throw BackupError.invalidArchive
        }
        
        // Create temp directory
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }
        
        // Extract just backup-info.json
        try unzipArchive(archiveURL, to: tempDir, progressHandler: nil)
        
        let infoURL = tempDir.appendingPathComponent("backup-info.json")
        guard fm.fileExists(atPath: infoURL.path) else {
            throw BackupError.invalidArchive
        }
        
        let infoData = try Data(contentsOf: infoURL)
        return try JSONDecoder().decode(BackupInfo.self, from: infoData)
    }
    
    // MARK: - Zip/Unzip (using system tools for simplicity)
    
    private static func zipDirectory(_ sourceURL: URL, to destinationURL: URL, progressHandler: ((Double) -> Void)?) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-q", destinationURL.path, "."]
        process.currentDirectoryURL = sourceURL
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw BackupError.backupFailed("zip command failed")
        }
        
        progressHandler?(1.0)
    }
    
    private static func unzipArchive(_ archiveURL: URL, to destinationURL: URL, progressHandler: ((Double) -> Void)?) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", "-o", archiveURL.path, "-d", destinationURL.path]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw BackupError.restoreFailed("unzip command failed")
        }
        
        progressHandler?(1.0)
    }
}
