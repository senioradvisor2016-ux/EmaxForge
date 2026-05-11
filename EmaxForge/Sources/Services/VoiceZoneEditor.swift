import Foundation

/// Edit voice zones, key maps, and zone descriptors within EMAX II bank presets.
///
/// Preset block layout (256 bytes at presetArea + index x 0x100 - Ghidra-verified):
///   +0x00..+0x0B  name (12 bytes ASCII, NUL-padded)
///   +0x23         zoneCount (1 byte - number of active key-zone voice records)
///   +0x24..+0x7B  keyMap (88 bytes - one byte per MIDI key, value = sample index or 0xFF)
///                 index 0 = MIDI 21 (A0), index 87 = MIDI 108 (C8)
///   +0x7C..       zone descriptors: zoneCount x 4 bytes
///                 then voice detail records: zoneCount x 32 bytes
///
/// Key map convention:
///   keyMap[i] = 0xFF -> no sample assigned to MIDI key (21 + i)
///   keyMap[i] = n    -> sample index n assigned to MIDI key (21 + i)
class VoiceZoneEditor {

    // MARK: - Public types

    struct ZoneDescriptor {
        var voiceGroup: UInt8    // 0-5 (bits 1:3 in descriptor byte 0)
        var velocityLow: UInt8   // 0-127 (0xFF = inactive)
        var velocityHigh: UInt8  // 0-127
    }

    struct EditResult {
        let presetIndex: Int
        let zoneCount: Int
        let keyMapBytesWritten: Int
    }

    enum EditError: LocalizedError {
        case invalidMidiKey(Int)
        case invalidKeyRange(low: Int, high: Int)
        case presetIndexOutOfRange(Int)
        case bankReadError(String)
        case bankWriteError(String)
        case invalidVoiceRecord(String)

        var errorDescription: String? {
            switch self {
            case .invalidMidiKey(let k):
                return "MIDI key \(k) is out of the supported range [21-108]"
            case .invalidKeyRange(let lo, let hi):
                return "Invalid key range: low \(lo) must be <= high \(hi)"
            case .presetIndexOutOfRange(let i):
                return "Preset index \(i) is out of range (0-255)"
            case .bankReadError(let msg):
                return "Bank read error: \(msg)"
            case .bankWriteError(let msg):
                return "Bank write error: \(msg)"
            case .invalidVoiceRecord(let msg):
                return "Invalid voice record: \(msg)"
            }
        }
    }

    // MARK: - Constants

    private static let presetAreaOffset   = 0x200
    private static let presetSize         = 0x100
    private static let maxPresets         = 256

    // Offsets within a preset block
    private static let zoneCountOffset    = 0x23
    private static let keyMapOffset       = 0x24
    private static let keyMapLength       = 88         // keys A0-C8
    private static let keyMapMidiBase     = 21         // MIDI note for keyMap[0]
    private static let zoneDescBase       = 0x7C
    private static let zoneDescSize       = 4
    private static let voiceRecordSize    = 32

    // MARK: - assignSampleToKeyRange

