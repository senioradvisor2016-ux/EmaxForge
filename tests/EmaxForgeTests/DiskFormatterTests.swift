import XCTest
import Foundation
@testable import EmaxForge

/// Tests for DiskFormatter — error types, FormatOptions defaults, and the
/// createBlankFloppy output (pure file-generation, no real disk required).
/// formatImage error paths exercise guards that fire after opening a temp file.
final class DiskFormatterTests: XCTestCase {

    // MARK: - Helpers

    private func makeTempURL(ext: String = "hda") -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("DiskFormatterTest_\(UUID().uuidString).\(ext)")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - FormatterError descriptions

    func testNotEmaxImageDescription() {
        let err = DiskFormatter.FormatterError.notEmaxImage
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testReadErrorDescription() {
        let err = DiskFormatter.FormatterError.readError
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testWriteErrorDescriptionContainsMessage() {
        let err = DiskFormatter.FormatterError.writeError("disk full")
        XCTAssertTrue(err.errorDescription?.contains("disk full") == true)
    }

    func testPermissionDeniedDescription() {
        let err = DiskFormatter.FormatterError.permissionDenied
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testVolumeBusyDescription() {
        let err = DiskFormatter.FormatterError.volumeBusy
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testInvalidVolumeDescription() {
        let err = DiskFormatter.FormatterError.invalidVolume
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testUnknownDiskSizeDescriptionContainsMB() {
        let err = DiskFormatter.FormatterError.unknownDiskSize(512)
        XCTAssertTrue(err.errorDescription?.contains("512") == true)
    }

    func testAllErrorDescriptionsNonEmpty() {
        let errors: [DiskFormatter.FormatterError] = [
            .notEmaxImage, .readError, .writeError("x"),
            .permissionDenied, .volumeBusy, .invalidVolume, .unknownDiskSize(96)
        ]
        for err in errors {
            XCTAssertFalse(err.errorDescription?.isEmpty ?? true,
                           "Error \(err) has empty description")
        }
    }

    // MARK: - FormatOptions defaults

    func testFormatOptionsDefaultKeepOSIsTrue() {
        let opts = DiskFormatter.FormatOptions()
        XCTAssertTrue(opts.keepOS)
    }

    func testFormatOptionsDefaultQuickFormatIsTrue() {
        let opts = DiskFormatter.FormatOptions()
        XCTAssertTrue(opts.quickFormat)
    }

    func testFormatOptionsDefaultVolumeLabelIsNil() {
        let opts = DiskFormatter.FormatOptions()
        XCTAssertNil(opts.volumeLabel)
    }

    func testFormatOptionsCanBeCustomized() {
        let opts = DiskFormatter.FormatOptions(keepOS: false, quickFormat: false, volumeLabel: "TEST")
        XCTAssertFalse(opts.keepOS)
        XCTAssertFalse(opts.quickFormat)
        XCTAssertEqual(opts.volumeLabel, "TEST")
    }

    // MARK: - FloppyDensity enum

    func testFloppyDensityCasesExist() {
        // Compile-time check that all three cases exist
        let _: DiskFormatter.FloppyDensity = .singleDensity
        let _: DiskFormatter.FloppyDensity = .doubleDensity
        let _: DiskFormatter.FloppyDensity = .highDensity
    }

    // MARK: - VolumeFileSystem enum

    func testVolumeFileSystemCasesExist() {
        let _: DiskFormatter.VolumeFileSystem = .fat32
        let _: DiskFormatter.VolumeFileSystem = .exfat
    }

    // MARK: - formatImage: too-small file

    func testFormatImageThrowsOnTooSmallFile() throws {
        // fileSize < 0x2000 (8192) → readError guard
        let url = makeTempURL()
        defer { cleanup(url) }
        try Data(count: 512).write(to: url)  // 512 bytes < 0x2000

        XCTAssertThrowsError(try DiskFormatter.formatImage(at: url)) { err in
            let e = err as! DiskFormatter.FormatterError
            if case .readError = e { } else {
                XCTFail("Expected readError for too-small file, got \(e)")
            }
        }
    }

    func testFormatImageThrowsOnFileExactly8192BytesWithWrongMagic() throws {
        // fileSize == 0x2000 but not EMX2 → notEmaxImage
        let url = makeTempURL()
        defer { cleanup(url) }
        try Data(count: 0x2000).write(to: url)  // All zeros — no EMX2 magic

        XCTAssertThrowsError(try DiskFormatter.formatImage(at: url)) { err in
            let e = err as! DiskFormatter.FormatterError
            if case .notEmaxImage = e { } else {
                XCTFail("Expected notEmaxImage for empty 8192-byte file, got \(e)")
            }
        }
    }

    func testFormatImageThrowsNotEmaxImageForRandomContent() throws {
        let url = makeTempURL()
        defer { cleanup(url) }
        // 16 KB of 0xFF — has correct size but wrong magic
        try Data(repeating: 0xFF, count: 16384).write(to: url)

        XCTAssertThrowsError(try DiskFormatter.formatImage(at: url)) { err in
            if case .notEmaxImage = err as! DiskFormatter.FormatterError { } else {
                XCTFail("Expected notEmaxImage")
            }
        }
    }

    // MARK: - createBlankFloppy: file creation

    func testCreateBlankFloppyCreatesFile() throws {
        let url = makeTempURL(ext: "hfe")
        defer { cleanup(url) }

        try DiskFormatter.createBlankFloppy(at: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "createBlankFloppy should create a file at the given URL")
    }

    func testCreateBlankFloppyFileIsNonEmpty() throws {
        let url = makeTempURL(ext: "hfe")
        defer { cleanup(url) }

        try DiskFormatter.createBlankFloppy(at: url)

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs[.size] as? Int64) ?? 0
        XCTAssertGreaterThan(size, 0)
    }

    func testCreateBlankFloppyHFESignature() throws {
        let url = makeTempURL(ext: "hfe")
        defer { cleanup(url) }

        try DiskFormatter.createBlankFloppy(at: url)
        let data = try Data(contentsOf: url)

        XCTAssertGreaterThanOrEqual(data.count, 8, "HFE file must be at least 8 bytes")
        let sig = String(data: data[0..<8], encoding: .ascii)
        XCTAssertEqual(sig, "HXCPICFE", "HFE signature must be HXCPICFE at offset 0")
    }

    func testCreateBlankFloppyNumTracks() throws {
        let url = makeTempURL(ext: "hfe")
        defer { cleanup(url) }

        try DiskFormatter.createBlankFloppy(at: url)
        let data = try Data(contentsOf: url)

        // numTracks at offset 9: UInt16 LE = 80 (0x50)
        XCTAssertGreaterThanOrEqual(data.count, 11)
        let numTracks = UInt16(data[9]) | (UInt16(data[10]) << 8)
        XCTAssertEqual(numTracks, 80, "numTracks should be 80")
    }

    func testCreateBlankFloppyNumSides() throws {
        let url = makeTempURL(ext: "hfe")
        defer { cleanup(url) }

        try DiskFormatter.createBlankFloppy(at: url)
        let data = try Data(contentsOf: url)

        // numSides at offset 11: UInt8 = 2
        XCTAssertGreaterThanOrEqual(data.count, 12)
        XCTAssertEqual(data[11], 2, "numSides should be 2")
    }

    func testCreateBlankFloppyDoubleDensityBitRate() throws {
        let url = makeTempURL(ext: "hfe")
        defer { cleanup(url) }

        try DiskFormatter.createBlankFloppy(at: url, density: .doubleDensity)
        let data = try Data(contentsOf: url)

        // bitRate at offset 14: UInt16 LE = 250 for double density
        XCTAssertGreaterThanOrEqual(data.count, 16)
        let bitRate = UInt16(data[14]) | (UInt16(data[15]) << 8)
        XCTAssertEqual(bitRate, 250, "Double density should have bit rate 250")
    }

    func testCreateBlankFloppyHighDensityBitRate() throws {
        let url = makeTempURL(ext: "hfe")
        defer { cleanup(url) }

        try DiskFormatter.createBlankFloppy(at: url, density: .highDensity)
        let data = try Data(contentsOf: url)

        // bitRate at offset 14: UInt16 LE = 500 for high density
        XCTAssertGreaterThanOrEqual(data.count, 16)
        let bitRate = UInt16(data[14]) | (UInt16(data[15]) << 8)
        XCTAssertEqual(bitRate, 500, "High density should have bit rate 500")
    }

    func testCreateBlankFloppyRotationSpeedAt16() throws {
        let url = makeTempURL(ext: "hfe")
        defer { cleanup(url) }

        try DiskFormatter.createBlankFloppy(at: url)
        let data = try Data(contentsOf: url)

        // rotationSpeed at offset 16: UInt16 LE = 300 RPM
        XCTAssertGreaterThanOrEqual(data.count, 18)
        let rpm = UInt16(data[16]) | (UInt16(data[17]) << 8)
        XCTAssertEqual(rpm, 300, "Rotation speed should be 300 RPM")
    }

    func testCreateBlankFloppyFileHasTrackData() throws {
        let url = makeTempURL(ext: "hfe")
        defer { cleanup(url) }

        try DiskFormatter.createBlankFloppy(at: url)
        let data = try Data(contentsOf: url)

        // 80 tracks × 2 sides × 6250 bytes (double density) + header(512) + trackTable(512)
        let expectedMin = 512 + 512 + (80 * 2 * 6250)
        XCTAssertGreaterThanOrEqual(data.count, expectedMin,
                                    "HFE file should contain full track data")
    }
}
