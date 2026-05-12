import XCTest
import Foundation
@testable import EmaxForge

/// Tests for EB2ParamTableBuilder — buildParamTable is a pure in-memory function,
/// no disk I/O needed. Tests cover error guards, pass-through for existing EMX
/// tables, and sample detection from high-entropy PCM data.
final class EB2ParamTableBuilderTests: XCTestCase {

    // MARK: - Helpers

    /// Read a UInt16 LE value from Data.
    private func u16(_ d: Data, at offset: Int) -> UInt16 {
        UInt16(d[offset]) | (UInt16(d[offset + 1]) << 8)
    }

    /// Read a UInt32 LE value from Data.
    private func u32(_ d: Data, at offset: Int) -> UInt32 {
        UInt32(d[offset]) |
        (UInt32(d[offset + 1]) << 8) |
        (UInt32(d[offset + 2]) << 16) |
        (UInt32(d[offset + 3]) << 24)
    }

    /// Build a buffer where the first param block at 0x10200 looks like a valid EMX entry.
    private func makeEMXBuffer(
        startAddr: UInt32 = 0,
        endAddr: UInt32 = 44100,
        sampleRate: UInt16 = 22050,
        extraPCMBytes: Int = 0
    ) -> Data {
        // Must be at least sampleParamOffset (0x10200) + sampleParamSize (0x40) bytes
        let minSize = EmaxIIFormat.sampleParamOffset + EmaxIIFormat.sampleParamSize
        let totalSize = max(minSize, minSize + extraPCMBytes)
        var data = Data(count: totalSize)

        let base = EmaxIIFormat.sampleParamOffset
        // paramStartAddr at base + 0
        data[base + 0] = UInt8(startAddr & 0xFF)
        data[base + 1] = UInt8((startAddr >> 8) & 0xFF)
        data[base + 2] = UInt8((startAddr >> 16) & 0xFF)
        data[base + 3] = UInt8((startAddr >> 24) & 0xFF)
        // paramEndAddr at base + 4
        data[base + 4] = UInt8(endAddr & 0xFF)
        data[base + 5] = UInt8((endAddr >> 8) & 0xFF)
        data[base + 6] = UInt8((endAddr >> 16) & 0xFF)
        data[base + 7] = UInt8((endAddr >> 24) & 0xFF)
        // sampleRate at base + 8
        data[base + 8]  = UInt8(sampleRate & 0xFF)
        data[base + 9]  = UInt8(sampleRate >> 8)

        return data
    }

    /// Build a buffer with repeating 0x00-0xFF PCM data at sampleDataOffset (0x20000).
    /// The repeating pattern guarantees entropy ≈ 8 bits and 256 unique byte values.
    private func makeHighEntropyBuffer(pcmByteCount: Int = 1024) -> Data {
        let dataOffset = EmaxIIFormat.sampleDataOffset  // 0x20000
        var data = Data(count: dataOffset + pcmByteCount)

        // Fill PCM area with 0x00-0xFF repeating pattern (max entropy)
        for i in 0..<pcmByteCount {
            data[dataOffset + i] = UInt8(i % 256)
        }
        return data
    }

    // MARK: - BuildError descriptions

