import XCTest
import Foundation
@testable import EmaxForge

/// Tests for FormatConverter and EB2Reader — pure logic: enum types,
/// identifyFormat (URL extension dispatch), parseBankHeader (in-memory),
/// and error descriptions. No disk I/O or Wine required.
final class FormatConverterTests: XCTestCase {

    // MARK: - Helpers

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: "/fake/\(name)")
    }

    private func makeEB2Header(bankName: String = "KICK DRUMS ") -> Data {
        // Minimal 64-byte block with ASCII bank name in the first 16 bytes
        var data = Data(count: 64)
        let nameBytes = Array(bankName.utf8.prefix(16))
        for (i, b) in nameBytes.enumerated() { data[i] = b }
        return data
    }

    // MARK: - FormatError descriptions

    func testUnsupportedFormatDescriptionContainsFormat() {
        let err = FormatConverter.FormatError.unsupported("xyz")
        XCTAssertTrue(err.errorDescription?.contains("xyz") == true)
    }

    func testInvalidDataDescriptionContainsMessage() {
        let err = FormatConverter.FormatError.invalidData("bad header")
        XCTAssertTrue(err.errorDescription?.contains("bad header") == true)
    }

    func testHFEParseErrorDescriptionContainsMessage() {
        let err = FormatConverter.FormatError.hfeParseError("wrong magic")
        XCTAssertTrue(err.errorDescription?.contains("wrong magic") == true)
    }

    // MARK: - emuExtensions

    func testEmuExtensionsContainsEB2() {
        XCTAssertTrue(FormatConverter.emuExtensions.contains("eb2"))
    }

    func testEmuExtensionsContainsHFE() {
        XCTAssertTrue(FormatConverter.emuExtensions.contains("hfe"))
    }

    func testEmuExtensionsContainsHDA() {
        XCTAssertTrue(FormatConverter.emuExtensions.contains("hda"))
    }

    func testEmuExtensionsContainsSF2() {
        XCTAssertTrue(FormatConverter.emuExtensions.contains("sf2"))
    }

    func testEmuExtensionsNotEmpty() {
        XCTAssertGreaterThan(FormatConverter.emuExtensions.count, 0)
    }

    // MARK: - EmuFormat enum

    func testEmuFormatDescriptions() {
        XCTAssertFalse(FormatConverter.EmuFormat.eb2.description.isEmpty)
        XCTAssertFalse(FormatConverter.EmuFormat.eb1.description.isEmpty)
        XCTAssertFalse(FormatConverter.EmuFormat.hfe.description.isEmpty)
        XCTAssertFalse(FormatConverter.EmuFormat.ez2.description.isEmpty)
        XCTAssertFalse(FormatConverter.EmuFormat.sf2.description.isEmpty)
        XCTAssertFalse(FormatConverter.EmuFormat.unknown.description.isEmpty)
    }

    func testEmuFormatRawValues() {
        XCTAssertEqual(FormatConverter.EmuFormat.eb2.rawValue, "EMAX II Bank")
        XCTAssertEqual(FormatConverter.EmuFormat.hfe.rawValue, "Gotek Floppy Image")
    }

    // MARK: - identifyFormat

    func testIdentifyFormatEB2() {
        XCTAssertEqual(FormatConverter.identifyFormat(url: url("bank.eb2")), .eb2)
    }

    func testIdentifyFormatEB1() {
        XCTAssertEqual(FormatConverter.identifyFormat(url: url("bank.eb1")), .eb1)
    }

    func testIdentifyFormatEM2() {
        XCTAssertEqual(FormatConverter.identifyFormat(url: url("bank.em2")), .em2)
    }

    func testIdentifyFormatEM1() {
        XCTAssertEqual(FormatConverter.identifyFormat(url: url("bank.em1")), .em1)
    }

    func testIdentifyFormatHFE() {
        XCTAssertEqual(FormatConverter.identifyFormat(url: url("floppy.hfe")), .hfe)
    }

    func testIdentifyFormatEZ2() {
        XCTAssertEqual(FormatConverter.identifyFormat(url: url("disk.ez2")), .ez2)
    }

    func testIdentifyFormatEZ1() {
        XCTAssertEqual(FormatConverter.identifyFormat(url: url("disk.ez1")), .ez1)
    }

    func testIdentifyFormatSF2() {
        XCTAssertEqual(FormatConverter.identifyFormat(url: url("sounds.sf2")), .sf2)
    }

    func testIdentifyFormatHDA() {
        XCTAssertEqual(FormatConverter.identifyFormat(url: url("disk.hda")), .hda)
    }

    func testIdentifyFormatIMG() {
        XCTAssertEqual(FormatConverter.identifyFormat(url: url("disk.img")), .hda)
    }

    func testIdentifyFormatISO() {
        XCTAssertEqual(FormatConverter.identifyFormat(url: url("disk.iso")), .hda)
    }

    func testIdentifyFormatUnknown() {
        XCTAssertEqual(FormatConverter.identifyFormat(url: url("file.xyz")), .unknown)
    }

    func testIdentifyFormatUnknownForNoExtension() {
        XCTAssertEqual(FormatConverter.identifyFormat(url: url("noextension")), .unknown)
    }

    func testIdentifyFormatCaseInsensitiveUpperEB2() {
        // pathExtension.lowercased() is used — so upper-case extension maps correctly
        XCTAssertEqual(FormatConverter.identifyFormat(url: url("BANK.EB2")), .eb2)
    }

    func testIdentifyFormatCaseInsensitiveUpperHDA() {
        XCTAssertEqual(FormatConverter.identifyFormat(url: url("DISK.HDA")), .hda)
    }
}