    /// Assign a sample index to a contiguous range of MIDI keys in a preset's key map.
    ///
    /// Algorithm:
    ///  1. Validate MIDI key bounds and ordering.
    ///  2. Convert MIDI keys to key-map indices (index = midiKey - 21).
    ///  3. Read bank data, locate preset block, write sampleIndex into
    ///     keyMap[midiKeyLow-21 .. midiKeyHigh-21] (inclusive).
    ///  4. Recalculate zoneCount: count of unique non-0xFF sample indices in the full key map.
    ///  5. Write back zoneCount at block+0x23.
    ///  6. Write bank data back to disk.
    static func assignSampleToKeyRange(
        presetIndex: Int,
        midiKeyLow: Int,
        midiKeyHigh: Int,
        sampleIndex: UInt8,
        in bankEntry: BankCatalogEntry,
        imageURL: URL
    ) throws -> EditResult {
        guard (0..<maxPresets).contains(presetIndex) else {
            throw EditError.presetIndexOutOfRange(presetIndex)
        }
        guard midiKeyLow >= 21 && midiKeyLow <= 108 else {
            throw EditError.invalidMidiKey(midiKeyLow)
        }
        guard midiKeyHigh >= 21 && midiKeyHigh <= 108 else {
            throw EditError.invalidMidiKey(midiKeyHigh)
        }
        guard midiKeyLow <= midiKeyHigh else {
            throw EditError.invalidKeyRange(low: midiKeyLow, high: midiKeyHigh)
        }

        let geo      = try loadGeometry(from: imageURL)
        var bankData = try readBank(entry: bankEntry, imageURL: imageURL, geo: geo)

        let blockBase  = Self.presetAreaOffset + presetIndex * Self.presetSize
        let keyMapBase = blockBase + Self.keyMapOffset

        guard keyMapBase + Self.keyMapLength <= bankData.count else {
            throw EditError.bankReadError("Bank data too small for preset \(presetIndex) key map")
        }

        // Convert MIDI keys to key-map indices
        let idxLow  = midiKeyLow  - Self.keyMapMidiBase
        let idxHigh = midiKeyHigh - Self.keyMapMidiBase

        // Write sample index into the key map range
        var written = 0
        for k in idxLow...idxHigh {
            let byteOff = keyMapBase + k
            guard byteOff < bankData.count else { break }
            bankData[byteOff] = sampleIndex
            written += 1
        }

        // Recalculate zoneCount: unique sample indices (excluding 0xFF) in full key map
        var uniqueSamples = Set<UInt8>()
        for k in 0..<Self.keyMapLength {
            let byteOff = keyMapBase + k
            guard byteOff < bankData.count else { break }
            let v = bankData[byteOff]
            if v != 0xFF { uniqueSamples.insert(v) }
        }
        let newZoneCount = UInt8(uniqueSamples.count)
        bankData[blockBase + Self.zoneCountOffset] = newZoneCount

        try writeBank(bankData, entry: bankEntry, imageURL: imageURL, geo: geo)

        return EditResult(
            presetIndex: presetIndex,
            zoneCount: Int(newZoneCount),
            keyMapBytesWritten: written
        )
    }

    // MARK: - clearSampleAssignments

    /// Remove all key-map assignments for a specific sample index in a preset.
    ///
    /// Writes 0xFF to every byte in the key map that equals `sampleIndex`, then
    /// recalculates and updates zoneCount.
    static func clearSampleAssignments(
        sampleIndex: UInt8,
        presetIndex: Int,
        in bankEntry: BankCatalogEntry,
        imageURL: URL
    ) throws -> EditResult {
        guard (0..<maxPresets).contains(presetIndex) else {
            throw EditError.presetIndexOutOfRange(presetIndex)
        }

        let geo      = try loadGeometry(from: imageURL)
        var bankData = try readBank(entry: bankEntry, imageURL: imageURL, geo: geo)

        let blockBase  = Self.presetAreaOffset + presetIndex * Self.presetSize
        let keyMapBase = blockBase + Self.keyMapOffset

        guard keyMapBase + Self.keyMapLength <= bankData.count else {
            throw EditError.bankReadError("Bank data too small for preset \(presetIndex) key map")
        }

        var cleared = 0
        for k in 0..<Self.keyMapLength {
            let byteOff = keyMapBase + k
            guard byteOff < bankData.count else { break }
            if bankData[byteOff] == sampleIndex {
                bankData[byteOff] = 0xFF
                cleared += 1
            }
        }

        // Recalculate zoneCount
        var uniqueSamples = Set<UInt8>()
        for k in 0..<Self.keyMapLength {
            let byteOff = keyMapBase + k
            guard byteOff < bankData.count else { break }
            let v = bankData[byteOff]
            if v != 0xFF { uniqueSamples.insert(v) }
        }
        let newZoneCount = UInt8(uniqueSamples.count)
        bankData[blockBase + Self.zoneCountOffset] = newZoneCount

        try writeBank(bankData, entry: bankEntry, imageURL: imageURL, geo: geo)

        return EditResult(
            presetIndex: presetIndex,
            zoneCount: Int(newZoneCount),
            keyMapBytesWritten: cleared
        )
    }

    // MARK: - updateZones

