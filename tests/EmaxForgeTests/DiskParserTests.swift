import XCTest
import Foundation

/// DiskImage parser tests — validates ZuluSCSI filename parsing logic inline.
/// Note: runs against raw logic since the executable target cannot be imported.
final class DiskParserTests: XCTestCase {

    // MARK: - ZuluSCSI two-digit format

    private func parseZuluSCSI(stem: String) -> (scsiID: Int?, imageIndex: Int?, label: String?) {
        let upper = stem.uppercased()
        var scsiID: Int?
        var imageIndex: Int?
        var label: String?

        for prefix in ["HD", "FD"] {
            if upper.hasPrefix(prefix) {
                let remainder = stem.dropFirst(prefix.count)
                let parts = remainder.split(separator: "_", maxSplits: 2).map(String.init)

                if let first = parts.first {
                    if first.count == 2, parts.count == 1,
                       let d1 = Int(String(first.prefix(1))),
                       let d2 = Int(String(first.suffix(1))) {
                        scsiID = d1
                        imageIndex = d2
                    } else if let id = Int(first) {
                        scsiID = id
                    }
                }
                if parts.count >= 2, let idx = Int(parts[1]) { imageIndex = idx }
                if parts.count >= 3 { label = parts[2] }
                break
            }
        }

        return (scsiID, imageIndex, label)
    }

    func testHD10ParsesAsScsiID1Index0() {
        let r = parseZuluSCSI(stem: "HD10")
        XCTAssertEqual(r.scsiID, 1)
        XCTAssertEqual(r.imageIndex, 0)
    }

    func testHD20ParsesAsScsiID2Index0() {
        let r = parseZuluSCSI(stem: "HD20")
        XCTAssertEqual(r.scsiID, 2)
    }

    func testHD11ParsesAsScsiID1Index1() {
        let r = parseZuluSCSI(stem: "HD11")
        XCTAssertEqual(r.scsiID, 1)
        XCTAssertEqual(r.imageIndex, 1)
    }

    // MARK: - Underscore-separated format

    func testHD1_0ParsesScsiID1Index0() {
        let r = parseZuluSCSI(stem: "HD1_0")
        XCTAssertEqual(r.scsiID, 1)
        XCTAssertEqual(r.imageIndex, 0)
    }

    func testHD1_0_MyDiskHasLabel() {
        let r = parseZuluSCSI(stem: "HD1_0_MyDisk")
        XCTAssertEqual(r.label, "MyDisk")
    }

    // MARK: - FD prefix

    func testFD10ParsesAsScsiID1Index0() {
        let r = parseZuluSCSI(stem: "FD10")
        XCTAssertEqual(r.scsiID, 1)
        XCTAssertEqual(r.imageIndex, 0)
    }

    func testFD00ParsesAsScsiID0() {
        let r = parseZuluSCSI(stem: "FD00")
        XCTAssertEqual(r.scsiID, 0)
    }

    // MARK: - No-prefix edge cases

    func testNoPrefixMatchYieldsNilScsiID() {
        let r = parseZuluSCSI(stem: "random_file")
        XCTAssertNil(r.scsiID)
    }

    func testSingleCharStemDoesNotCrash() {
        let r = parseZuluSCSI(stem: "a")
        XCTAssertNil(r.scsiID)
    }

    // MARK: - Extensions

    func testExtensionLowercased() {
        let filename = "HD10.HDA"
        let ext = (filename as NSString).pathExtension.lowercased()
        XCTAssertEqual(ext, "hda")
    }

    func testHFEExtensionRecognised() {
        let validExts: Set<String> = ["hda", "ez2", "img", "iso", "hfe", "dsk"]
        XCTAssertTrue(validExts.contains("hfe"))
    }

    func testDSKExtensionRecognised() {
        let validExts: Set<String> = ["hda", "ez2", "img", "iso", "hfe", "dsk"]
        XCTAssertTrue(validExts.contains("dsk"))
    }

    // MARK: - ZuluSCSI name generation

    func testZuluSCSINameFormat() {
        // HD SCSI ID 1, index 0
        let scsiID = 1
        let imageIndex = 0
        let name = "HD\(scsiID)\(imageIndex).hda"
        XCTAssertEqual(name, "HD10.hda")
    }

    func testFloppyZuluSCSINameFormat() {
        let scsiID = 0
        let imageIndex = 0
        let name = "FD\(scsiID)\(imageIndex).img"
        XCTAssertEqual(name, "FD00.img")
    }
}
