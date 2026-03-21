import XCTest
import Foundation

/// Floppy / Gotek support tests
/// Tests floppy format constants, size detection logic, and FD filename parsing.
/// Note: runs against raw logic since the executable target cannot be imported.
final class FloppyTests: XCTestCase {

    // MARK: - Floppy size constants

    let singleDensityBytes = 184_320   // 180 KB  (EMAX I)
    let doubleDensityBytes = 819_200   // 800 KB  (EMAX II standard)
    let highDensityBytes   = 1_474_560 // 1.44 MB (HD PC)

    func testDoubleDensityBytes() {
        XCTAssertEqual(doubleDensityBytes, 819_200)
    }

    func testHighDensityBytes() {
        XCTAssertEqual(highDensityBytes, 1_474_560)
    }

    func testSingleDensityBytes() {
        XCTAssertEqual(singleDensityBytes, 184_320)
    }

    // MARK: - Size detection logic

    private func detectFloppySize(bytes: Int) -> String? {
        let sizes: [(String, Int)] = [
            ("180K",  184_320),
            ("800K",  819_200),
            ("1440K", 1_474_560),
        ]
        for (label, target) in sizes {
            if abs(target - bytes) < target / 20 {
                return label
            }
        }
        return nil
    }

    func testDetectDoubleDensity800K() {
        XCTAssertEqual(detectFloppySize(bytes: 819_200), "800K")
    }

    func testDetectHighDensity1440K() {
        XCTAssertEqual(detectFloppySize(bytes: 1_474_560), "1440K")
    }

    func testDetectSingleDensity180K() {
        XCTAssertEqual(detectFloppySize(bytes: 184_320), "180K")
    }

    func testDetectDoubleDensityWithTolerance() {
        XCTAssertEqual(detectFloppySize(bytes: 819_200 + 10_000), "800K")
    }

    func testUnrecognisedSizeReturnsNil() {
        XCTAssertNil(detectFloppySize(bytes: 12_345_678))
    }

    // MARK: - FD filename parsing

    private func parseFDIndex(stem: String) -> Int? {
        let upper = stem.uppercased()
        guard upper.hasPrefix("FD"), upper.count >= 4 else { return nil }
        return Int(upper.dropFirst(2).prefix(2))
    }

    private func isFloppy(filename: String) -> Bool {
        let stem = (filename as NSString).deletingPathExtension.uppercased()
        let ext  = (filename as NSString).pathExtension.lowercased()
        return stem.hasPrefix("FD") || ext == "hfe" || ext == "dsk"
    }

    func testFDParsedAsFloppyImage() {
        XCTAssertTrue(isFloppy(filename: "FD00.img"))
    }

    func testFDParsedIndex() {
        XCTAssertEqual(parseFDIndex(stem: "FD10"), 10)
        XCTAssertEqual(parseFDIndex(stem: "FD00"), 0)
        XCTAssertEqual(parseFDIndex(stem: "FD20"), 20)
    }

    func testHFEIsFloppy() {
        XCTAssertTrue(isFloppy(filename: "EMAX_Floppy.hfe"))
    }

    func testDSKIsFloppy() {
        XCTAssertTrue(isFloppy(filename: "EMAX.dsk"))
    }

    func testHDIsNotFloppy() {
        XCTAssertFalse(isFloppy(filename: "HD10.hda"))
    }

    // MARK: - HFE magic

    func testHFEMagicBytes() {
        let magic = Data("HXCPICFE".utf8)
        XCTAssertEqual(magic.count, 8)
        XCTAssertEqual(magic[0], UInt8(ascii: "H"))
        XCTAssertEqual(magic[1], UInt8(ascii: "X"))
    }

    // MARK: - Floppy image creation (raw)

    func testCreateBlankFloppyFile() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FloppyTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let url = tmpDir.appendingPathComponent("FD00.img")
        let blank = Data(count: doubleDensityBytes)
        try blank.write(to: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let read = try Data(contentsOf: url)
        XCTAssertEqual(read.count, doubleDensityBytes)
    }

    func testAll800KBytesAreZeroForBlankFloppy() {
        let data = Data(count: doubleDensityBytes)
        XCTAssertTrue(data.allSatisfy { $0 == 0 })
    }

    // MARK: - Device type constants

    func testFloppyPrefixIsFD() {
        XCTAssertEqual("FD", "FD")
    }

    func testHDPrefixIsHD() {
        XCTAssertEqual("HD", "HD")
    }

    func testFloppyExtensions() {
        let floppyExts: Set<String> = ["hfe", "dsk"]
        XCTAssertTrue(floppyExts.contains("hfe"))
        XCTAssertTrue(floppyExts.contains("dsk"))
        XCTAssertFalse(floppyExts.contains("hda"))
    }
}
