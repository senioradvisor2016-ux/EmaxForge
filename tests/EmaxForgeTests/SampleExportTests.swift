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

    // MARK: - Stereo interleave (EMXP: "Create a STEREO file from the...")

    /// Build a Data buffer from an array of Int16 LE values.
    private func pcmFrom(_ samples: [Int16]) -> Data {
        var d = Data(count: samples.count * 2)
        for (i, s) in samples.enumerated() {
            d[i * 2]     = UInt8(s & 0xFF)
            d[i * 2 + 1] = UInt8((s >> 8) & 0xFF)
        }
        return d
    }

    /// Read a Data buffer back as an array of Int16 LE values.
    private func pcmToArray(_ data: Data) -> [Int16] {
        var out = [Int16]()
        for i in stride(from: 0, to: data.count - 1, by: 2) {
            let lo = Int16(data[i])
            let hi = Int16(data[i + 1]) << 8
            out.append(lo | hi)
        }
        return out
    }

    func testInterleaveEqualLengthBuffers() {
        let left  = pcmFrom([100, 200, 300])
        let right = pcmFrom([10, 20, 30])
        let stereo = SampleExporter.interleaveToStereo(leftPCM: left, rightPCM: right)
        XCTAssertEqual(stereo.count, 12, "3 frames × 2 channels × 2 bytes = 12 bytes")
        let vals = pcmToArray(stereo)
        // Expected: L0 R0 L1 R1 L2 R2
        XCTAssertEqual(vals, [100, 10, 200, 20, 300, 30])
    }

    func testInterleaveLongerLeft() {
        let left  = pcmFrom([1, 2, 3, 4])
        let right = pcmFrom([10, 20])
        let stereo = SampleExporter.interleaveToStereo(leftPCM: left, rightPCM: right)
        XCTAssertEqual(stereo.count, 16, "4 frames × 2 ch × 2 bytes")
        let vals = pcmToArray(stereo)
        XCTAssertEqual(vals, [1, 10, 2, 20, 3, 0, 4, 0], "Right channel zero-padded")
    }

    func testInterleaveLongerRight() {
        let left  = pcmFrom([5, 6])
        let right = pcmFrom([50, 60, 70, 80])
        let stereo = SampleExporter.interleaveToStereo(leftPCM: left, rightPCM: right)
        XCTAssertEqual(stereo.count, 16)
        let vals = pcmToArray(stereo)
        XCTAssertEqual(vals, [5, 50, 6, 60, 0, 70, 0, 80], "Left channel zero-padded")
    }

    func testInterleaveEmptyLeftProducesAllZeroLeft() {
        let left  = Data()
        let right = pcmFrom([1, 2, 3])
        let stereo = SampleExporter.interleaveToStereo(leftPCM: left, rightPCM: right)
        XCTAssertEqual(stereo.count, 12)
        let vals = pcmToArray(stereo)
        XCTAssertEqual(vals, [0, 1, 0, 2, 0, 3])
    }

    func testInterleaveEmptyRightProducesAllZeroRight() {
        let left  = pcmFrom([7, 8])
        let right = Data()
        let stereo = SampleExporter.interleaveToStereo(leftPCM: left, rightPCM: right)
        XCTAssertEqual(stereo.count, 8)
        let vals = pcmToArray(stereo)
        XCTAssertEqual(vals, [7, 0, 8, 0])
    }

    func testInterleaveBothEmptyProducesEmptyData() {
        let stereo = SampleExporter.interleaveToStereo(leftPCM: Data(), rightPCM: Data())
        XCTAssertEqual(stereo.count, 0)
    }

    func testInterleaveOutputSizeIsDoubleFrameCount() {
        // For any inputs, output byte count must be 4 * max(leftFrames, rightFrames)
        let left  = pcmFrom([Int16](repeating: 0, count: 100))
        let right = pcmFrom([Int16](repeating: 0, count: 80))
        let stereo = SampleExporter.interleaveToStereo(leftPCM: left, rightPCM: right)
        XCTAssertEqual(stereo.count, 100 * 4)
    }

    func testInterleavePreservesNegativeValues() {
        let left  = pcmFrom([-1000, -2000])
        let right = pcmFrom([1000, 2000])
        let stereo = SampleExporter.interleaveToStereo(leftPCM: left, rightPCM: right)
        let vals = pcmToArray(stereo)
        XCTAssertEqual(vals, [-1000, 1000, -2000, 2000])
    }

    func testInterleavePreservesMaxAmplitudeValues() {
        let left  = pcmFrom([Int16.min, Int16.max])
        let right = pcmFrom([Int16.max, Int16.min])
        let stereo = SampleExporter.interleaveToStereo(leftPCM: left, rightPCM: right)
        let vals = pcmToArray(stereo)
        XCTAssertEqual(vals, [Int16.min, Int16.max, Int16.max, Int16.min])
    }

    // MARK: - exportAllSamples filename template

    /// Build a minimal BankSampleData with one silent sample.
    private func makeBankSampleData(
        name: String = "KICK",
        sampleRate: Int = 22050,
        rootKey: Int = 60,
        loopStart: Int? = nil,
        loopEnd: Int? = nil
    ) -> BankSampleData {
        let pcm = Data(count: 200) // silence
        let entry = BankSampleData.SampleEntry(
            index: 0, name: name,
            pcmData: pcm, sampleRate: sampleRate,
            loopStart: loopStart, loopEnd: loopEnd,
            rootKey: rootKey
        )
        return BankSampleData(samples: [entry], rawPCM: pcm, sampleDataOffset: 0)
    }

    func testExportAllSamplesDefaultTemplateUsesSampleName() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let bank = makeBankSampleData(name: "VIOLIN")
        _ = try SampleExporter.exportAllSamples(
            from: bank, bankName: "STRINGS", to: dir,
            format: .wav, normalize: false, createSubfolder: false,
            filenameTemplate: .default
        )
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(files.contains("VIOLIN.wav"),
                      "Default template should produce 'VIOLIN.wav', got: \(files)")
    }

    func testExportAllSamplesEmxpStyleTemplate() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let bank = makeBankSampleData(name: "CELLO")
        _ = try SampleExporter.exportAllSamples(
            from: bank, bankName: "STRINGS", to: dir,
            format: .wav, normalize: false, createSubfolder: false,
            filenameTemplate: .emxpStyle   // {bank}_{index}_{sample}
        )
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(files.contains("STRINGS_001_CELLO.wav"),
                      "emxpStyle template should produce 'STRINGS_001_CELLO.wav', got: \(files)")
    }

    func testExportAllSamplesCustomTemplate() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let bank = makeBankSampleData(name: "BASS")
        _ = try SampleExporter.exportAllSamples(
            from: bank, bankName: "LOW", to: dir,
            format: .wav, normalize: false, createSubfolder: false,
            filenameTemplate: SampleFilenameTemplate("EXPORT_{bank}_{sample}")
        )
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(files.contains("EXPORT_LOW_BASS.wav"),
                      "Custom template should produce 'EXPORT_LOW_BASS.wav', got: \(files)")
    }

    func testExportAllSamplesBankIndexPassedToTemplate() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let bank = makeBankSampleData(name: "X")
        _ = try SampleExporter.exportAllSamples(
            from: bank, bankName: "B", to: dir,
            format: .wav, normalize: false, createSubfolder: false,
            filenameTemplate: SampleFilenameTemplate("{bankindex}_{sample}"),
            bankIndex: 7
        )
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(files.contains("7_X.wav"),
                      "bankindex=7 should produce '7_X.wav', got: \(files)")
    }

    func testExportAllSamplesKeyTemplateWithRootKey() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let bank = makeBankSampleData(name: "NOTE", rootKey: 60)  // C4
        _ = try SampleExporter.exportAllSamples(
            from: bank, bankName: "PIANO", to: dir,
            format: .wav, normalize: false, createSubfolder: false,
            filenameTemplate: .bankKeyAndSample   // {bank}_{key}_{sample}
        )
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(files.contains("PIANO_C4_NOTE.wav"),
                      "bankKeyAndSample template with rootKey=60 should produce 'PIANO_C4_NOTE.wav', got: \(files)")
    }

    // MARK: - WAV smpl chunk (loop preservation)

    /// Parse a WAV file and return the data of a chunk with the given 4-byte ID, or nil.
    /// The returned Data is always freshly allocated with 0-based indices.
    private func findWAVChunk(id: String, in wavData: Data) -> Data? {
        guard wavData.count >= 12 else { return nil }
        guard wavData[0..<4] == "RIFF".data(using: .ascii)! else { return nil }
        guard wavData[8..<12] == "WAVE".data(using: .ascii)! else { return nil }
        let idBytes = id.data(using: .ascii)!
        var offset = 12
        while offset + 8 <= wavData.count {
            let chunkID = wavData[offset..<offset + 4]
            let chunkSize = Int(wavData[offset+4]) |
                           (Int(wavData[offset+5]) << 8) |
                           (Int(wavData[offset+6]) << 16) |
                           (Int(wavData[offset+7]) << 24)
            if chunkID == idBytes {
                let dataStart = offset + 8
                let dataEnd = min(dataStart + chunkSize, wavData.count)
                // Return a new Data so indices start at 0, not at the file offset
                return Data(wavData[dataStart..<dataEnd])
            }
            offset += 8 + chunkSize
            if chunkSize % 2 != 0 { offset += 1 } // WAV pad byte
        }
        return nil
    }

    func testExportSampleWithLoopWritesSmplChunk() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let bank = makeBankSampleData(name: "LOOP", loopStart: 10, loopEnd: 80)
        let results = try SampleExporter.exportAllSamples(
            from: bank, bankName: "B", to: dir,
            format: .wav, normalize: false, createSubfolder: false
        )
        let wavURL = try XCTUnwrap(results.first?.outputURL)
        let wavData = try Data(contentsOf: wavURL)
        let smplChunk = findWAVChunk(id: "smpl", in: wavData)
        XCTAssertNotNil(smplChunk, "WAV file with loop should contain smpl chunk")
    }

    func testExportSampleWithoutLoopHasNoSmplChunk() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let bank = makeBankSampleData(name: "NOLOOP", loopStart: nil, loopEnd: nil)
        let results = try SampleExporter.exportAllSamples(
            from: bank, bankName: "B", to: dir,
            format: .wav, normalize: false, createSubfolder: false
        )
        let wavURL = try XCTUnwrap(results.first?.outputURL)
        let wavData = try Data(contentsOf: wavURL)
        let smplChunk = findWAVChunk(id: "smpl", in: wavData)
        XCTAssertNil(smplChunk, "WAV without loop data should not contain smpl chunk")
    }

    func testSmplChunkContainsCorrectLoopPoints() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let loopStart = 20
        let loopEnd   = 90
        let bank = makeBankSampleData(name: "L", rootKey: 69, loopStart: loopStart, loopEnd: loopEnd)
        let results = try SampleExporter.exportAllSamples(
            from: bank, bankName: "B", to: dir,
            format: .wav, normalize: false, createSubfolder: false
        )
        let wavURL = try XCTUnwrap(results.first?.outputURL)
        let wavData = try Data(contentsOf: wavURL)
        let smplBody = try XCTUnwrap(findWAVChunk(id: "smpl", in: wavData),
                                     "smpl chunk must be present")
        // MIDI unity note at byte 12 of smpl body
        let midiNote = Int(smplBody[12]) | (Int(smplBody[13]) << 8) |
                       (Int(smplBody[14]) << 16) | (Int(smplBody[15]) << 24)
        XCTAssertEqual(midiNote, 69, "smpl MIDI unity note should be rootKey=69")
        // num sample loops at byte 28
        let numLoops = Int(smplBody[28]) | (Int(smplBody[29]) << 8)
        XCTAssertEqual(numLoops, 1, "smpl chunk should encode exactly one loop")
        // Loop start at body offset 44 (36 header + 8 into loop struct)
        let ls = Int(smplBody[44]) | (Int(smplBody[45]) << 8) |
                 (Int(smplBody[46]) << 16) | (Int(smplBody[47]) << 24)
        let le = Int(smplBody[48]) | (Int(smplBody[49]) << 8) |
                 (Int(smplBody[50]) << 16) | (Int(smplBody[51]) << 24)
        XCTAssertEqual(ls, loopStart, "smpl loop start should match sample loopStart")
        XCTAssertEqual(le, loopEnd,   "smpl loop end should match sample loopEnd")
    }

    func testSmplChunkUpdatesRIFFSize() throws {
        // Verify that the RIFF container size field is updated when smpl chunk is appended
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let bank = makeBankSampleData(name: "R", loopStart: 5, loopEnd: 95)
        let results = try SampleExporter.exportAllSamples(
            from: bank, bankName: "B", to: dir,
            format: .wav, normalize: false, createSubfolder: false
        )
        let wavURL = try XCTUnwrap(results.first?.outputURL)
        let wavData = try Data(contentsOf: wavURL)
        // RIFF size at bytes 4-7 must equal total file size - 8
        let riffSize = Int(wavData[4]) | (Int(wavData[5]) << 8) |
                       (Int(wavData[6]) << 16) | (Int(wavData[7]) << 24)
        XCTAssertEqual(riffSize, wavData.count - 8, "RIFF size field must match actual file size - 8")
    }
}
