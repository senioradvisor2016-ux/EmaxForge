import XCTest
import Foundation
@testable import EmaxForge

// MARK: - SampleExtractor (Utilities/SampleExtractor.swift)

/// Tests for SampleExtractor — ExtractionResult computed properties and
/// ExtractionError descriptions. No disk I/O needed.
final class SampleExtractorUtilityTests: XCTestCase {

    // MARK: - ExtractionResult

    private func makeResult(
        samplesExtracted: Int = 3,
        totalSize: Int64 = 1_048_576,
        errors: [String] = []
    ) -> SampleExtractor.ExtractionResult {
        SampleExtractor.ExtractionResult(
            samplesExtracted: samplesExtracted,
            totalSize: totalSize,
            destinationURL: URL(fileURLWithPath: "/tmp/samples"),
            errors: errors
        )
    }

    func testSuccessTrueWhenNoErrors() {
        XCTAssertTrue(makeResult(errors: []).success)
    }

    func testSuccessFalseWhenErrorsPresent() {
        XCTAssertFalse(makeResult(errors: ["write failed"]).success)
    }

    func testFormattedSizeIsNonEmpty() {
        XCTAssertFalse(makeResult(totalSize: 1_048_576).formattedSize.isEmpty)
    }

    func testSamplesExtractedField() {
        XCTAssertEqual(makeResult(samplesExtracted: 5).samplesExtracted, 5)
    }

    func testDestinationURLField() {
        let r = makeResult()
        XCTAssertEqual(r.destinationURL.path, "/tmp/samples")
    }

    func testErrorsFieldAccess() {
        let r = makeResult(errors: ["error1", "error2"])
        XCTAssertEqual(r.errors.count, 2)
        XCTAssertEqual(r.errors[0], "error1")
    }

    // MARK: - ExtractionError descriptions

    func testInvalidBankFormatDescription() {
        let err = SampleExtractor.ExtractionError.invalidBankFormat
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
        XCTAssertTrue(err.errorDescription?.contains("bank") == true ||
                      err.errorDescription?.contains("Bank") == true)
    }

    func testInvalidImageFormatDescription() {
        let err = SampleExtractor.ExtractionError.invalidImageFormat
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
        XCTAssertTrue(err.errorDescription?.contains("image") == true ||
                      err.errorDescription?.contains("Image") == true)
    }

    func testBankNotFoundDescriptionContainsName() {
        let err = SampleExtractor.ExtractionError.bankNotFound("PIANO")
        XCTAssertTrue(err.errorDescription?.contains("PIANO") == true)
    }

    func testCorruptedClusterChainDescription() {
        let err = SampleExtractor.ExtractionError.corruptedClusterChain
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testWriteErrorDescriptionContainsPath() {
        let url = URL(fileURLWithPath: "/tmp/out.wav")
        let err = SampleExtractor.ExtractionError.writeError(url)
        XCTAssertTrue(err.errorDescription?.contains("/tmp/out.wav") == true)
    }

    func testAllExtractionErrorsHaveNonEmptyDescriptions() {
        let errors: [SampleExtractor.ExtractionError] = [
            .invalidBankFormat,
            .invalidImageFormat,
            .bankNotFound("TEST"),
            .corruptedClusterChain,
            .writeError(URL(fileURLWithPath: "/x"))
        ]
        for err in errors {
            XCTAssertFalse(err.errorDescription?.isEmpty ?? true,
                           "Empty description for \(err)")
        }
    }
}

// MARK: - InstrumentPlayer.LoadedSample

/// Tests for InstrumentPlayer.LoadedSample — pure struct, no audio hardware.
final class InstrumentPlayerLoadedSampleTests: XCTestCase {

