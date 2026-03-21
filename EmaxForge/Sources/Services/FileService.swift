import Foundation

/// Handles file operations: scan, copy, rename, delete
class FileService {
    private let fm = FileManager.default
    
    /// Scan a directory for disk images matching the device type
    func scanForImages(at url: URL, device: DeviceType) -> [DiskImage] {
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        
        let validExtensions = device.imageExtensions
        
        return contents
            .filter { validExtensions.contains($0.pathExtension.lowercased()) }
            .map { DiskImage.parse(url: $0, device: device) }
            .sorted { ($0.scsiID ?? 99, $0.imageIndex ?? 0) < ($1.scsiID ?? 99, $1.imageIndex ?? 0) }
    }
    
    /// Copy an image to a destination, optionally renaming to ZuluSCSI convention
    func copyImage(_ image: DiskImage, to destinationDir: URL, scsiID: Int, imageIndex: Int?, label: String?) throws -> URL {
        let newImage = DiskImage(
            url: image.url,
            filename: image.filename,
            fileSize: image.fileSize,
            scsiID: scsiID,
            imageIndex: imageIndex,
            label: label,
            deviceType: image.deviceType
        )
        
        let destURL = destinationDir.appendingPathComponent(newImage.zuluSCSIName)
        try fm.copyItem(at: image.url, to: destURL)
        return destURL
    }
    
    /// Rename an image file (ZuluSCSI convention)
    func renameImage(_ image: DiskImage, scsiID: Int, imageIndex: Int?, label: String?) throws -> URL {
        let dir = image.url.deletingLastPathComponent()
        let renamed = DiskImage(
            url: image.url,
            filename: image.filename,
            fileSize: image.fileSize,
            scsiID: scsiID,
            imageIndex: imageIndex,
            label: label,
            deviceType: image.deviceType
        )
        let newURL = dir.appendingPathComponent(renamed.zuluSCSIName)
        try fm.moveItem(at: image.url, to: newURL)
        return newURL
    }
    
    /// Delete an image (moves to Trash)
    func trashImage(_ image: DiskImage) throws {
        try fm.trashItem(at: image.url, resultingItemURL: nil)
    }
    
    /// Create an empty image of given size
    func createEmptyImage(at dir: URL, scsiID: Int, imageIndex: Int?, label: String?, sizeMB: Int, device: DeviceType) throws -> URL {
        let image = DiskImage(
            url: dir, // temporary
            filename: "",
            fileSize: Int64(sizeMB) * 1024 * 1024,
            scsiID: scsiID,
            imageIndex: imageIndex,
            label: label,
            deviceType: device
        )
        
        let destURL = dir.appendingPathComponent(image.zuluSCSIName)
        
        // Create empty file of specified size
        fm.createFile(atPath: destURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: destURL)
        try handle.truncate(atOffset: UInt64(sizeMB) * 1024 * 1024)
        handle.closeFile()
        
        return destURL
    }
}
