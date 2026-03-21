import XCTest
import Foundation
@testable import EmaxForge

/// Unit tests for SampleExporter.extractSamples (Issue #2)
///
/// Tests AudioFormat enum, ExportedSample struct, sanitizeFilename, and the
/// full extract-to-file pipeline using a synthetic EMX-format bank.
/// All tests are self-contained — no external bank files required.
final class SampleExportTests: XCTestCase {

    // MARK: - AudioFormat

    func testAudioFormatRawValues() {
        XCTAssertEqual(SampleExporter.AudioFormat.wav.rawValue, "WAV")
        XCTAssertEqual(SampleExporter.AudioFormat.aiff.rawValue, "AIFF")
    }

    func testAudioFormatCaseCount() {
        XCTAssertEqual(SampleExporter.AudioFormat.allCases.count, 2)
        XCTAssertTrue(SampleExporter.AudioFormat.allCases.contains(.wav))
        XCTAssertTrue(SampleExporter.AudioFormat.allCases.contains(.aiff))
    }

    // MARK: - ExportedSample

    func testExportedSampleFields() {
        let url = URL(fileURLWithPath: "/tmp/test.wav")
        let s = SampleExporter.ExportedSample(
            name: "Kick", path: url, sampleRate: 44100,
            bitDepth: 16, channels: 1, duration: 0.5
        )
        XCTAssertEqual(s.name, "Kick")
        XCTAssertEqual(s.sampleRate, 44100)
        XCTAssertEqual(s.bitDepth, 16)
        XCTAssertEqual(s.channels, 1)
        XCTAssertEqual(s.duration, 0.5, accuracy: 0.001)
        XCTAssertEqual(s.path, url)
    }

    // MARK: - sanitizeFilename

    func testSanitizeNormalName() {
        XCTAssertEqual(SampleExporter.sanitizeFilename("Hello World"), "Hello World")
    }

    func testSanitizeStripsSlash() {
        // EMAX bank names like "GUITAR/FLUTE" must have slash removed
        let result = SampleExporter.sanitizeFilename("GUITAR/FLUTE")
        XCTAssertFalse(result.contains("/"))
        XCTAssertFalse(result.isEmpty)
    }

    func testSanitizeEmptyReturnsUntitled() {
        XCTAssertEqual(SampleExporter.sanitizeFilename(""), "untitled")
    }

    func testSanitizeForbiddenCharsRemoved() {
        let dirty = "a:b*c?d\"e<f>g|h"
        let clean = SampleExporter.sanitizeFilename(dirty)
        for ch: Character in [":", "*", "?", "\"", "<", ">", "|"] {
            XCTAssertFalse(clean.contains(ch), "'\(ch)' should be removed")
        }
    }

    // MARK: - Synthetic EMX bank builder

    /// Build a minimal valid EMX-format bank containing one 22050 Hz sample.
    ///
    /// Layout (matching EmaxIIFormat constants):
    ///   0x001C–0x001D  numPresets = 1
    ///   0x001E–0x001F  numSamples = 1
    ///   0x10200        sample param 0 — startAddr=0, endAddr=pcmByteCount, rate=22050, name="MySample"
    ///   0x20000        PCM data (pcmByteCount bytes, all zeros)
    private func makeSyntheticBank(pcmByteCount: Int = 200) -> Data {
        // EmaxIIFormat.sampleParamOffset = 0x10200, sampleDataOffset = 0x20000
        let totalSize = 0x20000 + pcmByteCount
        var data = Data(count: totalSize)

        // Header: numPresets=1 at 0x1C, numSamples=1 at 0x1E (UInt16 LE)
        data[0x1C] = 1;  data[0x1D] = 0
        data[0x1E] = 1;  data[0x1F] = 0

        // Sample param block 0 at 0x10200 (64 bytes per param)
        let p = 0x10200
        // startAddress = 0 (already zero from Data init)
        // endAddress = pcmByteCount (UInt32 LE)
        data[p + 4] = UInt8( pcmByteCount        & 0xFF)
        data[p + 5] = UInt8((pcmByteCount >>  8) & 0xFF)
        data[p + 6] = 0
        data[p + 7] = 0
        // sampleRate = 22050 = 0x5622 (UInt16 LE)
        data[p + 8] = 0x22
        data[p + 9] = 0x56
        // name at param+32 = "MySample" (ASCII, 8 bytes, rest zero-padded)
        let nameBytes: [UInt8] = [0x4D, 0x79, 0x53, 0x61, 0x6D, 0x70, 0x6C, 0x65] // "MySample"
        for (i, b) in nameBytes.enumerated() { data[p + 32 + i] = b }

        // PCM area at 0x20000: all zeros (valid 16-bit silence)
        return data
    }

    // MARK: - extractSamples: WAV