    func testNoSamplesDetectedDescription() {
        let err = EB2ParamTableBuilder.BuildError.noSamplesDetected
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testInvalidBankFormatDescription() {
        let err = EB2ParamTableBuilder.BuildError.invalidBankFormat
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testTooManySamplesDescriptionContainsCount() {
        let err = EB2ParamTableBuilder.BuildError.tooManySamples(1200)
        XCTAssertTrue(err.errorDescription?.contains("1200") == true)
    }

    func testTooManySamplesDescriptionContainsMaxSamples() {
        let err = EB2ParamTableBuilder.BuildError.tooManySamples(5)
        let maxStr = String(EmaxIIFormat.maxSamples)
        XCTAssertTrue(err.errorDescription?.contains(maxStr) == true)
    }

    // MARK: - BuildResult struct

    func testBuildResultFieldAccess() {
        let r = EB2ParamTableBuilder.BuildResult(
            samplesDetected: 3,
            paramTableSize: 192,
            paramTableOffset: EmaxIIFormat.sampleParamOffset,
            totalBankSize: 500_000
        )
        XCTAssertEqual(r.samplesDetected, 3)
        XCTAssertEqual(r.paramTableSize, 192)
        XCTAssertEqual(r.paramTableOffset, EmaxIIFormat.sampleParamOffset)
        XCTAssertEqual(r.totalBankSize, 500_000)
    }

    func testBuildResultParamTableOffsetIsAlwaysFixed() {
        let r = EB2ParamTableBuilder.BuildResult(
            samplesDetected: 1,
            paramTableSize: 64,
            paramTableOffset: EmaxIIFormat.sampleParamOffset,
            totalBankSize: 100_000
        )
        XCTAssertEqual(r.paramTableOffset, 0x10200)
    }

    // MARK: - buildParamTable: invalidBankFormat guard

    func testBuildParamTableThrowsOnEmptyData() {
        XCTAssertThrowsError(try EB2ParamTableBuilder.buildParamTable(from: Data())) { err in
            if case .invalidBankFormat = err as! EB2ParamTableBuilder.BuildError { } else {
                XCTFail("Expected invalidBankFormat for empty Data")
            }
        }
    }

    func testBuildParamTableThrowsOnTooSmallData() {
        // EmaxIIFormat.headerSize = 0x200 = 512; anything < 512 → invalidBankFormat
        let tiny = Data(count: 100)
        XCTAssertThrowsError(try EB2ParamTableBuilder.buildParamTable(from: tiny)) { err in
            if case .invalidBankFormat = err as! EB2ParamTableBuilder.BuildError { } else {
                XCTFail("Expected invalidBankFormat for <512 byte data")
            }
        }
    }

    func testBuildParamTableThrowsOn511Bytes() {
        let data = Data(count: 511)
        XCTAssertThrowsError(try EB2ParamTableBuilder.buildParamTable(from: data)) { err in
            if case .invalidBankFormat = err as! EB2ParamTableBuilder.BuildError { } else {
                XCTFail("Expected invalidBankFormat for 511 bytes")
            }
        }
    }

    // MARK: - buildParamTable: noSamplesDetected

    func testBuildParamTableThrowsOnAllZeroBufferLargerThanHeader() throws {
        // All-zeros past 0x20000 have entropy=0 — neither detector finds samples.
        let zeros = Data(count: EmaxIIFormat.sampleDataOffset + 4096)
        XCTAssertThrowsError(try EB2ParamTableBuilder.buildParamTable(from: zeros)) { err in
            if case .noSamplesDetected = err as! EB2ParamTableBuilder.BuildError { } else {
                XCTFail("Expected noSamplesDetected for all-zeros buffer")
            }
        }
    }

    // MARK: - buildParamTable: existing EMX param table → pass-through

    func testBuildParamTablePassesThroughExistingEMXFormat() throws {
        // Buffer with a valid-looking param block at 0x10200 → hasExistingParamTable = true.
        // Should return the original data unchanged with samplesDetected from numSamples header.
        let original = makeEMXBuffer(startAddr: 0, endAddr: 44100, sampleRate: 22050)
        let (resultData, buildResult) = try EB2ParamTableBuilder.buildParamTable(from: original)

        // Data should be the same object / identical content
        XCTAssertEqual(resultData.count, original.count,
                       "Pass-through should not resize the data")
        XCTAssertEqual(buildResult.paramTableOffset, EmaxIIFormat.sampleParamOffset)
        XCTAssertEqual(buildResult.totalBankSize, original.count)
    }

    func testBuildParamTablePassThroughPreservesBytes() throws {
        var original = makeEMXBuffer(startAddr: 100, endAddr: 50000, sampleRate: 22050)
        // Write a sentinel byte somewhere in the buffer to verify identity
        original[512] = 0xAB
        let (resultData, _) = try EB2ParamTableBuilder.buildParamTable(from: original)
        XCTAssertEqual(resultData[512], 0xAB, "Pass-through must preserve all original bytes")
    }

    // MARK: - buildParamTable: high-entropy PCM → sample detection

    func testBuildParamTableDetectsSamplesFromHighEntropyPCM() throws {
        // Buffer with high-entropy repeating pattern at 0x20000; no existing param table.
        let eb2 = makeHighEntropyBuffer(pcmByteCount: 2048)
        let (_, result) = try EB2ParamTableBuilder.buildParamTable(from: eb2)

        XCTAssertGreaterThan(result.samplesDetected, 0,
                             "Should detect at least one sample from high-entropy PCM")
    }

    func testBuildParamTableOutputSizeGrowsFromDetection() throws {
        let eb2 = makeHighEntropyBuffer(pcmByteCount: 2048)
        let (output, _) = try EB2ParamTableBuilder.buildParamTable(from: eb2)

        // Output must contain at least the PCM area (0x20000) + detected param blocks
        XCTAssertGreaterThanOrEqual(output.count, EmaxIIFormat.sampleDataOffset)
    }

    func testBuildParamTableNumSamplesWrittenToHeader() throws {
        let eb2 = makeHighEntropyBuffer(pcmByteCount: 2048)
        let (output, result) = try EB2ParamTableBuilder.buildParamTable(from: eb2)

        // numSamples at EmaxIIFormat.numSamplesOffset (0x1E) should match samplesDetected
        let numSamples = Int(u16(output, at: EmaxIIFormat.numSamplesOffset))
        XCTAssertEqual(numSamples, result.samplesDetected)
    }

    func testBuildParamTableParamTableSizeEqualsDetectedTimesSampleParamSize() throws {
        let eb2 = makeHighEntropyBuffer(pcmByteCount: 2048)
        let (_, result) = try EB2ParamTableBuilder.buildParamTable(from: eb2)

        XCTAssertEqual(result.paramTableSize,
                       result.samplesDetected * EmaxIIFormat.sampleParamSize)
    }

    func testBuildParamTableParamTableOffsetIsAlways0x10200() throws {
        let eb2 = makeHighEntropyBuffer(pcmByteCount: 2048)
        let (_, result) = try EB2ParamTableBuilder.buildParamTable(from: eb2)
        XCTAssertEqual(result.paramTableOffset, 0x10200)
    }

    func testBuildParamTableOutputTotalBankSizeMatchesResult() throws {
        let eb2 = makeHighEntropyBuffer(pcmByteCount: 2048)
        let (output, result) = try EB2ParamTableBuilder.buildParamTable(from: eb2)
        XCTAssertEqual(output.count, result.totalBankSize)
    }

    func testBuildParamTableDetectedParamBlockHasReasonableSampleRate() throws {
        let eb2 = makeHighEntropyBuffer(pcmByteCount: 2048)
        let (output, result) = try EB2ParamTableBuilder.buildParamTable(from: eb2)

        guard result.samplesDetected > 0 else { return }  // skip if no detection

        // Read first param block from output
        let base = EmaxIIFormat.sampleParamOffset
        XCTAssertGreaterThanOrEqual(output.count, base + EmaxIIFormat.sampleParamSize)

        let startAddr = u32(output, at: base + EmaxIIFormat.paramStartAddr)
        let endAddr   = u32(output, at: base + EmaxIIFormat.paramEndAddr)
        let rate      = u16(output, at: base + EmaxIIFormat.paramSampleRate)

        XCTAssertLessThan(startAddr, endAddr, "Detected param block: startAddr must be < endAddr")
        XCTAssertGreaterThanOrEqual(rate, 8_000, "Sample rate must be ≥ 8000 Hz")
        XCTAssertLessThanOrEqual(rate, 50_000, "Sample rate must be ≤ 50000 Hz")
    }

    func testBuildParamTableDetectedParamBlockNameStartsWithSAMPLE() throws {
        let eb2 = makeHighEntropyBuffer(pcmByteCount: 2048)
        let (output, result) = try EB2ParamTableBuilder.buildParamTable(from: eb2)

        guard result.samplesDetected > 0 else { return }

        let base = EmaxIIFormat.sampleParamOffset + EmaxIIFormat.paramName
        XCTAssertGreaterThanOrEqual(output.count, base + 7)
        let nameBytes = output[base..<(base + 7)]
        let name = String(bytes: nameBytes, encoding: .ascii) ?? ""
        XCTAssertTrue(name.hasPrefix("SAMPLE "), "Auto-generated name should start with 'SAMPLE '")
    }
}
