import XCTest
import Foundation
@testable import EmaxForge

/// Unit tests for SampleConverter — EB2 bank building and error handling.
///
/// All tests are AVFoundation-free: error-guard tests pass fake URLs (checks
/// fire before any file I/O), and buildEB2Bank tests use directly-constructed
/// LoadedSample values (no audio files required).
final class SampleConverterTests: XCTestCase {

    // MARK: - Helpers

    /// Make a minimal LoadedSample with specified MIDI key range and PCM data.
    private func makeSample(
        name: String = "TESTSAMPLE  ",
        pcmBytes: Int = 100,
        lowKey: UInt8 = 0,
        highKey: UInt8 = 127,
        rootKey: UInt8 = 60
    ) -> SampleConverter.LoadedSample {
        SampleConverter.LoadedSample(
            name: name,
            pcmData: Data(repeating: 0, count: pcmBytes),
            originalSampleRate: 22050,
            lowKey: lowKey,
            highKey: highKey,
            rootKey: rootKey
        )
    }

    /// Read a UInt16 little-endian value from Data at `offset`.
    private func u16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    /// Read a UInt32 little-endian value from Data at `offset`.
    private func u32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) |
        (UInt32(data[offset + 1]) << 8) |
        (UInt32(data[offset + 2]) << 16) |
        (UInt32(data[offset + 3]) << 24)
    }

    // MARK: - ConvertError descriptions

    func testUnsupportedFormatDescription() {
        let err = SampleConverter.ConvertError.unsupportedFormat("xyz")
        XCTAssertTrue(err.errorDescription?.contains("xyz") == true)
    }

    func testReadErrorDescription() {
        let err = SampleConverter.ConvertError.readError("disk full")
        XCTAssertTrue(err.errorDescription?.contains("disk full") == true)
    }

    func testEmptyInputDescription() {
        let err = SampleConverter.ConvertError.emptyInput
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testTooManySamplesDescription() {
        let err = SampleConverter.ConvertError.tooManySamples
        XCTAssertTrue(err.errorDescription?.contains("16") == true)
    }

    func testSampleTooLargeDescription() {
        let err = SampleConverter.ConvertError.sampleTooLarge("BigSample")
        XCTAssertTrue(err.errorDescription?.contains("BigSample") == true)
    }

    func testConversionFailedDescription() {
        let err = SampleConverter.ConvertError.conversionFailed("bad buffer")
        XCTAssertTrue(err.errorDescription?.contains("bad buffer") == true)
    }

    // MARK: - supportedExtensions

    func testSupportedExtensionsContainsWAV() {
        XCTAssertTrue(SampleConverter.supportedExtensions.contains("wav"))
    }

    func testSupportedExtensionsContainsAIFF() {
        XCTAssertTrue(SampleConverter.supportedExtensions.contains("aiff"))
    }

    func testSupportedExtensionsContainsAIF() {
        XCTAssertTrue(SampleConverter.supportedExtensions.contains("aif"))
    }

    func testSupportedExtensionsNonEmpty() {
        XCTAssertGreaterThan(SampleConverter.supportedExtensions.count, 0)
    }

    // MARK: - LoadedSample struct

    func testLoadedSampleFieldAccess() {
        let s = makeSample(name: "KICK        ", pcmBytes: 200, lowKey: 48, highKey: 72, rootKey: 60)
        XCTAssertEqual(s.name, "KICK        ")
        XCTAssertEqual(s.pcmData.count, 200)
        XCTAssertEqual(s.originalSampleRate, 22050)
        XCTAssertEqual(s.lowKey, 48)
        XCTAssertEqual(s.highKey, 72)
        XCTAssertEqual(s.rootKey, 60)
    }

    // MARK: - loadMultiSamples error guards (no file I/O)

    func testLoadMultiSamplesThrowsOnEmptyURLArray() {
        XCTAssertThrowsError(try SampleConverter.loadMultiSamples(urls: [])) { err in
            XCTAssertTrue(err is SampleConverter.ConvertError)
            if case .emptyInput = err as! SampleConverter.ConvertError { } else {
                XCTFail("Expected emptyInput, got \(err)")
            }
        }
    }

    func testLoadMultiSamplesThrowsOnSeventeenURLs() {
        // Guard fires before any loadAudioFile call — fake URLs are fine.
        let urls = (0..<17).map { URL(fileURLWithPath: "/dev/null/fake_\($0).wav") }
        XCTAssertThrowsError(try SampleConverter.loadMultiSamples(urls: urls)) { err in
            if case .tooManySamples = err as! SampleConverter.ConvertError { } else {
                XCTFail("Expected tooManySamples, got \(err)")
            }
        }
    }

    func testLoadMultiSamplesSixteenURLsPassesGuard() {
        // With exactly 16 URLs the guard passes (will then throw readError from AVFoundation,
        // NOT tooManySamples). We verify the error is NOT tooManySamples.
        let urls = (0..<16).map { URL(fileURLWithPath: "/dev/null/fake_\($0).wav") }
        XCTAssertThrowsError(try SampleConverter.loadMultiSamples(urls: urls)) { err in
            if case .tooManySamples = err as! SampleConverter.ConvertError {
                XCTFail("16 URLs should pass the tooManySamples guard")
            }
        }
    }

    // MARK: - buildEB2Bank error guards

    func testBuildEB2BankThrowsOnEmptySamples() {
        XCTAssertThrowsError(try SampleConverter.buildEB2Bank(bankName: "EMPTY", samples: [])) { err in
            if case .emptyInput = err as! SampleConverter.ConvertError { } else {
                XCTFail("Expected emptyInput")
            }
        }
    }

    func testBuildEB2BankThrowsOnSeventeenSamples() {
        let samples = (0..<17).map { makeSample(name: "S\($0)          ".prefix(12) + "", pcmBytes: 10) }
        XCTAssertThrowsError(try SampleConverter.buildEB2Bank(bankName: "X", samples: samples)) { err in
            if case .tooManySamples = err as! SampleConverter.ConvertError { } else {
                XCTFail("Expected tooManySamples")
            }
        }
    }

    func testBuildEB2BankAcceptsSixteenSamples() throws {
        let samples = (0..<16).map { makeSample(pcmBytes: 10 * ($0 + 1)) }
        let data = try SampleConverter.buildEB2Bank(bankName: "SIXTEEN", samples: samples)
        XCTAssertFalse(data.isEmpty)
    }

    // MARK: - buildEB2Bank: output basics

    func testBuildEB2BankOneSampleProducesNonEmptyData() throws {
        let data = try SampleConverter.buildEB2Bank(bankName: "TEST", samples: [makeSample(pcmBytes: 100)])
        XCTAssertFalse(data.isEmpty)
    }

    func testBuildEB2BankOutputIsEvenLength() throws {
        // Bank must be padded to an even byte boundary
        for pcmBytes in [99, 100, 101, 200] {
            let data = try SampleConverter.buildEB2Bank(bankName: "PAD", samples: [makeSample(pcmBytes: pcmBytes)])
            XCTAssertEqual(data.count % 2, 0, "Output must be even-length for pcmBytes=\(pcmBytes)")
        }
    }

    func testBuildEB2BankOutputSizeIncludesPCMData() throws {
        let pcm = 400
        let data = try SampleConverter.buildEB2Bank(bankName: "SIZES", samples: [makeSample(pcmBytes: pcm)])
        // Minimum header is 0x1B8 = 440 bytes; total must be larger than that
        XCTAssertGreaterThan(data.count, 0x1B8 + pcm)
    }

    // MARK: - buildEB2Bank: bank name

    func testBankNameWrittenAt0x1AC() throws {
        let data = try SampleConverter.buildEB2Bank(bankName: "MYBANK", samples: [makeSample()])
        let nameBytes = data[0x1AC..<0x1B8]
        let name = String(bytes: nameBytes, encoding: .ascii) ?? ""
        XCTAssertTrue(name.hasPrefix("MYBANK"), "Bank name should start at 0x1AC")
    }

    func testBankNamePaddedWithSpacesToTwelveBytes() throws {
        let data = try SampleConverter.buildEB2Bank(bankName: "AB", samples: [makeSample()])
        let nameBytes = data[0x1AC..<0x1B8]
        XCTAssertEqual(nameBytes.count, 12)
        // First two bytes: 'A' and 'B'
        XCTAssertEqual(nameBytes[nameBytes.startIndex], UInt8(ascii: "A"))
        XCTAssertEqual(nameBytes[nameBytes.startIndex + 1], UInt8(ascii: "B"))
        // Remaining 10 bytes should be space (0x20)
        for i in 2..<12 {
            XCTAssertEqual(nameBytes[nameBytes.startIndex + i], 0x20,
                           "Byte \(i) of padded name should be space")
        }
    }

    func testBankNameTruncatedAtTwelveChars() throws {
        let longName = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let data = try SampleConverter.buildEB2Bank(bankName: longName, samples: [makeSample()])
        let nameBytes = data[0x1AC..<0x1B8]
        let name = String(bytes: nameBytes, encoding: .ascii) ?? ""
        XCTAssertEqual(name, "ABCDEFGHIJKL", "Name must be truncated to 12 chars")
    }

    func testBankNameExactlyTwelveCharsStoredVerbatim() throws {
        let name12 = "DRUM KIT 001"
        let data = try SampleConverter.buildEB2Bank(bankName: name12, samples: [makeSample()])
        let nameBytes = data[0x1AC..<0x1B8]
        let stored = String(bytes: nameBytes, encoding: .ascii) ?? ""
        XCTAssertEqual(stored, name12)
    }

    // MARK: - buildEB2Bank: metadata block

    func testSampleEndAddrAtOffset0x1A0() throws {
        let pcm = 200
        let data = try SampleConverter.buildEB2Bank(bankName: "X", samples: [makeSample(pcmBytes: pcm)])
        let sampleEndAddr = u32(data, at: 0x1A0)
        // Expected: pcmBytes + 0x200
        XCTAssertEqual(sampleEndAddr, UInt32(pcm + 0x200))
    }

    func testPresetEndAddrAtOffset0x1A4() throws {
        let pcm = 200
        let data = try SampleConverter.buildEB2Bank(bankName: "X", samples: [makeSample(pcmBytes: pcm)])
        let sampleEndAddr = u32(data, at: 0x1A0)
        let presetEndAddr = u32(data, at: 0x1A4)
        XCTAssertEqual(presetEndAddr, sampleEndAddr + 32)
    }

    func testVoiceBlockSizeAtOffset0x1A8OneSample() throws {
        let data = try SampleConverter.buildEB2Bank(bankName: "X", samples: [makeSample()])
        let voiceBlockSize = u32(data, at: 0x1A8)
        XCTAssertEqual(voiceBlockSize, 1 * 32, "1 zone × 32 bytes")
    }

    func testVoiceBlockSizeAtOffset0x1A8FourSamples() throws {
        let samples = (0..<4).map { _ in makeSample() }
        let data = try SampleConverter.buildEB2Bank(bankName: "X", samples: samples)
        let voiceBlockSize = u32(data, at: 0x1A8)
        XCTAssertEqual(voiceBlockSize, 4 * 32, "4 zones × 32 bytes")
    }

    // MARK: - buildEB2Bank: preset header

    func testPresetHeaderMarkerByte() throws {
        // Preset header at 0x1B8, byte[0] = 0x41 ('A')
        let data = try SampleConverter.buildEB2Bank(bankName: "X", samples: [makeSample()])
        XCTAssertEqual(data[0x1B8], 0x41, "Preset marker must be 'A' (0x41)")
    }

    func testPresetHeaderVolumeByte() throws {
        // Preset header byte[3] = 99
        let data = try SampleConverter.buildEB2Bank(bankName: "X", samples: [makeSample()])
        XCTAssertEqual(data[0x1B8 + 3], 99, "Default preset volume should be 99")
    }

    // MARK: - buildEB2Bank: key pointer table

    func testKeyPointerTableFilledWithRAMBase() throws {
        // All 101 entries (0x000–0xC9) contain 0x0200 (sampleRAMBase)
        let data = try SampleConverter.buildEB2Bank(bankName: "X", samples: [makeSample()])
        for i in stride(from: 0, to: 0xCA, by: 2) {
            XCTAssertEqual(u16(data, at: i), 0x0200,
                           "Key pointer at offset \(i) should be 0x0200")
        }
    }

    // MARK: - buildEB2Bank: sample data appended

    func testSamplePCMAppearsInOutput() throws {
        // Use a distinctive pattern so we can find it in the output
        var pcm = Data(count: 10)
        pcm[0] = 0xDE; pcm[1] = 0xAD
        pcm[2] = 0xBE; pcm[3] = 0xEF
        let sample = SampleConverter.LoadedSample(
            name: "PATTERN     ",
            pcmData: pcm,
            originalSampleRate: 22050,
            lowKey: 0, highKey: 127, rootKey: 60
        )
        let data = try SampleConverter.buildEB2Bank(bankName: "X", samples: [sample])
        // The pattern 0xDE 0xAD 0xBE 0xEF must appear somewhere after the fixed header
        let pattern: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
        let dataBytes = [UInt8](data)
        let found = dataBytes.windows(ofCount: 4).contains { Array($0) == pattern }
        XCTAssertTrue(found, "PCM pattern should appear in EB2 output")
    }

    func testTwoSamplesPCMBothAppended() throws {
        var pcm1 = Data(count: 4); pcm1[0] = 0x11; pcm1[1] = 0x22
        var pcm2 = Data(count: 4); pcm2[0] = 0xAA; pcm2[1] = 0xBB

        let s1 = SampleConverter.LoadedSample(name: "FIRST       ", pcmData: pcm1,
            originalSampleRate: 22050, lowKey: 0, highKey: 63, rootKey: 32)
        let s2 = SampleConverter.LoadedSample(name: "SECOND      ", pcmData: pcm2,
            originalSampleRate: 22050, lowKey: 64, highKey: 127, rootKey: 96)

        let data = try SampleConverter.buildEB2Bank(bankName: "TWO", samples: [s1, s2])
        let dataBytes = [UInt8](data)

        let pat1: [UInt8] = [0x11, 0x22]
        let pat2: [UInt8] = [0xAA, 0xBB]
        XCTAssertTrue(dataBytes.windows(ofCount: 2).contains { Array($0) == pat1 }, "First sample PCM must appear")
        XCTAssertTrue(dataBytes.windows(ofCount: 2).contains { Array($0) == pat2 }, "Second sample PCM must appear")
    }

    // MARK: - buildEB2Bank: output grows with sample count

    func testOutputSizeGrowsWithAdditionalSamples() throws {
        let one   = try SampleConverter.buildEB2Bank(bankName: "A", samples: [makeSample(pcmBytes: 100)])
        let two   = try SampleConverter.buildEB2Bank(bankName: "A", samples: [makeSample(pcmBytes: 100), makeSample(pcmBytes: 100)])
        let three = try SampleConverter.buildEB2Bank(bankName: "A", samples: [makeSample(pcmBytes: 100), makeSample(pcmBytes: 100), makeSample(pcmBytes: 100)])
        XCTAssertLessThan(one.count, two.count, "Two-sample bank must be larger than one-sample")
        XCTAssertLessThan(two.count, three.count, "Three-sample bank must be larger than two-sample")
    }

    func testOutputSizeGrowsWithLargerPCMData() throws {
        let small = try SampleConverter.buildEB2Bank(bankName: "A", samples: [makeSample(pcmBytes: 100)])
        let large = try SampleConverter.buildEB2Bank(bankName: "A", samples: [makeSample(pcmBytes: 5000)])
        XCTAssertLessThan(small.count, large.count)
    }

    // MARK: - buildEB2Bank: sampleEndAddr reflects total PCM

    func testSampleEndAddrReflectsTotalPCMForTwoSamples() throws {
        let pcm1 = 300
        let pcm2 = 500
        let samples = [makeSample(pcmBytes: pcm1), makeSample(pcmBytes: pcm2)]
        let data = try SampleConverter.buildEB2Bank(bankName: "X", samples: samples)
        let sampleEndAddr = u32(data, at: 0x1A0)
        XCTAssertEqual(sampleEndAddr, UInt32(pcm1 + pcm2 + 0x200))
    }
}

// MARK: - Sliding window helper (no stdlib dependency)

private extension Array {
    /// Returns a lazy sequence of consecutive sub-arrays of the given size.
    func windows(ofCount n: Int) -> [[Element]] {
        guard n <= count else { return [] }
        return (0...(count - n)).map { Array(self[$0..<$0 + n]) }
    }
}
