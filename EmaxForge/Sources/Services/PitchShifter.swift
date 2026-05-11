import Foundation

/// Offline pitch-shifting for EMAX II samples.
///
/// The EMAX II does not perform digital pitch-shifting — it controls pitch exclusively
/// through the playback sample rate. Changing the stored sample rate is therefore the
/// correct way to permanently shift a sample's pitch.
///
/// Supported rates (Ghidra-verified against EMXP FUN_00503580 rate table):
///   10000, 15625, 20000, 22050, 27778, 31250, 39063, 41667, 44100 Hz
///
/// Semitone formula: newRate = currentRate × 2^(semitones / 12)
/// The nearest supported rate is selected after the computation.
enum PitchShifter {

    // MARK: - Constants

    /// All sample rates supported by the EMAX II hardware, in ascending order.
    /// Verified against EMXP v3.11.4 rate enumeration (Ghidra FUN_00503580).
    static let supportedRates: [UInt16] = [
        10000, 15625, 20000, 22050, 27778, 31250, 39063, 41667, 44100
    ]

    // MARK: - Errors

    enum ShiftError: LocalizedError {
        case semitonesOutOfRange(Double)    // only ±24 semitones allowed
        case unsupportedRate(UInt16)        // rate not in supportedRates
        case bankFormatNotSupported         // EB2 without param table
        case sampleIndexOutOfRange(Int)
        case underlyingError(Error)

        var errorDescription: String? {
            switch self {
            case .semitonesOutOfRange(let s):
                return "Semitone shift \(s) is out of range (±24 semitones maximum)"
            case .unsupportedRate(let r):
                return "Sample rate \(r) Hz is not supported by the EMAX II hardware"
            case .bankFormatNotSupported:
                return "Bank is in EB2 format without a sample parameter table — convert to EMX first"
            case .sampleIndexOutOfRange(let i):
                return "Sample index \(i) is out of range"
            case .underlyingError(let e):
                return e.localizedDescription
            }
        }
    }

    // MARK: - Result

    struct ShiftResult {
        let sampleIndex: Int
        let originalRate: UInt16
        let newRate: UInt16
        /// Actual semitone shift achieved (may differ slightly from requested due to quantisation).
        let actualSemitones: Double
    }

    // MARK: - API

    /// Shift a sample's pitch by the given number of semitones.
    ///
    /// Positive = higher pitch (raise), negative = lower pitch (lower).
    /// The nearest EMAX II–supported rate is selected.
    ///
    /// - Parameters:
    ///   - semitones: Desired shift in semitones (±24 max).
    ///   - sampleIndex: 0-based index in the bank's sample parameter table.
    ///   - bankEntry: The `BankCatalogEntry` whose cluster chain to update.
    ///   - imageURL: URL of the HD disk image.
    @discardableResult
    static func shiftBySemitones(
        _ semitones: Double,
        sampleIndex: Int,
        in bankEntry: BankCatalogEntry,
        imageURL: URL
    ) throws -> ShiftResult {
        guard abs(semitones) <= 24 else {
            throw ShiftError.semitonesOutOfRange(semitones)
        }
        guard sampleIndex >= 0 else {
            throw ShiftError.sampleIndexOutOfRange(sampleIndex)
        }

        // Read current rate from sample param entry +0x08
        let currentRate = try readCurrentRate(sampleIndex: sampleIndex,
                                              bankEntry: bankEntry,
                                              imageURL: imageURL)

        // Compute target rate: f_new = f_cur × 2^(semitones/12)
        let factor = pow(2.0, semitones / 12.0)
        let targetHz = Double(currentRate) * factor

        // Snap to nearest supported rate
        let newRate = nearestSupportedRate(to: targetHz)
        let actualSemitones = 12.0 * log2(Double(newRate) / Double(currentRate))

        // Write back via SampleParamWriteService
        do {
            let update = SampleParamWriteService.SampleParamUpdate(sampleRate: newRate)
            try SampleParamWriteService.updateSampleParam(
                at: sampleIndex,
                update: update,
                in: bankEntry,
                imageURL: imageURL
            )
        } catch {
            throw ShiftError.underlyingError(error)
        }

        return ShiftResult(
            sampleIndex: sampleIndex,
            originalRate: currentRate,
            newRate: newRate,
            actualSemitones: actualSemitones
        )
    }

    /// Set an explicit sample rate (overrides whatever is currently stored).
    ///
    /// Passing an unsupported rate throws `ShiftError.unsupportedRate`.
    @discardableResult
    static func setSampleRate(
        _ newRate: UInt16,
        sampleIndex: Int,
        in bankEntry: BankCatalogEntry,
        imageURL: URL
    ) throws -> ShiftResult {
        guard supportedRates.contains(newRate) else {
            throw ShiftError.unsupportedRate(newRate)
        }
        guard sampleIndex >= 0 else {
            throw ShiftError.sampleIndexOutOfRange(sampleIndex)
        }

        let currentRate = try readCurrentRate(sampleIndex: sampleIndex,
                                              bankEntry: bankEntry,
                                              imageURL: imageURL)

        let actualSemitones = currentRate > 0
            ? 12.0 * log2(Double(newRate) / Double(currentRate))
            : 0.0

        do {
            let update = SampleParamWriteService.SampleParamUpdate(sampleRate: newRate)
            try SampleParamWriteService.updateSampleParam(
                at: sampleIndex,
                update: update,
                in: bankEntry,
                imageURL: imageURL
            )
        } catch {
            throw ShiftError.underlyingError(error)
        }

        return ShiftResult(
            sampleIndex: sampleIndex,
            originalRate: currentRate,
            newRate: newRate,
            actualSemitones: actualSemitones
        )
    }

    // MARK: - Helpers

    /// Read sample rate (U16 LE at param +0x08) directly from the cluster chain.
    private static func readCurrentRate(
        sampleIndex: Int,
        bankEntry: BankCatalogEntry,
        imageURL: URL
    ) throws -> UInt16 {
        let geo = try BankDataWriter.loadGeometry(from: imageURL)
        let bankData = try BankDataWriter.readBankData(entry: bankEntry,
                                                       from: imageURL,
                                                       geometry: geo)
        // Sample param area starts at 0x10200; each entry is 0x40 bytes; rate at +0x08
        let base = 0x10200 + sampleIndex * 0x40
        guard base + 0x0A <= bankData.count else {
            throw ShiftError.sampleIndexOutOfRange(sampleIndex)
        }
        return bankData.readU16LE(at: base + 0x08)   // param +0x08: sampleRate
    }

    /// Return the element of `supportedRates` whose value is closest to `hz`.
    private static func nearestSupportedRate(to hz: Double) -> UInt16 {
        supportedRates.min(by: { abs(Double($0) - hz) < abs(Double($1) - hz) }) ?? 22050
    }
}

// MARK: - Data helper (private)

private extension Data {
    func readU16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return withUnsafeBytes { ptr in
            ptr.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt16.self)
        }
    }
}
