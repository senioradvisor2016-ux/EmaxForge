import Foundation

/// Convert various E-mu and sample formats to EMAX II .EB2 banks
class FormatConverter {
    
    enum FormatError: LocalizedError {
        case unsupported(String)
        case invalidData(String)
        case hfeParseError(String)
        
        var errorDescription: String? {
            switch self {
            case .unsupported(let f): return "Unsupported format: \(f)"
            case .invalidData(let msg): return "Invalid data: \(msg)"
            case .hfeParseError(let msg): return "HFE parse error: \(msg)"
            }
        }
    }
    
    /// All E-mu related formats we can handle
    static let emuExtensions: Set<String> = ["eb2", "em2", "em1", "eb1", "ez2", "ez1", "hfe", "sf2", "hda", "img", "iso"]
    
    /// Identify format from file extension and magic bytes
    enum EmuFormat: String, CustomStringConvertible {
        case eb2 = "EMAX II Bank"
        case eb1 = "EMAX I Bank"
        case em2 = "EMAX II Floppy (emaxutil)"
        case em1 = "EMAX I Floppy (emaxutil)"
        case hfe = "Gotek Floppy Image"
        case ez2 = "EMAX II HD Image"
        case ez1 = "EMAX I HD Image"
        case sf2 = "SoundFont 2"
        case hda = "Raw HD Image"
        case unknown = "Unknown"
        
        var description: String { rawValue }
    }
    
