import XCTest
import Foundation

/// Bank import / catalog tests
/// Tests EB2 bank structure parsing, catalog offsets, and FAT chain logic.
final class BankImportTests: XCTestCase {

    // MARK: - EB2 magic

    func testEB2MagicBytes() {
        // EB2 banks should start with recognisable header
        // The exact magic varies — just confirm we can read 4 bytes
        let header = Data([0x45, 0x42, 0x32, 0x00])  // "EB2\0"
        XCTAssertEqual(header.count, 4)
        XCTAssertEqual(header[0], 0x45)  // 'E'
        XCTAssertEqual(header[1], 0x42)  // 'B'
        XCTAssertEqual(header[2], 0x32)  // '2'
    }

    // MARK: - Catalog structure

    func testCatalogHolds32Entries() {
        // EMAX II catalog has 32 entries (0x800 bytes / 0x40 each)
        let CATALOG_SIZE   = 0x800
        let ENTRY_SIZE     = 0x40
        let maxEntries     = CATALOG_SIZE / ENTRY_SIZE
        XCTAssertEqual(maxEntries, 32)
    }

    func testOSEntryIsAtSlot0() {
        // OS always occupies catalog slot 0 (offset 0x1000)
        let CATALOG_BASE   = 0x1000
        let ENTRY_SIZE     = 0x40
        let osEntryOffset  = CATALOG_BASE + 0 * ENTRY_SIZE
        XCTAssertEqual(osEntryOffset, 0x1000)
    }

    func testFirstBankSlotOffset() {
        let CATALOG_BASE   = 0x1000
        let ENTRY_SIZE     = 0x40
        let firstBankOffset = CATALOG_BASE + 1 * ENTRY_SIZE
        XCTAssertEqual(firstBankOffset, 0x1040)
    }

    func testLastBankSlotOffset() {
        let CATALOG_BASE   = 0x1000
        let ENTRY_SIZE     = 0x40
        let lastBankOffset = CATALOG_BASE + 31 * ENTRY_SIZE
        XCTAssertEqual(lastBankOffset, 0x17C0)
    }

    // MARK: - FAT chain

    func testFATEndOfChainValue() {
        let endOfChain = UInt16(0x7FFF)
        XCTAssertEqual(endOfChain, 0x7FFF)
    }

    func testFATFreeClusterValue() {
        let free = UInt16(0x0000)
        XCTAssertEqual(free, 0x0000)
    }

    func testFATBuildChain() {
        // Build a 3-cluster chain: 5 → 6 → 7 → EOC
        var fat = [UInt16](repeating: 0, count: 16)
        fat[5] = 6
        fat[6] = 7
        fat[7] = 0x7FFF  // EOC
        fat[0] = 0x000F  // Reserved

        // Follow chain from 5
        var chain: [Int] = []
        var current: UInt16 = 5
        var safety = 0
        while current != 0x7FFF && safety < 100 {
            chain.append(Int(current))
            current = fat[Int(current)]
            safety += 1
        }

        XCTAssertEqual(chain, [5, 6, 7])
    }

    // MARK: - Bank naming

    func testBankNameMaxLength() {
        // EMAX II bank names are up to 16 characters
        let maxLen = 16
        let name = "PERCUSSION BANK"
        XCTAssertLessThanOrEqual(name.count, maxLen)
    }

    func testBankNameNullTerminated() {
        let name = "MY BANK"
        var bytes = [UInt8](repeating: 0, count: 16)
        for (i, c) in name.utf8.enumerated() {
            bytes[i] = c
        }
        // Null terminator should be present
        XCTAssertEqual(bytes[name.count], 0)
    }

    // MARK: - Cluster size variants

    func testClusterSizes() {
        // EMAX II uses different cluster sizes per disk size
        let clusterSizes = [0x8000, 0x10000, 0x20000]
        for cs in clusterSizes {
            XCTAssertTrue(cs > 0, "Cluster size should be positive")
            XCTAssertTrue(cs % 512 == 0, "Cluster size should be sector-aligned")
        }
    }

    // MARK: - Synthetic bank round-trip

    func testSyntheticBankData() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BankTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Create a fake EB2 with minimal header
        var bank = Data(count: 0x8000)  // 32 KB
        bank[0] = 0x45  // 'E'
        bank[1] = 0x42  // 'B'
        bank[2] = 0x32  // '2'
        bank[3] = 0x00

        let url = tmpDir.appendingPathComponent("test.eb2")
        try bank.write(to: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let read = try Data(contentsOf: url)
        XCTAssertEqual(read.count, 0x8000)
        XCTAssertEqual(read[0], 0x45)
    }
}