    private func makeSample(frames: Int = 100, sampleRate: Int = 22050) -> InstrumentPlayer.LoadedSample {
        InstrumentPlayer.LoadedSample(
            name: "BASS",
            pcmData: Data(count: frames * 2),  // 16-bit = 2 bytes/frame
            sampleRate: sampleRate,
            rootKey: 48,  // C3
            loopStart: nil,
            loopEnd: nil
        )
    }

    func testFrameCountIsHalfPCMCount() {
        XCTAssertEqual(makeSample(frames: 200).frameCount, 200)
    }

    func testFrameCountZeroForEmptyData() {
        XCTAssertEqual(makeSample(frames: 0).frameCount, 0)
    }

    func testNameFieldAccess() {
        XCTAssertEqual(makeSample().name, "BASS")
    }

    func testSampleRateFieldAccess() {
        XCTAssertEqual(makeSample(sampleRate: 39063).sampleRate, 39063)
    }

    func testRootKeyFieldAccess() {
        XCTAssertEqual(makeSample().rootKey, 48)
    }

    func testLoopStartNilByDefault() {
        XCTAssertNil(makeSample().loopStart)
    }

    func testLoopEndNilByDefault() {
        XCTAssertNil(makeSample().loopEnd)
    }

    func testLoopPointsWithValues() {
        let s = InstrumentPlayer.LoadedSample(
            name: "LOOP",
            pcmData: Data(count: 1000),
            sampleRate: 22050,
            rootKey: 60,
            loopStart: 100,
            loopEnd: 900
        )
        XCTAssertEqual(s.loopStart, 100)
        XCTAssertEqual(s.loopEnd, 900)
    }
}

// MARK: - DiskImage.parse() filename parsing

/// Tests for DiskImage.parse(url:device:) static method.
/// Uses URL objects without reading the filesystem — fileSize will be 0 for non-existent paths.
final class DiskImageParseTests: XCTestCase {

    // Helper: parse a filename as if in /Volumes/SD/
    private func parse(_ filename: String) -> DiskImage {
        let url = URL(fileURLWithPath: "/Volumes/SD/\(filename)")
        return DiskImage.parse(url: url, device: .emaxII)
    }

    // MARK: - ZuluSCSI two-digit format (HD10 → scsiID=1, imageIndex=0)

    func testParseHD10GivesSCSIID1ImageIndex0() {
        let img = parse("HD10.hda")
        XCTAssertEqual(img.scsiID, 1)
        XCTAssertEqual(img.imageIndex, 0)
    }

    func testParseHD20GivesSCSIID2ImageIndex0() {
        let img = parse("HD20.hda")
        XCTAssertEqual(img.scsiID, 2)
        XCTAssertEqual(img.imageIndex, 0)
    }

    func testParseHD51GivesSCSIID5ImageIndex1() {
        let img = parse("HD51.hda")
        XCTAssertEqual(img.scsiID, 5)
        XCTAssertEqual(img.imageIndex, 1)
    }

    func testParseFD00GivesSCSIID0ImageIndex0() {
        let img = parse("FD00.img")
        XCTAssertEqual(img.scsiID, 0)
        XCTAssertEqual(img.imageIndex, 0)
    }

    // MARK: - Underscore-separated format (HD1_0_Label)

    func testParseHD1WithLabel() {
        let img = parse("HD1_0_STRINGS.hda")
        XCTAssertEqual(img.scsiID, 1)
        XCTAssertEqual(img.imageIndex, 0)
        XCTAssertEqual(img.label, "STRINGS")
    }

    func testParseHDWithNoSCSIIDReturnsNilScsiID() {
        let img = parse("unknown.hda")
        XCTAssertNil(img.scsiID)
    }

    // MARK: - Filename property

    func testFilenameMatchesLastPathComponent() {
        let img = parse("HD10.hda")
        XCTAssertEqual(img.filename, "HD10.hda")
    }

    // MARK: - DeviceType preserved

    func testDeviceTypeIsPreserved() {
        let img = parse("HD10.hda")
        XCTAssertEqual(img.deviceType, .emaxII)
    }
}
