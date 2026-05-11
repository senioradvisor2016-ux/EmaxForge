import Foundation

/// Write sample parameter data back to an EMAX II disk image.
///
/// Builds on BankDataWriter for low-level cluster I/O.
///
/// Sample parameter area layout (EMX full format, Ghidra-verified):
///   Bank buffer +0x10200: sample param area begins
///   Each param block = 0x40 (64) bytes, max 999 samples
///
/// Per-sample block field offsets (all verified via Ghidra FUN_00503580 / FUN_0058a990):
///   param +0x00  startAddress     (U32 LE)         param +0x00
///   param +0x04  endAddress       (U32 LE)         param +0x04
///   param +0x08  sampleRate       (U16 LE, Hz)     param +0x08
///   param +0x0A  originalKey      (U8, MIDI 0–127) param +0x0A
///   param +0x0B  flags            (U8, bit0=soundType, bit1=userDefinedName) param +0x0B
///   param +0x0C  sustainLoopStart (U32 LE)         param +0x0C
///   param +0x10  sustainLoopEnd   (U32 LE)         param +0x10
///   param +0x14  releaseLoopStart (U32 LE)         param +0x14
///   param +0x18  releaseLoopEnd   (U32 LE)         param +0x18
///   param +0x1C  loopFlags        (U8, bit0=sustain, bit1=release, bit2=backward) param +0x1C
///   param +0x20  name             (16 bytes ASCII, NUL-terminated, space-padded) param +0x20
///   param +0x30  outputChannel    (U8, 1–8)        param +0x30
enum SampleParamWriteService {

    // MARK: - Error types

    enum SampleWriteError: LocalizedError {
        case sampleIndexOutOfRange(Int)
        case bankDataTooSmall(Int)
        case nameTooLong(String)
        case underlyingError(Error)

        var errorDescription: String? {
            switch self {
            case .sampleIndexOutOfRange(let i):
                return "Sample index \(i) is out of range (0–998)"
            case .bankDataTooSmall(let size):
                return "Bank data (\(size) bytes) is too small — no sample parameter area (need ≥ 0x10200 bytes)"
            case .nameTooLong(let name):
                return "Sample name '\(name)' is too long (max 16 characters)"
            case .underlyingError(let error):
                return error.localizedDescription
            }
        }
    }

    // MARK: - SampleParamUpdate

    /// Describes which fields of a sample parameter block to modify.
    /// Fields left as `nil` are not touched.
    struct SampleParamUpdate {
        /// Sample start address (relative byte offset into sample data area). param +0x00
        var startAddress: UInt32?
        /// Sample end address (relative byte offset, exclusive). param +0x04
        var endAddress: UInt32?
        /// Sample rate in Hz (e.g. 39063, 44100). param +0x08
        var sampleRate: UInt16?
        /// MIDI root note (0–127). param +0x0A
        var originalKey: UInt8?
        /// Flags byte (bit0=soundType/DECAYED, bit1=userDefinedName). param +0x0B
        var flags: UInt8?
        /// Sustain loop start frame offset. param +0x0C
        var sustainLoopStart: UInt32?
        /// Sustain loop end frame offset (0 = disabled). param +0x10
        var sustainLoopEnd: UInt32?
        /// Release loop start frame offset (EMAX II). param +0x14
        var releaseLoopStart: UInt32?
        /// Release loop end frame offset (0 = disabled). param +0x18
        var releaseLoopEnd: UInt32?
        /// Loop flags (bit0=sustainEnabled, bit1=releaseEnabled, bit2=backward). param +0x1C
        var loopFlags: UInt8?
        /// Sample name (max 16 ASCII characters, NUL-terminated). param +0x20
        var name: String?
        /// Output channel routing (1–8, 0 = unset). param +0x30
        var outputChannel: UInt8?
    }

    // MARK: - Main update