// MARK: - EB2Reader tests

/// Tests for EB2Reader — EB2Error descriptions, BankHeader struct, and
/// parseBankHeader (pure in-memory: returns nil for bad inputs, BankHeader for valid data).
final class EB2ReaderTests: XCTestCase {

    // MARK: - EB2Error descriptions

    func testInvalidEB2FileDescription() {
        let err = EB2Reader.EB2Error.invalidEB2File
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testFileTooSmallDescription() {
        let err = EB2Reader.EB2Error.fileTooSmall
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    // MARK: - BankHeader struct

    func testBankHeaderFieldAccess() {
        let h = BankHeader(name: "STRINGS", dataSize: 489472, clusterCount: 1)
        XCTAssertEqual(h.name, "STRINGS")
        XCTAssertEqual(h.dataSize, 489472)
        XCTAssertEqual(h.clusterCount, 1)
    }

    // MARK: - parseBankHeader

    func testParseBankHeaderReturnsNilForDataSmallerThan64Bytes() {
        XCTAssertNil(EB2Reader.parseBankHeader(data: Data(count: 63)))
    }

    func testParseBankHeaderReturnsNilForEmptyData() {
        XCTAssertNil(EB2Reader.parseBankHeader(data: Data()))
    }

    func testParseBankHeaderReturnsNilForAllZeroHeader() {
        // 64 zero bytes → name is all NUL → trimmed name is empty → returns nil
        XCTAssertNil(EB2Reader.parseBankHeader(data: Data(count: 64)))
    }

    func testParseBankHeaderReturnsNilForAllSpaceHeader() {
        // 64 space bytes → trimmed name is empty → returns nil
        XCTAssertNil(EB2Reader.parseBankHeader(data: Data(repeating: 0x20, count: 64)))
    }

    func testParseBankHeaderReturnsValidHeaderForASCIIName() {
        var data = Data(count: 64)
        let name = "PIANO       " // 12 chars, padded to 12
        let nameBytes = Array(name.utf8.prefix(16))
        for (i, b) in nameBytes.enumerated() { data[i] = b }

        let header = EB2Reader.parseBankHeader(data: data)
        XCTAssertNotNil(header)
        XCTAssertTrue(header?.name.contains("PIANO") == true)
    }

    func testParseBankHeaderNameIsTrimmed() {
        var data = Data(count: 64)
        // Write "BASS\0\0\0\0\0\0\0\0\0\0\0\0" (16 bytes, null-padded)
        let nameBytes: [UInt8] = [0x42, 0x41, 0x53, 0x53, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        for (i, b) in nameBytes.enumerated() { data[i] = b }

        let header = EB2Reader.parseBankHeader(data: data)
        XCTAssertNotNil(header)
        XCTAssertEqual(header?.name, "BASS")
    }

    func testParseBankHeaderDataSizeMatchesInputSize() {
        var data = Data(count: 64)
        data[0] = 0x48  // 'H'
        data[1] = 0x49  // 'I'
        data[2] = 0x54  // 'T'

        let header = EB2Reader.parseBankHeader(data: data)
        XCTAssertEqual(header?.dataSize, 64)
    }

    func testParseBankHeaderLargerDataSizeIsPreserved() {
        var data = Data(count: 489472)
        data[0] = 0x53  // 'S'
        data[1] = 0x54  // 'T'
        data[2] = 0x52  // 'R'

        let header = EB2Reader.parseBankHeader(data: data)
        XCTAssertEqual(header?.dataSize, 489472)
    }

    func testParseBankHeaderClusterCountForOneCluster() {
        // 489472 bytes → clusterCount = 1 (exactly one 239MB cluster)
        var data = Data(count: 489472)
        data[0] = 0x41  // 'A'

        let header = EB2Reader.parseBankHeader(data: data)
        XCTAssertEqual(header?.clusterCount, 1)
    }

    func testParseBankHeaderClusterCountForTwoClusters() {
        // 489472 + 1 = 489473 bytes → ceiling division → clusterCount = 2
        var data = Data(count: 489473)
        data[0] = 0x41  // 'A'

        let header = EB2Reader.parseBankHeader(data: data)
        XCTAssertEqual(header?.clusterCount, 2)
    }
}
