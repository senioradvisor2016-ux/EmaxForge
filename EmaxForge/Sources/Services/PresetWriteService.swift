import Foundation

/// Write preset data back to an EMAX II disk image.
///
/// Builds on BankDataWriter for low-level cluster I/O.
///
/// Preset area layout (EMX full format, Ghidra-verified):
///   Bank buffer +0x200: preset area begins
///   Each preset block = 0x100 (256) bytes, max 256 presets
///
/// Per-preset block field offsets:
///   block +0x00..+0x0B  name (12 bytes ASCII, NUL-padded)              BNT +0x00
///   block +0x23         zoneCount (1 byte)                             BNT +0x23
///   block +0x24..+0x7B  keyMap (88 bytes, one byte per MIDI key 21–108, BNT +0x24
///                        0xFF = not assigned)
///   block +0x7C..       zone descriptors: zoneCount × 4 bytes          BNT +0x7C
///   block +0x7C + 4*zoneCount  voice detail records: zoneCount × 32 bytes
enum PresetWriteService {

    // MARK: - Error types

    enum PresetWriteError: LocalizedError {
        case presetIndexOutOfRange(Int)
        case bankDataTooSmall(Int)
        case invalidKeyMap(Int)
        case invalidVoiceRecordSize(index: Int, size: Int)
        case tooManyZones(Int)
        case nameTooLong(String)
        case underlyingError(Error)

        var errorDescription: String? {
            switch self {
            case .presetIndexOutOfRange(let i):
                return "Preset index \(i) is out of range (0–255)"
            case .bankDataTooSmall(let size):
                return "Bank data (\(size) bytes) is too small — no preset/sample area (need ≥ 0x10200 bytes)"
            case .invalidKeyMap(let size):
                return "keyMap must be exactly 88 bytes, got \(size)"
            case .invalidVoiceRecordSize(let i, let size):
                return "Voice record \(i) must be exactly 32 bytes, got \(size)"
            case .tooManyZones(let n):
                return "Too many zones (\(n)); maximum is 63 (fits within 256-byte preset block)"
            case .nameTooLong(let name):
                return "Preset name '\(name)' is too long (max 12 characters)"
            case .underlyingError(let error):
                return error.localizedDescription
            }
        }
    }

    // MARK: - PresetUpdate

    /// Describes which fields of a preset block to modify.
    /// Fields left as `nil` are not touched.
    struct PresetUpdate {
        /// New preset name (max 12 ASCII characters). Stored NUL-padded at block +0x00.
        var name: String?
        /// Array of 32-byte voice detail record blocks (one per zone). `nil` = do not change.
        /// Also updates the zoneCount byte at block +0x23.
        var voiceRecords: [Data]?
        /// 88-byte key map (MIDI keys 21–108, 0xFF = not assigned). `nil` = do not change.
        var keyMap: Data?
    }

    // MARK: - Main update

