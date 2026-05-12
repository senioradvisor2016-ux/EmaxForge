import Foundation

/// Validates that a .hda image is bootable on EMAX II before writing to an SD card.
///
/// Acceptance criteria (Issue #5):
///  - Boot signature: 0x78 0x82 at offset 0x1FE
///  - FAT entry 0 == 0x8000 (reserved marker, verified against all EMXP templates)
///  - OS data non-zero at cluster 1 offset
///  - Catalog flags valid
public struct BootDiskValidator {

    // MARK: - Types

    public struct Check {
        public let name: String
        public let passed: Bool
        public let message: String
    }

    public struct ValidationResult {
        public let isBootable: Bool
        public let checks: [Check]

        public var summary: String {
            let fail = checks.filter { !$0.passed }
            if fail.isEmpty {
                return "✅ All \(checks.count) boot checks passed — image is bootable"
            }
            let names = fail.map(\.name).joined(separator: ", ")
            return "❌ \(fail.count) check(s) failed: \(names)"
        }
    }

    // MARK: - Boot Signatures per disk size

    /// Known valid EMAX II boot signatures (byte pair at 0x1FE).
    /// Each size gets a distinct signature embedded by the format tool.
    private static let validBootSignatures: [[UInt8]] = [
        [0x78, 0x82],  // 239 MB (most common)
        [0xA1, 0x93],  // 96 MB
        [0x65, 0x9F],  // 481 MB
        [0x79, 0x24],  // 633 MB
        [0xD7, 0xAD],  // 962 MB
    ]

    // MARK: - Validate

