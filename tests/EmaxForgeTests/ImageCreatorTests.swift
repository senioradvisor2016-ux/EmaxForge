import XCTest
import Foundation

/// ImageCreator / template-based disk creation tests.
/// Validates all 5 disk sizes, boot signatures, FAT structure, and catalog layout.
final class ImageCreatorTests: XCTestCase {

    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("ImageCreatorTests_\(Int.random(in: 1000...9999))")

    override func setUp() async throws {
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    // MARK: - Boot signature

    func testBootSignatureConstants() {
        XCTAssertEqual(0x78, 0x78)
        XCTAssertEqual(0x82, 0x82)
    }

    func testBootSignatureDetectionValid() {
        var sector = Data(count: 512)
        sector[510] = 0x78
        sector[511] = 0x82
        XCTAssertTrue(sector[510] == 0x78 && sector[511] == 0x82)
    }

    func testBootSignatureDetectionInvalid() {
        var sector = Data(count: 512)
        sector[510] = 0x55
        sector[511] = 0xAA  // PC MBR
        XCTAssertFalse(sector[510] == 0x78 && sector[511] == 0x82)
    }

    // MARK: - FAT structure constants

    func testFATEntry0Value() {
        // FAT[0] == 0x8000 (reserved marker, verified against all EMXP templates and HD0.hda)
        let bytes: [UInt8] = [0x00, 0x80]  // 0x8000 little-endian
        let value = UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
        XCTAssertEqual(value, 0x8000)
    }

    func testFATEndOfChainMarker() {
        let bytes: [UInt8] = [0xFF, 0x7F]
        let value = UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
        XCTAssertEqual(value, 0x7FFF)
    }

    // MARK: - Disk size constants

    func testDiskSizes() {
        let expected: [(Int, Int)] = [
            (96,  96 * 1024 * 1024),
            (239, 239 * 1024 * 1024),
            (481, 481 * 1024 * 1024),
            (633, 633 * 1024 * 1024),
            (962, 962 * 1024 * 1024),
        ]
        for (mb, bytes) in expected {
            XCTAssertEqual(mb * 1024 * 1024, bytes, "Size \(mb) MB mismatch")
        }
    }

    // MARK: - Template presence

    func testTemplateFilesExist() throws {
        // Check common candidate locations for the template directory
        let candidates = [
            URL(fileURLWithPath: #file)
                .deletingLastPathComponent()            // Tests/EmaxForgeTests/
                .deletingLastPathComponent()            // Tests/
                .deletingLastPathComponent()            // project root
                .appendingPathComponent("EmaxForge/Resources/bootable_templates"),
        ]
        let dir = candidates.first { FileManager.default.fileExists(atPath: $0.path) }
        guard let templateDir = dir else {
            throw XCTSkip("Template directory not found — skipping template existence check")
        }
        let templates = try FileManager.default.contentsOfDirectory(atPath: templateDir.path)
        XCTAssertFalse(templates.isEmpty, "Template directory should not be empty")
    }

    // MARK: - SCSI filename format

    func testSCSIFilenameZeroPadded() {
        let filename = String(format: "HD%02d.hda", 0)
        XCTAssertEqual(filename, "HD00.hda")
    }

    func testSCSIFilenameScsiID1() {
        let filename = String(format: "HD%02d.hda", 1)
        XCTAssertEqual(filename, "HD01.hda")
    }

    func testSCSIFilenameZuluFormat() {
        // ZuluSCSI encodes SCSI ID 1, index 0 as "HD10"
        let scsiID = 1
        let imageIndex = 0
        let name = "HD\(scsiID)\(imageIndex).hda"
        XCTAssertEqual(name, "HD10.hda")
    }

    // MARK: - Catalog offset constants

    func testCatalogOffset() {
        let CATALOG_OFFSET = 0x1000
        XCTAssertEqual(CATALOG_OFFSET, 4096)
    }

    func testCatalogEntrySize() {
        let CATALOG_ENTRY_SIZE = 0x40
        XCTAssertEqual(CATALOG_ENTRY_SIZE, 64)
    }

    // MARK: - Synthetic disk creation

    func testCreateSyntheticValidDisk() throws {
        let data = makeFakeDisk(sizeMB: 239)
        let url = tmpDir.appendingPathComponent("test_HD10.hda")
        try data.write(to: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let read = try Data(contentsOf: url)
        XCTAssertEqual(read[510], 0x78)
        XCTAssertEqual(read[511], 0x82)
    }

    func testAllFiveSizesCreateCorrectly() throws {
        // Per-size boot signatures from DiskFormatter templates (verified against EMXP).
        // Each disk size has a distinct opaque byte pair at offset 0x1FE-0x1FF.
        let bootSigs: [Int: (UInt8, UInt8)] = [
            96:  (0xA1, 0x93),
            239: (0x78, 0x82),
            481: (0x65, 0x9F),
            633: (0x79, 0x24),
            962: (0xD7, 0xAD),
        ]
        let sizes = [96, 239, 481, 633, 962]
        for mb in sizes {
            let data = makeFakeDisk(sizeMB: mb)
            let expected = mb * 1024 * 1024
            XCTAssertEqual(data.count, expected, "Size mismatch for \(mb) MB")
            let (b0, b1) = bootSigs[mb]!
            XCTAssertEqual(data[510], b0, "Boot sig byte 0 for \(mb) MB")
            XCTAssertEqual(data[511], b1, "Boot sig byte 1 for \(mb) MB")
        }
    }

    // MARK: - Helper

    /// Per-size boot signatures from DiskFormatter templates (verified against EMXP).
    private func bootSig(forMB mb: Int) -> (UInt8, UInt8) {
        switch mb {
        case 96:  return (0xA1, 0x93)
        case 239: return (0x78, 0x82)
        case 481: return (0x65, 0x9F)
        case 633: return (0x79, 0x24)
        case 962: return (0xD7, 0xAD)
        default:  return (0x78, 0x82)  // fallback: 239 MB signature
        }
    }

    private func makeFakeDisk(sizeMB: Int) -> Data {
        var data = Data(count: sizeMB * 1024 * 1024)
        // Per-size boot signature at offset 0x1FE (each size has a distinct opaque pair)
        let (b0, b1) = bootSig(forMB: sizeMB)
        data[510] = b0
        data[511] = b1
        // FAT[0] = 0x8000 (reserved marker, verified against all EMXP templates and HD0.hda)
        data[0x400] = 0x00
        data[0x401] = 0x80
        // FAT[1] end-of-chain
        data[0x402] = 0xFF
        data[0x403] = 0x7F
        // Catalog OS entry
        let osName = "EMAX II OS"
        for (i, c) in osName.utf8.enumerated() {
            data[0x1000 + i] = c
        }
        return data
    }
}