    func testExtractSamplesWAVProducesFile() throws {
        let tmpDir = makeTempDir()
        defer { cleanup(tmpDir) }
        let bankURL = try writeTempBank(makeSyntheticBank())
        defer { cleanup(bankURL) }

        let results = try SampleExporter.extractSamples(from: bankURL, outputDir: tmpDir, format: .wav)

        XCTAssertFalse(results.isEmpty, "Expected at least one exported sample")
        let first = try XCTUnwrap(results.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path.path),
                      "WAV file not found at \(first.path.path)")
        XCTAssertEqual(first.path.pathExtension, "wav")
    }

    func testExtractSamplesWAVMetadata() throws {
        let tmpDir = makeTempDir()
        defer { cleanup(tmpDir) }
        let bankURL = try writeTempBank(makeSyntheticBank())
        defer { cleanup(bankURL) }

        let results = try SampleExporter.extractSamples(from: bankURL, outputDir: tmpDir, format: .wav)
        let first = try XCTUnwrap(results.first)

        XCTAssertEqual(first.sampleRate, 22050)
        XCTAssertEqual(first.bitDepth, 16)
        XCTAssertEqual(first.channels, 1)
        XCTAssertGreaterThan(first.duration, 0)
    }

    // MARK: - extractSamples: AIFF

    func testExtractSamplesAIFFProducesFile() throws {
        let tmpDir = makeTempDir()
        defer { cleanup(tmpDir) }
        let bankURL = try writeTempBank(makeSyntheticBank())
        defer { cleanup(bankURL) }

        let results = try SampleExporter.extractSamples(from: bankURL, outputDir: tmpDir, format: .aiff)

        XCTAssertFalse(results.isEmpty)
        let first = try XCTUnwrap(results.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path.path),
                      "AIFF file not found at \(first.path.path)")
        XCTAssertEqual(first.path.pathExtension, "aiff")
    }

    // MARK: - extractSamples: directory creation

    func testExtractSamplesCreatesOutputDirectory() throws {
        let base = makeTempDir()
        defer { cleanup(base) }
        let nested = base.appendingPathComponent("sub/deep")
        let bankURL = try writeTempBank(makeSyntheticBank())
        defer { cleanup(bankURL) }

        _ = try SampleExporter.extractSamples(from: bankURL, outputDir: nested, format: .wav)

        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.path),
                      "Output directory should be created automatically")
    }

    // MARK: - extractSamples: sample count

    func testExtractSamplesOneEntryFromSyntheticBank() throws {
        let tmpDir = makeTempDir()
        defer { cleanup(tmpDir) }
        let bankURL = try writeTempBank(makeSyntheticBank())
        defer { cleanup(bankURL) }

        let results = try SampleExporter.extractSamples(from: bankURL, outputDir: tmpDir, format: .wav)

        XCTAssertEqual(results.count, 1, "Synthetic bank has exactly one sample")
    }

    // MARK: - extractSamples: output file has content

    func testExtractSamplesOutputFileNonEmpty() throws {
        let tmpDir = makeTempDir()
        defer { cleanup(tmpDir) }
        let bankURL = try writeTempBank(makeSyntheticBank(pcmByteCount: 400))
        defer { cleanup(bankURL) }

        let results = try SampleExporter.extractSamples(from: bankURL, outputDir: tmpDir, format: .wav)
        let first = try XCTUnwrap(results.first)

        let attrs = try FileManager.default.attributesOfItem(atPath: first.path.path)
        let fileSize = (attrs[.size] as? Int64) ?? 0
        XCTAssertGreaterThan(fileSize, 0, "Output WAV file should contain data")
    }

    // MARK: - extractSamples: throws on empty / too-small file

    func testExtractSamplesThrowsOnEmptyFile() throws {
        let tmpDir = makeTempDir()
        defer { cleanup(tmpDir) }
        let emptyURL = try writeTempBank(Data())
        defer { cleanup(emptyURL) }

        XCTAssertThrowsError(
            try SampleExporter.extractSamples(from: emptyURL, outputDir: tmpDir, format: .wav),
            "Empty file should throw ExportError.noSampleData"
        )
    }

    func testExtractSamplesThrowsOnTooSmallFile() throws {
        let tmpDir = makeTempDir()
        defer { cleanup(tmpDir) }
        // 100 bytes < EmaxIIFormat.headerSize (0x200 = 512)
        let tinyURL = try writeTempBank(Data(count: 100))
        defer { cleanup(tinyURL) }

        XCTAssertThrowsError(
            try SampleExporter.extractSamples(from: tinyURL, outputDir: tmpDir, format: .wav)
        )
    }

    // MARK: - Helpers

    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SampleExportTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeTempBank(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bank_\(UUID().uuidString).eb2")
        try data.write(to: url)
        return url
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
