import Foundation

/// Handles image format operations: conversion, inspection, validation
class ImageService {
    
    /// Validate that a file is a valid EMAX II image
    func validateImage(at url: URL, device: DeviceType) -> ImageValidation {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return ImageValidation(isValid: false, message: "File not found")
        }
        
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return ImageValidation(isValid: false, message: "Cannot read file attributes")
        }
        
        // EMAX II images - industry-standard format standard sizes (verified Mar 4, 2026)
        let validSizes: Set<Int64> = [
            96 * 1024 * 1024,   // ZIP 100
            239 * 1024 * 1024,  // ZIP 250
            481 * 1024 * 1024,  // HD 512
            633 * 1024 * 1024,  // CD 650
            962 * 1024 * 1024   // HD 1GB
        ]
        
        let sizeOK = size > 0 && size % 512 == 0  // Must be block-aligned
        
        return ImageValidation(
            isValid: sizeOK,
            message: sizeOK ? "Valid image (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))" : "Invalid image size (not block-aligned)",
            fileSize: size
        )
    }
    
    /// Convert .EZ2 → .hda (for EMAX II, they're identical — just rename!)
    /// NOTE: No header stripping needed. dd skip=1 is WRONG and corrupts the image.
    func convertEZ2toHDA(source: URL, destination: URL) throws {
        try FileManager.default.copyItem(at: source, to: destination)
    }
}

struct ImageValidation {
    let isValid: Bool
    let message: String
    var fileSize: Int64 = 0
}
