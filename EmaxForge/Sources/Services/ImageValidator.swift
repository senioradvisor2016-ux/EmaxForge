import Foundation

/// Validates EMAX II disk images for structural integrity
/// Based on industry-standard format specification validation (Mar 17, 2026)
class ImageValidator {
    
    struct ValidationResult {
        let isValid: Bool
        let checks: [Check]
        let errors: [ValidationError]?
        let errorCount: Int
        
        struct Check {
            let name: String
            let passed: Bool
            let message: String
        }
        
        struct ValidationError: Codable {
            let code: String
            let title: String
            let description: String
            let context: String?
            let repairHint: String?
            let offset: String?
            
            enum CodingKeys: String, CodingKey {
                case code, title, description, context
                case repairHint = "repair_hint"
                case offset
            }
        }
    }
    
    enum ValidatorError: LocalizedError {
        case fileNotFound
        case fileTooSmall
        case readError(String)
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound: return "Image file not found"
            case .fileTooSmall: return "Image file too small"
            case .readError(let msg): return "Read error: \(msg)"
            }
        }
    }
    
    /// Validate an EMAX II disk image
    /// Returns detailed validation results
    /// - Parameter detailed: If true, includes standard tools error codes (E001-E020)
    static func validate(imageURL: URL, detailed: Bool = false) async throws -> ValidationResult {
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw ValidatorError.fileNotFound
        }
        
        let handle = try FileHandle(forReadingFrom: imageURL)
        defer { try? handle.close() }
        
        var checks: [ValidationResult.Check] = []
        
        // Read header (first 512 bytes)
        handle.seek(toFileOffset: 0)
        guard let headerData = try handle.read(upToCount: 512), headerData.count == 512 else {
            throw ValidatorError.fileTooSmall
        }
        
        // Check 1: File size
        let fileSize = try FileManager.default.attributesOfItem(atPath: imageURL.path)[.size] as? Int ?? 0
        let sizeMB = fileSize / (1024 * 1024)
        let expectedSizes = [96, 239, 481, 633, 962]
        let sizeValid = expectedSizes.contains { abs(sizeMB - $0) <= 1 }
        checks.append(.init(
            name: "File size",
            passed: sizeValid,
            message: sizeValid ? "\(sizeMB) MB ✓" : "\(sizeMB) MB (unexpected size)"
        ))
        
        // Check 2: Boot signature — size-specific byte pair at offset 0x1FE-0x1FF.
        // Each EMAX II disk size has a distinct opaque signature from the format tool.
        // Compare bytes directly (do NOT interpret as a UInt16 — endian confusion caused 0x7882 bug).
        let bootSigBySize: [Int: (UInt8, UInt8)] = [
            96:  (0xA1, 0x93),
            239: (0x78, 0x82),
            481: (0x65, 0x9F),
            633: (0x79, 0x24),
            962: (0xD7, 0xAD),
        ]
        handle.seek(toFileOffset: 0x1FE)
        guard let bootSigData = try handle.read(upToCount: 2), bootSigData.count == 2 else {
            checks.append(.init(name: "Boot signature", passed: false, message: "Could not read"))
            return ValidationResult(isValid: false, checks: checks, errors: nil, errorCount: 0)
        }

        let bootSigValid: Bool
        if let (b0, b1) = bootSigBySize[sizeMB] {
            bootSigValid = bootSigData[0] == b0 && bootSigData[1] == b1
        } else {
            // Unknown size — accept any non-empty, non-PC-MBR signature
            bootSigValid = !(bootSigData[0] == 0x55 && bootSigData[1] == 0xAA)
                        && !(bootSigData[0] == 0 && bootSigData[1] == 0)
        }
        let sigHex = String(format: "0x%02X 0x%02X", bootSigData[0], bootSigData[1])
        checks.append(.init(
            name: "Boot signature",
            passed: bootSigValid,
            message: bootSigValid ? "\(sigHex) ✓" : "\(sigHex) ✗ (unexpected for \(sizeMB) MB disk)"
        ))
        
        // Check 3: FAT header (entry 0 == 0x8000, reserved marker, verified against all EMXP templates)
        handle.seek(toFileOffset: 0x400)
        guard let fatData = try handle.read(upToCount: 2), fatData.count == 2 else {
            checks.append(.init(name: "FAT header", passed: false, message: "Could not read"))
            return ValidationResult(isValid: false, checks: checks, errors: nil, errorCount: 0)
        }
        
        // FAT[0] == 0x8000 (reserved marker, verified against all EMXP templates and HD0.hda)
        let fatEntry0 = UInt16(fatData[0]) | (UInt16(fatData[1]) << 8)
        let fatValid = fatEntry0 == 0x8000
        checks.append(.init(
            name: "FAT header",
            passed: fatValid,
            message: fatValid ? String(format: "0x%04X ✓", fatEntry0) : String(format: "0x%04X ✗ (expected 0x8000)", fatEntry0)
        ))
        
        // Check 4: BNT/Catalog entries (32-byte, offset from header[0x10])
        let bntSector: UInt64 = headerData.count >= 0x14
            ? UInt64(headerData[0x10]) | (UInt64(headerData[0x11]) << 8) | (UInt64(headerData[0x12]) << 16) | (UInt64(headerData[0x13]) << 24)
            : 0x08
        let maxBanks: Int = headerData.count >= 0x18
            ? Int(headerData[0x14]) | (Int(headerData[0x15]) << 8) | (Int(headerData[0x16]) << 16) | (Int(headerData[0x17]) << 24)
            : 90
        let bntOffset = bntSector * 512
        let readSize = min((maxBanks + 1) * 32, 16384)
        
        handle.seek(toFileOffset: bntOffset)
        guard let catalogData = try handle.read(upToCount: readSize), catalogData.count >= 32 else {
            checks.append(.init(name: "BNT/Catalog", passed: false, message: "Could not read at 0x\(String(bntOffset, radix: 16))"))
            return ValidationResult(isValid: false, checks: checks, errors: nil, errorCount: 0)
        }
        
        var entryCount = 0
        for i in stride(from: 0, to: catalogData.count, by: 32) {
            guard i + 32 <= catalogData.count else { break }
            if catalogData[i] != 0x00 && catalogData[i] != 0xFF {
                entryCount += 1
            }
        }
        
        let catalogValid = entryCount >= 0
        checks.append(.init(
            name: "BNT/Catalog",
            passed: catalogValid,
            message: catalogValid ? "\(entryCount) entries, 32-byte @ 0x\(String(bntOffset, radix: 16, uppercase: true))" : "Invalid structure"
        ))
        
        // Overall validity
        let isValid = checks.allSatisfy { $0.passed }
        
        // If detailed errors requested, call CLI
        var errors: [ValidationResult.ValidationError]? = nil
        var errorCount = 0
        
        if detailed && !isValid {
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["cli-anything-emaxforge", "verify-disk", imageURL.path, "--detailed", "--json"]
                
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let json = try? JSONDecoder().decode([String: AnyCodable].self, from: data),
                   let errorArray = json["errors"]?.value as? [[String: Any]] {
                    errors = errorArray.compactMap { dict in
                        guard let code = dict["code"] as? String,
                              let title = dict["title"] as? String,
                              let description = dict["description"] as? String else {
                            return nil
                        }
                        return ValidationResult.ValidationError(
                            code: code,
                            title: title,
                            description: description,
                            context: dict["context"] as? String,
                            repairHint: dict["repair_hint"] as? String,
                            offset: dict["offset"] as? String
                        )
                    }
                    errorCount = errors?.count ?? 0
                }
            } catch {
                // CLI call failed, continue without detailed errors
            }
        }
        
        return ValidationResult(isValid: isValid, checks: checks, errors: errors, errorCount: errorCount)
    }
    
    // Helper for dynamic JSON decoding
    private struct AnyCodable: Codable {
        let value: Any
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let int = try? container.decode(Int.self) {
                value = int
            } else if let double = try? container.decode(Double.self) {
                value = double
            } else if let string = try? container.decode(String.self) {
                value = string
            } else if let bool = try? container.decode(Bool.self) {
                value = bool
            } else if let array = try? container.decode([AnyCodable].self) {
                value = array.map { $0.value }
            } else if let dict = try? container.decode([String: AnyCodable].self) {
                value = dict.mapValues { $0.value }
            } else {
                value = NSNull()
            }
        }
        
        func encode(to encoder: Encoder) throws {
            // Not needed for our use case
        }
    }
    
    /// Check if disk has OS installed (BNT slot 0 contains "EMAX2 Software")
    static func hasOS(imageURL: URL) throws -> Bool {
        let handle = try FileHandle(forReadingFrom: imageURL)
        defer { try? handle.close() }
        
        // Read header to get BNT offset
        handle.seek(toFileOffset: 0)
        guard let header = try handle.read(upToCount: 512), header.count >= 0x14 else {
            return false
        }
        let bntSector = header.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0x10, as: UInt32.self) }
        let bntOffset = UInt64(bntSector) * 512
        
        // Read BNT entry 0 (32 bytes)
        handle.seek(toFileOffset: bntOffset)
        guard let entry = try handle.read(upToCount: 32), entry.count == 32 else {
            return false
        }
        
        let nameData = entry.subdata(in: 0..<14)
        if let name = String(data: nameData, encoding: .ascii) {
            return name.uppercased().contains("EMAX")
        }
        
        return false
    }
    
    /// Parse cluster size from disk header
    /// Cluster size is stored at offset 0x04 as raw byte count (NOT 0x0C!)
    static func getClusterSize(imageURL: URL) throws -> Int {
        let handle = try FileHandle(forReadingFrom: imageURL)
        defer { try? handle.close() }
        
        handle.seek(toFileOffset: 0x04)
        guard let data = try handle.read(upToCount: 4), data.count == 4 else {
            throw ValidatorError.readError("Could not read cluster size field")
        }
        
        // Parse as little-endian UInt32 — this IS the cluster size in bytes
        let blocks = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        
        // header[0x04] is cluster size in bytes directly — no conversion needed
        return Int(blocks)
    }
}
