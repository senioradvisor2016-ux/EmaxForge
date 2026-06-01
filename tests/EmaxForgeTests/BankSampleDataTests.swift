import XCTest
import Foundation
@testable import EmaxForge

// MARK: - BankSampleData.extractSampleData

/// Tests for BankSampleData.extractSampleData(from:) and BankSampleData.detectBankFormat().
///
/// These tests exercise the EMX-format sample parameter parsing, including
/// the originalKey field that was historically hardcoded to 60+(i%12) instead
/// of being read from the stored byte at param +0x0A.
final class BankSampleDataExtractionTests: XCTestCase {

    // MARK: - Helpers

    /// Build the minimum EMX-format bank buffer that detectBankFormat() recognises as .emx.
    ///
    /// Layout:
    ///   0x0000–0x01FF : header (numPresets @ 0x1C, numSamples @ 0x1E)
    ///   0x10200–0x1023F: sample param block 0 (64 bytes)
    ///   0x20000–…      : sample PCM data
    private func makeEMXBuffer(
        numPresets: UInt16 = 1,
        numSamples: UInt16 = 1,
        sampleRate: UInt16 = 39063,
        originalKey: UInt8 = 60,
        loopStart: UInt32 = 0,
        loopEnd: UInt32 = 0,
        loopFlags: UInt8 = 0x00,   // +0x1C: bit0=sustainEnabled
        sampleName: String = "KICK",
        pcmFrames: Int = 500      // frames (each frame = 2 bytes, 16-bit)
    ) -> Data {
        let pcmBytes = pcmFrames * 2
        let totalSize = EmaxIIFormat.sampleDataOffset + pcmBytes  // 0x20000 + pcmBytes
        var buf = Data(count: totalSize)

        // --- Header ---
        // numPresets at 0x1C
        buf.writeU16LE(numPresets, at: EmaxIIFormat.numPresetsOffset)   // 0x1C
        // numSamples at 0x1E
        buf.writeU16LE(numSamples, at: EmaxIIFormat.numSamplesOffset)   // 0x1E

        // --- Sample parameter block 0 at 0x10200 ---
        let base = EmaxIIFormat.sampleParamOffset                        // 0x10200
        // startAddress = 0 (relative to sample data area)
        buf.writeU32LE(0, at: base + EmaxIIFormat.paramStartAddr)        // +0x00
        // endAddress = pcmBytes
        buf.writeU32LE(UInt32(pcmBytes), at: base + EmaxIIFormat.paramEndAddr)  // +0x04
        // sampleRate
        buf.writeU16LE(sampleRate, at: base + EmaxIIFormat.paramSampleRate)     // +0x08
        // originalKey — the field that was previously hardcoded
        buf[base + EmaxIIFormat.paramOriginalKey] = originalKey                  // +0x0A
        // loopStart
        buf.writeU32LE(loopStart, at: base + EmaxIIFormat.paramSustainLoopStart) // +0x0C
        // loopEnd
        buf.writeU32LE(loopEnd,   at: base + EmaxIIFormat.paramSustainLoopEnd)   // +0x10
        // loopFlags — bit0=sustainEnabled, bit1=releaseEnabled, bit2=backward
        buf[base + EmaxIIFormat.paramLoopFlags] = loopFlags                       // +0x1C
        // name at +0x20
        let nameData = sampleName.prefix(16).data(using: .ascii) ?? Data()
        for (i, byte) in nameData.enumerated() where i < 16 {
            buf[base + EmaxIIFormat.paramName + i] = byte                        // +0x20
        }

        // --- PCM data at 0x20000 (random noise so entropy detection also works) ---
        for i in 0..<pcmBytes {
            buf[EmaxIIFormat.sampleDataOffset + i] = UInt8((i * 37 + 13) % 256)
        }

        return buf
    }

    // MARK: - detectBankFormat

    func testDetectBankFormatReturnEMXForValidEMXBuffer() {
        let buf = makeEMXBuffer()
        XCTAssertEqual(EmaxIIParser.detectBankFormat(buf), .emx)
    }

    func testDetectBankFormatReturnEB2ForTooSmallBuffer() {
        // Buffer smaller than 0x10200 + 0x40 → eb2
        let buf = Data(count: 0x1000)
        XCTAssertEqual(EmaxIIParser.detectBankFormat(buf), .eb2)
    }

    // MARK: - extractSampleData: EMX path

    func testExtractSampleDataReturnsNonNilForValidEMXBuffer() {
        let buf = makeEMXBuffer()
        XCTAssertNotNil(EmaxIIParser.extractSampleData(from: buf))
    }

    func testExtractSampleDataReturnsNilForTooSmallBuffer() {
        // Buffer smaller than headerSize (0x200) → nil
        XCTAssertNil(EmaxIIParser.extractSampleData(from: Data(count: 100)))
    }

    // MARK: - originalKey fix (regression for hardcoded 60+(i%12))

    func testOriginalKeyIsReadFromParamBlockNotHardcoded() {
        // Store originalKey = 67 (G4) in the param block
        let buf = makeEMXBuffer(originalKey: 67)
        guard let bankData = EmaxIIParser.extractSampleData(from: buf),
              let entry = bankData.samples.first else {
            XCTFail("Failed to extract sample data from EMX buffer")
            return
        }
        XCTAssertEqual(entry.rootKey, 67,
                       "rootKey must be read from param +0x0A (67 = G4), not hardcoded to 60+(i%12)")
    }