    static func identifyFormat(url: URL) -> EmuFormat {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "eb2": return .eb2
        case "eb1": return .eb1
        case "em2": return .em2
        case "em1": return .em1
        case "hfe": return .hfe
        case "ez2": return .ez2
        case "ez1": return .ez1
        case "sf2": return .sf2
        case "hda", "img", "iso": return .hda
        default: return .unknown
        }
    }
    
    // MARK: - EM2 → EB2
    
    /// Extract EB2 bank data from an emaxutil .EM2 file
    /// Format: text header "emaxutil v... date\n" followed by raw bank data
    static func extractFromEM2(url: URL) throws -> Data {
        let data = try Data(contentsOf: url)
        
        // Find end of text header (first newline)
        guard let nlIndex = data.firstIndex(of: 0x0A) else {
            throw FormatError.invalidData("No emaxutil header found in .EM2 file")
        }
        
        let headerEnd = data.index(after: nlIndex)
        let bankData = data[headerEnd...]
        
        guard bankData.count > 0x200 else {
            throw FormatError.invalidData("EM2 bank data too small")
        }
        
        return Data(bankData)
    }
    
    // MARK: - EM1 → EB2 (EMAX I → II is approximate)
    
    /// Extract bank data from emaxutil .EM1 file
    /// Same header format as EM2 but EMAX I bank structure
    static func extractFromEM1(url: URL) throws -> Data {
        // Same extraction — EM1 and EM2 have identical wrapper
        return try extractFromEM2(url: url)
    }
    
    // MARK: - EB1 → EB2 passthrough
    
    /// EMAX I .EB1 bank — can be loaded on EMAX II (backward compatible)
    static func extractFromEB1(url: URL) throws -> Data {
        return try Data(contentsOf: url)
    }
    
    // MARK: - HFE → EB2 banks
    
    /// Extract bank data from an HFE floppy image
    /// HFE format: header (512 bytes) + track data
    /// EMAX II floppy = 80 tracks, 2 sides, ~10KB per track
    static func extractBanksFromHFE(url: URL) throws -> [Data] {
        let data = try Data(contentsOf: url)
        
        // Verify HFE magic
        guard data.count > 512,
              String(data: data[0..<8], encoding: .ascii) == "HXCPICFE" else {
            throw FormatError.hfeParseError("Invalid HFE magic")
        }
        
        // HFE header (parsed for future MFM decoder; currently unused — bank scan below)
        _ = data[8]           // revision
        _ = Int(data.readU16LE(at: 9))   // numTracks
        _ = Int(data[11])     // numSides
        _ = data[12]          // trackEncoding  (0=ISOIBM_MFM, 2=AMIGA_MFM)
        _ = Int(data.readU16LE(at: 14))  // bitRate
        _ = Int(data.readU16LE(at: 16))  // floppyRPM
        _ = data[18]          // floppyInterfaceMode

        // Track offset table starts at 0x200
        // Each entry: 2 bytes offset (in 512-byte blocks), 2 bytes length

        // For EMAX II floppies, the data is MFM encoded
        // We need to decode MFM → raw sector data → find EB2 banks
        // This is complex — for now, try to find raw bank data by scanning

        return try scanForBanks(in: data)
    }
    
    // MARK: - HD Image → EB2 banks
    
    /// Extract all user banks from an HD image as individual EB2 data
    static func extractBanksFromHDImage(url: URL) throws -> [(name: String, data: Data)] {
        let fs = try EmaxIIParser.parseHDImage(at: url)
        var banks: [(String, Data)] = []
        
        for entry in fs.userBanks {
            if let data = EmaxIIParser.readBankData(from: url, entry: entry, clusterSize: fs.clusterSize, clusterAreaStartSector: fs.clusterAreaStartSector) {
                banks.append((entry.name, data))
            }
        }
        
        return banks
    }
    
    // MARK: - Universal converter
    
    /// Convert any supported file to EB2 bank data
    /// Returns array of (bankName, bankData) tuples
    static func convertToEB2(url: URL) throws -> [(name: String, data: Data)] {
        let format = identifyFormat(url: url)
        
        switch format {
        case .eb2:
            // Already EB2
            let data = try Data(contentsOf: url)
            let name = extractBankName(from: data) ?? url.deletingPathExtension().lastPathComponent
            return [(name, data)]
            
        case .eb1:
            let data = try extractFromEB1(url: url)
            let name = url.deletingPathExtension().lastPathComponent
            return [(name, data)]
            
        case .em2:
            let data = try extractFromEM2(url: url)
            let name = extractBankName(from: data) ?? url.deletingPathExtension().lastPathComponent
            return [(name, data)]
            
        case .em1:
            let data = try extractFromEM1(url: url)
            let name = url.deletingPathExtension().lastPathComponent
            return [(name, data)]
            
        case .hfe:
            let banks = try extractBanksFromHFE(url: url)
            return banks.enumerated().map { i, data in
                let name = extractBankName(from: data) ?? "\(url.deletingPathExtension().lastPathComponent)_\(i)"
                return (name, data)
            }
            
        case .ez2, .hda:
            return try extractBanksFromHDImage(url: url)
            
        case .ez1:
            throw FormatError.unsupported("EMAX I HD images (.EZ1) not yet supported")
            
        case .sf2:
            return try SoundFontConverter.convertToEB2(url: url)
            
        case .unknown:
            throw FormatError.unsupported(url.pathExtension)
        }
    }
    
    /// Convert files and import into HD image
    static func convertAndImport(urls: [URL], into imageURL: URL) -> (imported: [String], errors: [(String, Error)]) {
        var imported: [String] = []
        var errors: [(String, Error)] = []
        
        for url in urls {
            do {
                let banks = try convertToEB2(url: url)
                for (_, data) in banks {
                    // Write to temp, then import
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("EB2")
                    try data.write(to: tempURL)
                    defer { try? FileManager.default.removeItem(at: tempURL) }
                    
                    let result = try BankImporter.importBank(eb2URL: tempURL, into: imageURL, allowDuplicate: true)
                    imported.append(result.bankName)
                }
            } catch {
                errors.append((url.lastPathComponent, error))
            }
        }
        
        return (imported, errors)
    }
    
    // MARK: - Helpers
    
    /// Extract bank name from EB2 data
    private static func extractBankName(from data: Data) -> String? {
        guard data.count >= 0x1B8 else { return nil }
        let name = String(data: data[0x1AC..<0x1B8], encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .init(charactersIn: "\0 "))
        return name?.isEmpty == false ? name : nil
    }
    
    /// Scan binary data for embedded EB2 banks (for HFE and raw images)
    private static func scanForBanks(in data: Data) throws -> [Data] {
        var banks: [Data] = []
        let searchRange = 0..<(data.count - 0x1C0)
        
        // Look for bank signatures: readable name at offset 0x1AC + marker at 0x1B8
        var offset = 0
        while offset < searchRange.upperBound {
            // Check for a valid bank start: look for the pattern at 0x1AC offset
            // This means we need to find where offset - 0x1AC is a bank start
            
            // Alternative: scan for preset markers (0x41 or 0x01) preceded by a bank name
            if offset + 13 <= data.count {
                let marker = data[offset + 12]
                if marker == 0x41 || marker == 0x01 {
                    // Check if preceding 12 bytes are a printable name
                    let nameBytes = data[offset..<(offset + 12)]
                    let isPrintable = nameBytes.allSatisfy { (0x20...0x7E).contains($0) || $0 == 0 }
                    let hasContent = nameBytes.contains(where: { $0 != 0x20 && $0 != 0 })
                    
                    if isPrintable && hasContent {
                        // Potential bank — the bank start is at offset - 0x1AC
                        let bankStart = offset - 0x1AC
                        if bankStart >= 0 {
                            // Try to determine bank size from metadata
                            if bankStart + 0x1B0 < data.count {
                                let sampleEnd = data.readU32LE(at: bankStart + 0x1A0)
                                let estimatedSize = max(Int(sampleEnd) + 0x200, 0x1000)
                                let safeSize = min(estimatedSize, data.count - bankStart)
                                
                                if safeSize > 0x200 {
                                    banks.append(Data(data[bankStart..<(bankStart + safeSize)]))
                                    offset = bankStart + safeSize
                                    continue
                                }
                            }
                        }
                    }
                }
            }
            offset += 1
        }
        
        return banks
    }
}

// MARK: - Data helpers

private extension Data {
    func readU16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return withUnsafeBytes { $0.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt16.self) }
    }
    
    func readU32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return withUnsafeBytes { $0.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt32.self) }
    }
}