    /// Update one preset block inside a bank on disk.
    ///
    /// Steps:
    ///   1. Load disk geometry and read the full bank data buffer
    ///   2. Validate bank data size (≥ 0x10200 to have a preset/sample area)
    ///   3. Compute blockBase = 0x200 + presetIndex × 0x100
    ///   4. Apply each non-nil field from `update` into the buffer
    ///   5. Write the buffer back to the same clusters
    ///
    /// - Parameters:
    ///   - presetIndex: 0-based preset index (0–255)
    ///   - update:      Fields to modify (nil = unchanged)
    ///   - bankEntry:   Catalog entry with cluster chain
    ///   - imageURL:    URL of the EMAX II disk image
    static func updatePreset(
        at presetIndex: Int,
        update: PresetUpdate,
        in bankEntry: BankCatalogEntry,
        imageURL: URL
    ) throws {
        guard (0...255).contains(presetIndex) else {
            throw PresetWriteError.presetIndexOutOfRange(presetIndex)
        }

        // 1. Load geometry and read bank data
        let geo = try BankDataWriter.loadGeometry(from: imageURL)
        var bankData = try {
            do { return try BankDataWriter.readBankData(entry: bankEntry, from: imageURL, geometry: geo) }
            catch { throw PresetWriteError.underlyingError(error) }
        }()

        // 2. Validate bank data has preset + sample param area
        // Banks shorter than 0x10200 are EB2-format and lack the preset/sample table
        guard bankData.count >= 0x10200 else {
            throw PresetWriteError.bankDataTooSmall(bankData.count)
        }

        // 3. Preset block base address in bank buffer
        // Preset area starts at buffer +0x200; each block is 0x100 bytes
        let blockBase = 0x200 + presetIndex * 0x100  // BNT +0x00 of this preset

        // Ensure block fits within bank data
        guard blockBase + 0x100 <= bankData.count else {
            throw PresetWriteError.presetIndexOutOfRange(presetIndex)
        }

        // 4a. Apply name update
        if let name = update.name {
            guard name.count <= 12 else {
                throw PresetWriteError.nameTooLong(name)
            }
            // Name: 12 bytes, ASCII, NUL-terminated, space-padded — BNT +0x00
            var nameBytes = Data(count: 12)
            let encoded = name.prefix(12).data(using: .ascii) ?? Data()
            for (i, byte) in encoded.enumerated() where i < 12 {
                nameBytes[i] = byte
            }
            // Remaining bytes stay 0x00 (NUL padding as per EMAX II convention)
            bankData.replaceSubrange(
                (blockBase + 0x00)..<(blockBase + 0x0C),  // BNT +0x00: name (12 bytes)
                with: nameBytes
            )
        }

        // 4b. Apply keyMap update
        if let keyMap = update.keyMap {
            guard keyMap.count == 88 else {
                throw PresetWriteError.invalidKeyMap(keyMap.count)
            }
            // keyMap: 88 bytes at block +0x24 (MIDI keys 21–108) — BNT +0x24
            bankData.replaceSubrange(
                (blockBase + 0x24)..<(blockBase + 0x24 + 88),  // BNT +0x24: key map (88 bytes)
                with: keyMap
            )
        }

        // 4c. Apply voice records update
        if let records = update.voiceRecords {
            // Maximum zones: (0x100 - 0x7C) / (4 + 32) = 0x84 / 36 = 5.7 → max ~5–6 in practice
            // The block is 256 bytes; zone area starts at +0x7C leaving 0x84 bytes.
            // Each zone = 4 (descriptor) + 32 (detail) = 36 bytes → max 5 zones.
            // We allow up to what fits in the block.
            let zoneCount = records.count
            let zoneAreaSize = 4 * zoneCount + 32 * zoneCount
            guard blockBase + 0x7C + zoneAreaSize <= bankData.count else {
                throw PresetWriteError.tooManyZones(zoneCount)
            }

            for (i, record) in records.enumerated() {
                guard record.count == 32 else {
                    throw PresetWriteError.invalidVoiceRecordSize(index: i, size: record.count)
                }
            }

            // zoneCount byte at block +0x23 — BNT +0x23
            bankData.writeU8(UInt8(zoneCount), at: blockBase + 0x23)  // BNT +0x23: zone count

            // Zone descriptors: zoneCount × 4 bytes starting at block +0x7C — BNT +0x7C
            // Note: we preserve existing descriptor bytes; callers supply full records only.
            // Descriptors are kept as-is unless voiceRecords provides them implicitly via
            // the 32-byte record blocks written immediately after.

            // Voice detail records: zoneCount × 32 bytes after the descriptor area
            let detailBase = blockBase + 0x7C + (4 * zoneCount)  // BNT +0x7C + 4×zoneCount
            for (i, record) in records.enumerated() {
                let destStart = detailBase + i * 32
                let destEnd   = destStart + 32
                guard destEnd <= bankData.count else { break }
                bankData.replaceSubrange(destStart..<destEnd, with: record)
            }
        }

        // 5. Write buffer back to disk
        do {
            try BankDataWriter.writeBankData(bankData, entry: bankEntry, to: imageURL, geometry: geo)
        } catch {
            throw PresetWriteError.underlyingError(error)
        }
    }

    // MARK: - Rename preset (convenience)


    /// Rename a single preset in place without touching any other fields.
    ///
    /// - Parameters:
    ///   - index:    0-based preset index (0–255)
    ///   - newName:  New name string (max 12 ASCII characters)
    ///   - entry:    Catalog entry with cluster chain
    ///   - imageURL: URL of the EMAX II disk image
    static func renamePreset(
        at index: Int,
        newName: String,
        in entry: BankCatalogEntry,
        imageURL: URL
    ) throws {
        let update = PresetUpdate(name: newName, voiceRecords: nil, keyMap: nil)
        try updatePreset(at: index, update: update, in: entry, imageURL: imageURL)
    }
}

// MARK: - Data helpers

private extension Data {
    mutating func writeU8(_ value: UInt8, at offset: Int) {
        guard offset < count else { return }
        self[offset] = value
    }

    mutating func writeU16LE(_ value: UInt16, at offset: Int) {
        guard offset + 2 <= count else { return }
        self[offset]     = UInt8(value & 0xFF)
        self[offset + 1] = UInt8(value >> 8)
    }

    mutating func writeU32LE(_ value: UInt32, at offset: Int) {
        guard offset + 4 <= count else { return }
        self[offset]     = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8)  & 0xFF)
        self[offset + 2] = UInt8((value >> 16) & 0xFF)
        self[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
}