    /// Full boot-readiness validation.
    public static func validate(imageURL: URL) -> ValidationResult {
        var checks = [Check]()

        guard let handle = try? FileHandle(forReadingFrom: imageURL) else {
            let check = Check(name: "File access", passed: false,
                              message: "Cannot open \(imageURL.lastPathComponent)")
            return ValidationResult(isBootable: false, checks: [check])
        }
        defer { handle.closeFile() }

        let fileSize = Int(handle.seekToEndOfFile())

        // Need at least sector 0 + FAT area + catalog
        guard fileSize >= 0x2000 else {
            let check = Check(name: "File size", passed: false,
                              message: "File too small (\(fileSize) bytes) — not a valid image")
            return ValidationResult(isBootable: false, checks: [check])
        }

        // 1. Boot signature — 2 bytes at 0x1FE (offset 510)
        handle.seek(toFileOffset: 0x1FE)
        let sigBytes = handle.readData(ofLength: 2)
        let sig: [UInt8] = sigBytes.count == 2 ? [sigBytes[0], sigBytes[1]] : []
        let sigMatches = validBootSignatures.contains(where: { $0 == sig })
        let sigHex = sig.map { String(format: "0x%02X", $0) }.joined(separator: " ")
        checks.append(Check(
            name: "Boot signature",
            passed: sigMatches,
            message: sigMatches
                ? "\(sigHex) at 0x1FE ✓"
                : "\(sigHex) at 0x1FE — expected EMAX II signature (e.g. 0x78 0x82 for 239 MB)"
        ))

        // 2. FAT entry 0 == 0x8000 (reserved marker, verified against all EMXP templates and HD0.hda)
        handle.seek(toFileOffset: 0x400)
        let fatBytes = handle.readData(ofLength: 2)
        let fat0: UInt16
        if fatBytes.count == 2 {
            fat0 = UInt16(fatBytes[0]) | (UInt16(fatBytes[1]) << 8)
        } else {
            fat0 = 0xFFFF
        }
        let fat0Valid = fat0 == 0x8000
        checks.append(Check(
            name: "FAT entry 0",
            passed: fat0Valid,
            message: fat0Valid
                ? "0x\(String(format: "%04X", fat0)) ✓"
                : "0x\(String(format: "%04X", fat0)) — expected 0x8000 (EMAX II reserved FAT marker)"
        ))

        // 3. OS data non-zero at cluster 1 offset.
        //    The EMAX II header contains cluster size at 0x04 and cluster area start sector at 0x20.
        //    OS is at cluster 1 (0-based): offset = clusterAreaStart * 512 + 1 * clusterSize.
        //    We check cluster 0 (first byte of cluster area) as a quick proxy — cluster 0 is
        //    adjacent to cluster 1 and non-zero OS data is readable from the cluster area start.
        //    If we can't read the header, fall back to a fixed offset that works for all templates.
        handle.seek(toFileOffset: 0)
        let headerData = handle.readData(ofLength: 512)

        let clusterSize: Int
        let clusterAreaStartSector: Int

        if headerData.count >= 0x28 {
            let cs = Int(headerData.readU32LE(at: 0x04))
            let cas = Int(headerData.readU32LE(at: 0x20))
            clusterSize = cs > 0 && cs < 0x100_000 ? cs : 16384
            clusterAreaStartSector = cas > 0 ? cas : 512
        } else {
            clusterSize = 16384
            clusterAreaStartSector = 512
        }

        // OS is at cluster 1 (0-based): caOffset + 1 * clusterSize (verified vs OSManager.swift)
        let osDataOffset = UInt64(clusterAreaStartSector) * 512 + UInt64(clusterSize)
        var osDataValid = false
        if osDataOffset + 64 <= UInt64(fileSize) {
            handle.seek(toFileOffset: osDataOffset)
            let osSnippet = handle.readData(ofLength: 64)
            osDataValid = osSnippet.contains(where: { $0 != 0 })
        }
        checks.append(Check(
            name: "OS data at cluster 1",
            passed: osDataValid,
            message: osDataValid
                ? "Non-zero data at 0x\(String(format: "%X", osDataOffset)) ✓"
                : "All zeros at 0x\(String(format: "%X", osDataOffset)) — OS may not have been written"
        ))

        // 4. Catalog flags — BNT at headerData[0x10]*512, entry 0 should have
        //    recognized flag values (0x0068 primary, 0x0081 secondary, 0x0000 empty).
        let bntSector = headerData.count >= 0x14 ? Int(headerData.readU32LE(at: 0x10)) : 0
        let bntOffset = bntSector > 0 ? UInt64(bntSector) * 512 : 0x1000
        var catalogFlagsValid = true
        var catalogMessage = ""

        if bntOffset + 32 <= UInt64(fileSize) {
            handle.seek(toFileOffset: bntOffset)
            let bntEntry = handle.readData(ofLength: 32)
            if bntEntry.count >= 28 {
                let flags = UInt16(bntEntry[22]) | (UInt16(bntEntry[23]) << 8)
                // Valid flag values seen in all EMXP templates
                let validFlags: [UInt16] = [0x0000, 0x0068, 0x0069, 0x0081, 0x7800]
                let knownFlag = validFlags.contains(flags)
                if !knownFlag {
                    catalogFlagsValid = false
                    catalogMessage = "Unexpected catalog flags 0x\(String(format: "%04X", flags)) at BNT slot 0"
                } else {
                    catalogMessage = "flags=0x\(String(format: "%04X", flags)) ✓"
                }
            } else {
                catalogMessage = "Could not read catalog entry"
            }
        } else {
            catalogFlagsValid = false
            catalogMessage = "BNT offset 0x\(String(format: "%X", bntOffset)) beyond file size"
        }

        checks.append(Check(
            name: "Catalog flags",
            passed: catalogFlagsValid,
            message: catalogMessage
        ))

        let isBootable = checks.allSatisfy(\.passed)
        return ValidationResult(isBootable: isBootable, checks: checks)
    }

    /// Quick check — returns (isBootable, one-line summary)
    public static func quickCheck(imageURL: URL) -> (isBootable: Bool, summary: String) {
        let result = validate(imageURL: imageURL)
        return (result.isBootable, result.summary)
    }
}

// MARK: - Data helpers

private extension Data {
    func readU32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return withUnsafeBytes { buf in
            buf.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt32.self)
        }
    }
}