    func testOriginalKeyA4IsPreserved() {
        let buf = makeEMXBuffer(originalKey: 69)  // A4
        guard let entry = EmaxIIParser.extractSampleData(from: buf)?.samples.first else {
            XCTFail("Expected at least one sample entry"); return
        }
        XCTAssertEqual(entry.rootKey, 69, "A4 (MIDI 69) must survive the param round-trip")
    }

    func testOriginalKeyMiddleCIsPreserved() {
        let buf = makeEMXBuffer(originalKey: 60)  // C4
        guard let entry = EmaxIIParser.extractSampleData(from: buf)?.samples.first else {
            XCTFail("Expected at least one sample entry"); return
        }
        XCTAssertEqual(entry.rootKey, 60, "C4 (MIDI 60) must survive the param round-trip")
    }

    func testOriginalKeyZeroFallsBackToC4() {
        // 0 is treated as "unset" → default C4 (60)
        let buf = makeEMXBuffer(originalKey: 0)
        guard let entry = EmaxIIParser.extractSampleData(from: buf)?.samples.first else {
            XCTFail("Expected at least one sample entry"); return
        }
        XCTAssertEqual(entry.rootKey, 60,
                       "originalKey=0 should default to C4 (60), as 0 means unset")
    }

    func testOriginalKey127IsMaximumValidMIDINote() {
        let buf = makeEMXBuffer(originalKey: 127)  // MIDI max
        guard let entry = EmaxIIParser.extractSampleData(from: buf)?.samples.first else {
            XCTFail("Expected at least one sample entry"); return
        }
        XCTAssertEqual(entry.rootKey, 127, "MIDI 127 is valid and must be preserved")
    }

    // MARK: - sampleRate parsing

    func testSampleRateIsReadFromParamBlock() {
        let buf = makeEMXBuffer(sampleRate: 22050)
        guard let entry = EmaxIIParser.extractSampleData(from: buf)?.samples.first else {
            XCTFail("Expected at least one sample entry"); return
        }
        XCTAssertEqual(entry.sampleRate, 22050)
    }

    func testSampleRateDefaultsTo39063ForInvalidRate() {
        // Rate < 8000 → fallback to EmaxIIFormat.defaultSampleRate
        let buf = makeEMXBuffer(sampleRate: 100)
        guard let entry = EmaxIIParser.extractSampleData(from: buf)?.samples.first else {
            XCTFail("Expected at least one sample entry"); return
        }
        XCTAssertEqual(entry.sampleRate, EmaxIIFormat.defaultSampleRate)
    }

    // MARK: - sample name parsing

    func testSampleNameIsReadFromParamBlock() {
        let buf = makeEMXBuffer(sampleName: "BASS")
        guard let entry = EmaxIIParser.extractSampleData(from: buf)?.samples.first else {
            XCTFail("Expected at least one sample entry"); return
        }
        XCTAssertEqual(entry.name, "BASS")
    }

    // MARK: - loop point parsing

    func testLoopEndGreaterThanLoopStartMeansHasLoop() {
        // loopFlags bit0 (sustainEnabled) must be set for looping to activate
        let buf = makeEMXBuffer(loopStart: 100, loopEnd: 400, loopFlags: 0x01, pcmFrames: 500)
        guard let entry = EmaxIIParser.extractSampleData(from: buf)?.samples.first else {
            XCTFail("Expected at least one sample entry"); return
        }
        XCTAssertNotNil(entry.loopStart, "loopStart should be set when loopEnd > loopStart and sustainBit=1")
        XCTAssertNotNil(entry.loopEnd,   "loopEnd should be set when loopEnd > loopStart and sustainBit=1")
    }

    func testLoopFlagsZeroWithValidAddressesGivesNoLoop() {
        // Even with valid loop addresses, loopFlags=0 means no loop (sustainBit not set)
        let buf = makeEMXBuffer(loopStart: 100, loopEnd: 400, loopFlags: 0x00, pcmFrames: 500)
        guard let entry = EmaxIIParser.extractSampleData(from: buf)?.samples.first else {
            XCTFail("Expected at least one sample entry"); return
        }
        XCTAssertNil(entry.loopStart, "loopStart should be nil when sustainBit=0 (loop disabled by flags)")
        XCTAssertNil(entry.loopEnd,   "loopEnd should be nil when sustainBit=0 (loop disabled by flags)")
    }

    func testLoopEndZeroMeansNoLoop() {
        let buf = makeEMXBuffer(loopStart: 0, loopEnd: 0, loopFlags: 0x00)
        guard let entry = EmaxIIParser.extractSampleData(from: buf)?.samples.first else {
            XCTFail("Expected at least one sample entry"); return
        }
        XCTAssertNil(entry.loopStart, "loopStart should be nil when loopEnd=0 (no loop)")
        XCTAssertNil(entry.loopEnd,   "loopEnd should be nil when loopEnd=0 (no loop)")
    }
}

// MARK: - Data write helpers (local to this test file)

private extension Data {
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
