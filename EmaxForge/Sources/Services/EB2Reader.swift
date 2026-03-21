import Foundation

/// Reads standard tools .EB2 bank files
/// DISCOVERY: .EB2 files are identical to raw disk cluster data (no compression!)
class EB2Reader {
    
    enum EB2Error: Error, LocalizedError {
        case invalidEB2File
        case fileTooSmall
        
        var errorDescription: String? {
            switch self {
            case .invalidEB2File:
                return "Invalid .EB2 file format"
            case .fileTooSmall:
                return "EB2 file too small (< 64 bytes)"
            }
        }
    }
    
    /// Read .EB2 file and return raw bank data
    /// - Parameter url: Path to .EB2 file
    /// - Returns: Raw bank data (identical to disk cluster data)
    static func readEB2(url: URL) throws -> Data {
        let data = try Data(contentsOf: url)
        
        // Validate minimum size
        guard data.count >= 64 else {
            throw EB2Error.fileTooSmall
        }
        
        // .EB2 = raw cluster data, no header, no compression!
        // File structure: Bank header (64 bytes) + Voice data + Sample data
        return data
    }
    
    /// Parse bank header from .EB2 data
    /// - Parameter data: Raw .EB2 data
    /// - Returns: Bank metadata
    static func parseBankHeader(data: Data) -> BankHeader? {
        guard data.count >= 64 else { return nil }
        
        // Bank header structure (first 64 bytes of cluster data)
        // This is EMAX-II native format, not standard tools-specific!
        
        var nameBytes = [UInt8](repeating: 0, count: 16)
        data.copyBytes(to: &nameBytes, from: 0..<16)
        
        guard let name = String(bytes: nameBytes, encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .whitespaces),
              !name.isEmpty else {
            return nil
        }
        
        return BankHeader(
            name: name,
            dataSize: data.count,
            // clusterCount is only an estimate here — actual value depends on disk geometry
            // BankImporter calculates the correct count from geo.clusterSize
            clusterCount: (data.count + 489471) / 489472
        )
    }
    
    /// Check if file is likely a valid .EB2
    /// - Parameter url: File to check
    /// - Returns: true if file appears to be .EB2
    static func isValidEB2(url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped) else {
            return false
        }
        
        // Quick validation: check for ASCII bank name in first 16 bytes
        guard data.count >= 16 else { return false }
        
        let nameBytes = data.prefix(16)
        guard let name = String(data: nameBytes, encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .whitespaces) else {
            return false
        }
        
        // Must have at least 1 printable character
        return !name.isEmpty && name.contains(where: { $0.isLetter || $0.isNumber })
    }
}

struct BankHeader {
    let name: String
    let dataSize: Int
    let clusterCount: Int
}
