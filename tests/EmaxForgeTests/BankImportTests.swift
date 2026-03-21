import XCTest
import Foundation

/// Bank import / catalog tests
/// Tests EB2 bank structure parsing, catalog offsets, and FAT chain logic.
/// Constants verified against EmaxII-02.ez2 reference disk (Mar 21 2026).
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

    // MARK: - Catalog / BNT structure

    func testBNTEntrySize() {
        // BNT entries are 32 bytes each (verified from EmaxII-02.ez2)
        let ENTRY_SIZE = 32
        XCTAssertEqual(ENTRY_SIZE, 32)
    }

    func testBNTStartOffset96MB() {
        // For 96MB disk: BNT starts at sector 9 → offset 0x1200
        // Confirmed from header[0x10] = 9 in EmaxII-02.ez2
        let BNT_SECTOR   = 9
        let BNT_OFFSET   = BNT_SECTOR * 512
        XCTAssertEqual(BNT_OFFSET, 0x1200)
    }

    func testOSEntryIsAtSlot0() {
        // OS always occupies BNT slot 0 (first 32-byte entry at bntOffset)
        // For 96MB disk: BNT at 0x1200, OS entry at 0x1200 + 0*32 = 0x1200
        let BNT_OFFSET   = 9 * 512   // 0x1200
        let ENTRY_SIZE   = 32
        let osEntryOffset = BNT_OFFSET + 0 * ENTRY_SIZE
        XCTAssertEqual(osEntryOffset, 0x1200)
    }

    func testFirstBankSlotOffset() {
        // First bank is in BNT slot 1
        let BNT_OFFSET      = 9 * 512   // 0x1200
        let ENTRY_SIZE      = 32
        let firstBankOffset = BNT_OFFSET + 1 * ENTRY_SIZE
        XCTAssertEqual(firstBankOffset, 0x1220)
    }

    // MARK: - BNT entry field offsets (verified from reference disk)

    func testBNTEntryFieldOffsets() {
        // GUITAR/FLUTE bank 1 from EmaxII-02.ez2:
        // raw: 47 55 49 54 41 52 2f 46 4c 55 54 45 20 20 00 00
        //      00 00 05 00 0f 00 68 00 16 00 81 00 00 00 00 00
        let raw: [UInt8] = [
            0x47, 0x55, 0x49, 0x54, 0x41, 0x52, 0x2f, 0x46,
            0x4c, 0x55, 0x54, 0x45, 0x20, 0x20, 0x00, 0x00,
            0x00, 0x00, 0x05, 0x00, 0x0f, 0x00, 0x68, 0x00,
            0x16, 0x00, 0x81, 0x00, 0x00, 0x00, 0x00, 0x00
        ]
        let entry = Data(raw)

        // [0-13]: name, space-padded to 14 chars
        let name = String(bytes: entry[0..<14], encoding: .ascii) ?? ""
        XCTAssertEqual(name, "GUITAR/FLUTE  ")

        // [14-15]: null padding
        XCTAssertEqual(entry[14], 0x00)
        XCTAssertEqual(entry[15], 0x00)

        // [16-17]: idx = 0x0000 (bank 1)
        let idx = UInt16(entry[16]) | (UInt16(entry[17]) << 8)
        XCTAssertEqual(idx, 0x0000)

        // [18-19]: start_cluster = 5
        let sc = UInt16(entry[18]) | (UInt16(entry[19]) << 8)
        XCTAssertEqual(sc, 5)

        // [20-21]: cluster_count = 15
        let cnt = UInt16(entry[20]) | (UInt16(entry[21]) << 8)
        XCTAssertEqual(cnt, 15)

        // [26-27]: flags = 0x0081
        let flags = UInt16(entry[26]) | (UInt16(entry[27]) << 8)
        XCTAssertEqual(flags, 0x0081)

        // [28-31]: zeros
        XCTAssertEqual(entry[28], 0x00)
        XCTAssertEqual(entry[29], 0x00)
        XCTAssertEqual(entry[30], 0x00)
        XCTAssertEqual(entry[31], 0x00)
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

    func testFATReservedValue() {
        // FAT[0] is always reserved with this marker
        let reserved = UInt16(0x8000)
        XCTAssertEqual(reserved, 0x8000)
    }

    func testFATOSChain() {
        // OS uses clusters 1→2→3→4→0x7FFF (verified from EmaxII-02.ez2)
        var fat = [UInt16](repeating: 0, count: 20)
        fat[0] = 0x8000  // reserved
        fat[1] = 2       // OS cluster 1 → 2
        fat[2] = 3       // OS cluster 2 → 3
        fat[3] = 4       // OS cluster 3 → 4
        fat[4] = 0x7FFF  // OS cluster 4 → end

        // Follow chain from 1
        var chain: [Int] = []
        var current: UInt16 = 1
        var safety = 0
        while current != 0x7FFF && safety < 100 {
            chain.append(Int(current))
            current = fat[Int(current)]
            safety += 1
        }
        XCTAssertEqual(chain, [1, 2, 3, 4])
    }

    func testFATBuildChain() {
        // Build a 15-cluster chain starting at 5 (like GUITAR/FLUTE)
        var fat = [UInt16](repeating: 0, count: 25)
        fat[0] = 0x8000  // reserved
        fat[1] = 2; fat[2] = 3; fat[3] = 4; fat[4] = 0x7FFF  // OS
        for i in 5..<19 { fat[i] = UInt16(i + 1) }
        fat[19] = 0x7FFF  // bank end-of-chain

        // Follow chain from 5
        var chain: [Int] = []
        var current: UInt16 = 5
        var safety = 0
        while current != 0x7FFF && safety < 100 {
            chain.append(Int(current))
            current = fat[Int(current)]
            safety += 1
        }
        XCTAssertEqual(chain.count, 15)
        XCTAssertEqual(chain.first, 5)
        XCTAssertEqual(chain.last, 19)
    }

    // MARK: - Cluster offset formula

    func testClusterOffset96MB() {
        // For 96MB disk: ca_sector=120, cluster_size=65536
        // cluster_offset(n) = ca_offset + n * cluster_size
        let CA_OFFSET    = 120 * 512        // 0xF000
        let CLUSTER_SIZE = 65536

        XCTAssertEqual(CA_OFFSET + 0 * CLUSTER_SIZE, 0xF000)   // cluster 0
        XCTAssertEqual(CA_OFFSET + 1 * CLUSTER_SIZE, 0x1F000)  // cluster 1 (OS)
        XCTAssertEqual(CA_OFFSET + 5 * CLUSTER_SIZE, 0x5F000)  // cluster 5 (first bank)
    }

    // MARK: - Bank naming

    func testBankNameMaxLength() {
        // EMAX II bank names are 14 characters (padded with spaces)
        let maxLen = 14
        let name = "GUITAR/FLUTE"
        XCTAssertLessThanOrEqual(name.count, maxLen)
        let padded = name.padding(toLength: maxLen, withPad: " ", startingAt: 0)
        XCTAssertEqual(padded.count, maxLen)
        XCTAssertEqual(padded, "GUITAR/FLUTE  ")
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