    /// Update one sample parameter block inside a bank on disk.
    ///
    /// Steps:
    ///   1. Load disk geometry and read the full bank data buffer
    ///   2. Validate bank data size (≥ 0x10200 to have a sample param area)
    ///   3. Compute paramBase = 0x10200 + sampleIndex × 0x40
    ///   4. Apply each non-nil field from `update` into the buffer
    ///   5. Write the buffer back to the same clusters
    ///
    /// - Parameters:
    ///   - sampleIndex: 0-based sample index (0–998)
    ///   - update:      Fields to modify (nil = unchanged)
    ///   - bankEntry:   Catalog entry with cluster chain
    ///   - imageURL:    URL of the EMAX II disk image
    static func updateSampleParam(
        at sampleIndex: Int,
        update: SampleParamUpdate,
        in bankEntry: BankCatalogEntry,
        imageURL: URL
    ) throws {
        guard (0...998).contains(sampleIndex) else {
            throw SampleWriteError.sampleIndexOutOfRange(sampleIndex)
        }

        // 1. Load geometry and read bank data
        let geo = try BankDataWriter.loadGeometry(from: imageURL)
        var bankData = try {
            do { return try BankDataWriter.readBankData(entry: bankEntry, from: imageURL, geometry: geo) }
            catch { throw SampleWriteError.underlyingError(error) }
        }()

        // 2. Validate bank data has sample param area
        // Banks shorter than 0x10200 are EB2-format and lack the sample param table
        guard bankData.count >= 0x10200 else {
            throw SampleWriteError.bankDataTooSmall(bankData.count)
        }

        // 3. Sample param block base address in bank buffer
        // Sample param area starts at buffer +0x10200; each block is 0x40 bytes
        let paramBase = 0x10200 + sampleIndex * 0x40  // param +0x00 of this sample

        // Ensure block fits within bank data
        guard paramBase + 0x40 <= bankData.count else {
            throw SampleWriteError.sampleIndexOutOfRange(sampleIndex)
        }

        // 4. Apply updates — only non-nil fields are written

        if let v = update.startAddress {
            // param +0x00: startAddress (U32 LE)
            bankData.writeU32LE(v, at: paramBase + 0x00)  // param +0x00
        }

        if let v = update.endAddress {
            // param +0x04: endAddress (U32 LE)
            bankData.writeU32LE(v, at: paramBase + 0x04)  // param +0x04
        }

        if let v = update.sampleRate {
            // param +0x08: sampleRate (U16 LE, Hz)
            bankData.writeU16LE(v, at: paramBase + 0x08)  // param +0x08
        }

        if let v = update.originalKey {
            // param +0x0A: originalKey (U8, MIDI root note 0–127)
            bankData.writeU8(v, at: paramBase + 0x0A)     // param +0x0A
        }

        if let v = update.flags {
            // param +0x0B: flags (bit0=soundType/DECAYED, bit1=userDefinedName)
            bankData.writeU8(v, at: paramBase + 0x0B)     // param +0x0B
        }

        if let v = update.sustainLoopStart {
            // param +0x0C: sustainLoopStart (U32 LE, sample-frame offset)
            bankData.writeU32LE(v, at: paramBase + 0x0C)  // param +0x0C
        }

        if let v = update.sustainLoopEnd {
            // param +0x10: sustainLoopEnd (U32 LE, sample-frame offset, 0=off)
            bankData.writeU32LE(v, at: paramBase + 0x10)  // param +0x10
        }

        if let v = update.releaseLoopStart {
            // param +0x14: releaseLoopStart (U32 LE, EMAX II only)
            bankData.writeU32LE(v, at: paramBase + 0x14)  // param +0x14
        }

        if let v = update.releaseLoopEnd {
            // param +0x18: releaseLoopEnd (U32 LE, 0=off)
            bankData.writeU32LE(v, at: paramBase + 0x18)  // param +0x18
        }

        if let v = update.loopFlags {
            // param +0x1C: loopFlags (bit0=sustainEnabled, bit1=releaseEnabled, bit2=backward)
            bankData.writeU8(v, at: paramBase + 0x1C)     // param +0x1C
        }

        if let name = update.name {
            guard name.count <= 16 else {
                throw SampleWriteError.nameTooLong(name)
            }
            // param +0x20: name (16 bytes, ASCII, NUL-terminated, space-padded)
            var nameBytes = Data(count: 16)
            let encoded = name.prefix(16).data(using: .ascii) ?? Data()
            for (i, byte) in encoded.enumerated() where i < 16 {
                nameBytes[i] = byte
            }
            // Remaining bytes stay 0x00 (NUL padding)
            bankData.replaceSubrange(
                (paramBase + 0x20)..<(paramBase + 0x30),  // param +0x20: name (16 bytes)
                with: nameBytes
            )
        }

        if let v = update.outputChannel {
            // param +0x30: outputChannel (U8, 1–8)
            bankData.writeU8(v, at: paramBase + 0x30)     // param +0x30
        }

        // 5. Write buffer back to disk
        do {
            try BankDataWriter.writeBankData(bankData, entry: bankEntry, to: imageURL, geometry: geo)
        } catch {
            throw SampleWriteError.underlyingError(error)
        }
    }

    // MARK: - Convenience: update loop points

    /// Update all loop parameters for a single sample in one operation.
    ///
    /// Sets both sustain and release loop addresses and the loopFlags byte atomically.
    ///
    /// - Parameters:
    ///   - sampleIndex:   0-based sample index (0–998)
    ///   - sustainStart:  Sustain loop start frame offset (param +0x0C)
    ///   - sustainEnd:    Sustain loop end frame offset (param +0x10)
    ///   - releaseStart:  Release loop start frame offset (param +0x14)
    ///   - releaseEnd:    Release loop end frame offset (param +0x18)
    ///   - loopFlags:     Loop flags byte (bit0=sustainEnabled, bit1=releaseEnabled, bit2=backward)
    ///   - bankEntry:     Catalog entry with cluster chain
    ///   - imageURL:      URL of the EMAX II disk image
    static func updateLoopPoints(
        at sampleIndex: Int,
        sustainStart: UInt32,
        sustainEnd: UInt32,
        releaseStart: UInt32,
        releaseEnd: UInt32,
        loopFlags: UInt8,
        in bankEntry: BankCatalogEntry,
        imageURL: URL
    ) throws {
        let update = SampleParamUpdate(
            startAddress:    nil,
            endAddress:      nil,
            sampleRate:      nil,
            originalKey:     nil,
            flags:           nil,
            sustainLoopStart: sustainStart,
            sustainLoopEnd:   sustainEnd,
            releaseLoopStart: releaseStart,
            releaseLoopEnd:   releaseEnd,
            loopFlags:        loopFlags,
            name:            nil,
            outputChannel:   nil
        )
        try updateSampleParam(at: sampleIndex, update: update, in: bankEntry, imageURL: imageURL)
    }

    // MARK: - Convenience: rename sample

    /// Rename a single sample parameter entry in place without touching any other fields.
    ///
    /// - Parameters:
    ///   - index:    0-based sample index (0–998)
    ///   - newName:  New name string (max 16 ASCII characters)
    ///   - entry:    Catalog entry with cluster chain
    ///   - imageURL: URL of the EMAX II disk image
    static func renameSample(
        at index: Int,
        newName: String,
        in entry: BankCatalogEntry,
        imageURL: URL
    ) throws {
        let update = SampleParamUpdate(name: newName)
        try updateSampleParam(at: index, update: update, in: entry, imageURL: imageURL)
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