    /// Replace the zone descriptors and voice detail records for a preset.
    ///
    /// Layout of zone data starting at block+0x7C:
    ///   zoneCount x 4 bytes  -> zone descriptors
    ///   zoneCount x 32 bytes -> voice detail records
    ///
    /// The `zones` array provides one (descriptor, voiceRecord) pair per zone.
    /// `voiceRecord` must be exactly 32 bytes. Also updates zoneCount at block+0x23.
    static func updateZones(
        presetIndex: Int,
        zones: [(descriptor: ZoneDescriptor, voiceRecord: Data)],
        in bankEntry: BankCatalogEntry,
        imageURL: URL
    ) throws -> EditResult {
        guard (0..<maxPresets).contains(presetIndex) else {
            throw EditError.presetIndexOutOfRange(presetIndex)
        }
        for (i, zone) in zones.enumerated() {
            guard zone.voiceRecord.count == Self.voiceRecordSize else {
                throw EditError.invalidVoiceRecord(
                    "Zone \(i) voiceRecord must be \(Self.voiceRecordSize) bytes, got \(zone.voiceRecord.count)")
            }
        }

        let geo      = try loadGeometry(from: imageURL)
        var bankData = try readBank(entry: bankEntry, imageURL: imageURL, geo: geo)

        let blockBase     = Self.presetAreaOffset + presetIndex * Self.presetSize
        let zoneDescStart = blockBase + Self.zoneDescBase
        let zoneCount     = zones.count

        // Check zone data fits within the 256-byte preset block
        let zoneDataSize = zoneCount * Self.zoneDescSize + zoneCount * Self.voiceRecordSize
        let zoneDataEnd  = zoneDescStart + zoneDataSize

        guard zoneDataEnd <= blockBase + Self.presetSize else {
            throw EditError.bankWriteError(
                "Zone data (\(zoneDataSize) bytes) overflows preset block for \(zoneCount) zones")
        }
        guard zoneDataEnd <= bankData.count else {
            throw EditError.bankReadError("Bank data too small for preset \(presetIndex) zone data")
        }

        // Update zoneCount byte
        bankData[blockBase + Self.zoneCountOffset] = UInt8(zoneCount)

        // Write zone descriptors (4 bytes each)
        for (i, zone) in zones.enumerated() {
            let descOff = zoneDescStart + i * Self.zoneDescSize
            // byte 0: bits 1-3 encode voiceGroup
            bankData[descOff + 0] = (zone.descriptor.voiceGroup & 0x07) << 1
            bankData[descOff + 1] = zone.descriptor.velocityLow
            bankData[descOff + 2] = zone.descriptor.velocityHigh
            bankData[descOff + 3] = 0x00
        }

        // Write voice detail records (32 bytes each) immediately after all descriptors
        let voiceRecordStart = zoneDescStart + zoneCount * Self.zoneDescSize
        for (i, zone) in zones.enumerated() {
            let recOff = voiceRecordStart + i * Self.voiceRecordSize
            guard recOff + Self.voiceRecordSize <= bankData.count else { break }
            bankData.replaceSubrange(
                recOff ..< recOff + Self.voiceRecordSize,
                with: zone.voiceRecord
            )
        }

        try writeBank(bankData, entry: bankEntry, imageURL: imageURL, geo: geo)

        return EditResult(
            presetIndex: presetIndex,
            zoneCount: zoneCount,
            keyMapBytesWritten: 0
        )
    }

    // MARK: - Private helpers

    private static func loadGeometry(from imageURL: URL) throws -> BankDataWriter.DiskGeometry {
        do {
            return try BankDataWriter.loadGeometry(from: imageURL)
        } catch {
            throw EditError.bankReadError(error.localizedDescription)
        }
    }

    private static func readBank(
        entry: BankCatalogEntry,
        imageURL: URL,
        geo: BankDataWriter.DiskGeometry
    ) throws -> Data {
        do {
            return try BankDataWriter.readBankData(entry: entry, from: imageURL, geometry: geo)
        } catch {
            throw EditError.bankReadError(error.localizedDescription)
        }
    }

    private static func writeBank(
        _ data: Data,
        entry: BankCatalogEntry,
        imageURL: URL,
        geo: BankDataWriter.DiskGeometry
    ) throws {
        do {
            try BankDataWriter.writeBankData(data, entry: entry, to: imageURL, geometry: geo)
        } catch {
            throw EditError.bankWriteError(error.localizedDescription)
        }
    }
}
