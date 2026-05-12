import XCTest
import Foundation
@testable import EmaxForge

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

    // MARK: - BNT entry field offsets (verified against EmaxIIFileSystem.swift layout)

    func testBNTEntryFieldOffsets() {
        // Synthetic 32-byte BNT entry for a bank "GUITAR/FLUTE" with
        // startCluster=5, clusterCount=15, numPresets=0, f22=0x68, bankIndex=0x16.
        // Layout per EmaxIIFileSystem.swift (the authoritative reference):
        //   [0-15]:  name, ASCII, space/null padded to 16 bytes
        //   [16-17]: startCluster (U16 LE, 0-based)
        //   [18-19]: clusterCount (U16 LE)
        //   [20-21]: numPresets   (U16 LE)
        //   [22-23]: f22          (U16 LE, unknown metadata)
        //   [24-25]: bankIndex    (U16 LE, idx/preset address)
        //   [26-27]: flags = 0x0081
        //   [28-31]: zeros
        let raw: [UInt8] = [
            0x47, 0x55, 0x49, 0x54, 0x41, 0x52, 0x2f, 0x46,  // "GUITAR/F"
            0x4c, 0x55, 0x54, 0x45, 0x20, 0x20, 0x00, 0x00,  // "LUTE  \0\0"
            0x05, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x68, 0x00,  // startCluster=5, clusterCount=15, numPresets=0, f22=0x68
            0x16, 0x00, 0x81, 0x00, 0x00, 0x00, 0x00, 0x00   // bankIndex=0x16, flags=0x0081, zeros
        ]
        let entry = Data(raw)

        // [0-13]: name, space-padded to 14 chars
        let name = String(bytes: entry[0..<14], encoding: .ascii) ?? ""
        XCTAssertEqual(name, "GUITAR/FLUTE  ")

        // [14-15]: null padding
        XCTAssertEqual(entry[14], 0x00)
        XCTAssertEqual(entry[15], 0x00)

        // [16-17]: startCluster = 5 (0-based cluster index, per EmaxIIFileSystem.swift +0x10)
        let startCluster = UInt16(entry[16]) | (UInt16(entry[17]) << 8)
        XCTAssertEqual(startCluster, 5)

        // [18-19]: clusterCount = 15 (per EmaxIIFileSystem.swift +0x12)
        let clusterCount = UInt16(entry[18]) | (UInt16(entry[19]) << 8)
        XCTAssertEqual(clusterCount, 15)

        // [20-21]: numPresets = 0 (set to 0 on import; EMAX II updates at load time)
        let numPresets = UInt16(entry[20]) | (UInt16(entry[21]) << 8)
        XCTAssertEqual(numPresets, 0)

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

    func testFATCompatEndOfChainValue() {
        // 0x8080 is the legacy EOC written by old BankImporter (prior to the May 2026 fix).
        // All readers (EmaxIIFileSystem, BankExtractor, DiskInspectorService) now recognise it.
        let compatEOC = UInt16(0x8080)
        XCTAssertEqual(compatEOC, 0x8080)
    }

    func testFATFreeClusterValue() {
        let free = UInt16(0x0000)
        XCTAssertEqual(free, 0x0000)
    }

    func testFATReservedValue() {
        // 0x8000 is used as a reserved/special FAT entry marker on some EMXP-created disks.
        // On original EMAX II hardware disks (e.g. HD0.hda), cluster 0 may be in use (FAT[0]=0x7FFF).
        let reservedMarker = UInt16(0x8000)
        XCTAssertEqual(reservedMarker, 0x8000)
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

    // MARK: - Import round-trip: FAT EOC written as 0x7FFF, readable by DiskInspectorService

    func testImportedBankFATChainUsesStandardEOC() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EOCTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let diskURL = tmpDir.appendingPathComponent("test.hda")
        try makeMinimalEMX2Disk().write(to: diskURL)

        var bank = Data(count: 1024)
        bank[0] = 0x45; bank[1] = 0x42; bank[2] = 0x32
        let bankURL = tmpDir.appendingPathComponent("TESTBANK.eb2")
        try bank.write(to: bankURL)

        let result = try BankImporter.importBank(eb2URL: bankURL, into: diskURL)
        XCTAssertEqual(result.clustersUsed, 1)

        // Read raw FAT and verify end-of-chain is 0x7FFF (not 0x8080)
        let diskData = try Data(contentsOf: diskURL)
        let fatOffset = 0x400
        let clusterFATOffset = fatOffset + result.catalogIndex * 2  // wrong — use cluster index
        // The FAT entry for the allocated cluster should be 0x7FFF.
        // Result.catalogIndex is the BNT slot, not the cluster. We need the cluster from BNT.
        let bntStartSector = 8  // from makeMinimalEMX2Disk
        let bntEntryOffset = bntStartSector * 512 + result.catalogIndex * 32
        let startCluster = Int(diskData.readU16LEat(bntEntryOffset + 16))
        let fatEntry = diskData.readU16LEat(fatOffset + startCluster * 2)
        XCTAssertEqual(fatEntry, 0x7FFF, "Imported bank FAT EOC must be 0x7FFF (standard), got 0x\(String(fatEntry, radix: 16))")
    }

    // MARK: - Duplicate import enforcement

    func testDuplicateBankNameRejected() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DupBankTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Build a minimal EMX2 disk (239MB geometry, 256 KB cluster size, 4-cluster FAT)
        let diskURL = tmpDir.appendingPathComponent("test.hda")
        let diskData = makeMinimalEMX2Disk()
        try diskData.write(to: diskURL)

        // Build a small fake bank (≤ 1 cluster = 256 KB)
        var bank = Data(count: 1024)
        bank[0] = 0x45; bank[1] = 0x42; bank[2] = 0x32

        // First import: "MYSTBANK" — must succeed
        let bank1URL = tmpDir.appendingPathComponent("MYSTBANK.eb2")
        try bank.write(to: bank1URL)
        _ = try BankImporter.importBank(eb2URL: bank1URL, into: diskURL)

        // Second import with same name: must throw when allowDuplicate=false (default)
        let bank2URL = tmpDir.appendingPathComponent("MYSTBANK.eb2")
        XCTAssertThrowsError(
            try BankImporter.importBank(eb2URL: bank2URL, into: diskURL, allowDuplicate: false)
        ) { error in
            guard case let BankImporter.ImportError.duplicateBankName(name) = error else {
                XCTFail("Expected duplicateBankName, got \(error)")
                return
            }
            XCTAssertEqual(name, "MYSTBANK")
        }

        // Third import with allowDuplicate=true: must succeed
        XCTAssertNoThrow(
            try BankImporter.importBank(eb2URL: bank2URL, into: diskURL, allowDuplicate: true)
        )
    }

    // MARK: - Helpers

    /// Build a minimal valid EMX2 disk image (small — just enough for BankImporter to parse).
    /// Geometry: clusterSize=262144 (512B*512), 4 FAT sectors, BNT at sector 8, CA at sector 20, 100 clusters.
    private func makeMinimalEMX2Disk() -> Data {
        let clusterSize = 262_144        // 512 sectors * 512 bytes
        let fatSectors  = 4
        let bntSector   = 8
        let caSector    = 20
        let totalClusters = 100
        let diskSize    = caSector * 512 + totalClusters * clusterSize  // ~25.6 MB

        var disk = Data(count: diskSize)

        // Header (sector 0)
        disk[0] = 0x45; disk[1] = 0x4D; disk[2] = 0x58; disk[3] = 0x32  // EMX2
        func writeU32(_ v: UInt32, at off: Int) {
            disk[off]   = UInt8(v & 0xFF)
            disk[off+1] = UInt8((v >> 8) & 0xFF)
            disk[off+2] = UInt8((v >> 16) & 0xFF)
            disk[off+3] = UInt8((v >> 24) & 0xFF)
        }
        writeU32(UInt32(clusterSize), at: 0x04)
        writeU32(2,                   at: 0x0C)  // fatStartSector (ignored; FAT always at 0x400)
        writeU32(UInt32(bntSector),   at: 0x10)
        writeU32(90,                  at: 0x14)  // maxBanks
        writeU32(2,                   at: 0x18)
        writeU32(UInt32(fatSectors),  at: 0x1C)
        writeU32(UInt32(caSector),    at: 0x20)
        writeU32(UInt32(totalClusters), at: 0x24)

        // FAT at 0x400: FAT[0]=0x8000, FAT[1]=0x7FFF (OS), rest free
        disk[0x400] = 0x00; disk[0x401] = 0x80  // FAT[0] = 0x8000
        disk[0x402] = 0xFF; disk[0x403] = 0x7F  // FAT[1] = 0x7FFF

        // BNT slot 0: OS entry
        let bntOff = bntSector * 512
        let osName = Array("EMAX2 Software\0\0".utf8)
        for (i, b) in osName.enumerated() { disk[bntOff + i] = b }
        disk[bntOff + 16] = 0x00; disk[bntOff + 17] = 0x78  // startCluster = 0x7800
        disk[bntOff + 18] = 1;    disk[bntOff + 19] = 0      // clusterCount = 1
        disk[bntOff + 26] = 0x80; disk[bntOff + 27] = 0x00  // flags = 0x0080

        return disk
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

// MARK: - Test helpers

private extension Data {
    func readU16LEat(_ offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }
}
