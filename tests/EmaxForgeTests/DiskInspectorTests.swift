import XCTest
import Foundation
@testable import EmaxForge

/// Unit tests for DiskInspectorService.
/// All tests use synthetic in-memory disk images written to temp files — no real .hda needed.
///
/// Disk layout used in helpers:
///   sector  0    : header (512 bytes)
///   sector  2    : FAT at 0x400 (2 sectors = 1 KB = 512 UInt16 entries)
///   sectors 9-23 : BNT at 9*512 = 0x1200 (15 sectors = 7680 bytes, max 240 entries)
///   sectors 24+  : cluster area (16 clusters × 512 bytes)
///
/// Total = (24 + 16) × 512 = 20 480 bytes
final class DiskInspectorTests: XCTestCase {

    // MARK: - Error cases

    func testFileTooSmall() throws {
        let url = try writeTempData(Data(count: 100))
        XCTAssertThrowsError(try DiskInspectorService.inspectDisk(at: url)) { error in
            guard case DiskInspectorService.InspectionError.fileTooSmall = error else {
                XCTFail("Expected fileTooSmall, got \(error)")
                return
            }
        }
    }

    func testInvalidMagic() throws {
        var data = Data(count: 0x2000)
        data[0] = 0x00; data[1] = 0x00; data[2] = 0x00; data[3] = 0x00
        let url = try writeTempData(data)
        XCTAssertThrowsError(try DiskInspectorService.inspectDisk(at: url)) { error in
            guard case DiskInspectorService.InspectionError.invalidMagic = error else {
                XCTFail("Expected invalidMagic, got \(error)")
                return
            }
        }
    }

    func testWrongMagicString() throws {
        var data = Data(count: 0x2000)
        "WRONG".utf8.enumerated().forEach { data[$0.offset] = $0.element }
        let url = try writeTempData(data)
        XCTAssertThrowsError(try DiskInspectorService.inspectDisk(at: url)) { error in
            guard case DiskInspectorService.InspectionError.invalidMagic(let found) = error else {
                XCTFail("Expected invalidMagic"); return
            }
            XCTAssertFalse(found.contains("EMX2"))
        }
    }

    // MARK: - Header parsing

    func testHeaderMagic() throws {
        let image = buildMinimalImage()
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        XCTAssertEqual(result.header.magic, "EMX2")
    }

    func testHeaderImageSize() throws {
        let image = buildMinimalImage()
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        XCTAssertEqual(result.header.imageSize, image.count)
    }

    func testHeaderClusterSizeComputed() throws {
        // 40 sectors total, CA starts at sector 24, 16 clusters → 1 sector/cluster = 512 bytes
        let image = buildMinimalImage()
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        XCTAssertEqual(result.header.clusterSize, 512)
        XCTAssertEqual(result.header.totalClusters, 16)
    }

    func testHeaderFATOffset() throws {
        let image = buildMinimalImage()
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        XCTAssertEqual(result.header.fatOffset, 0x400)
    }

    func testHeaderBNTOffset() throws {
        // bntStartSector = 9 → 9 * 512 = 0x1200
        let image = buildMinimalImage()
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        XCTAssertEqual(result.header.bntOffset, UInt64(9 * 512))
    }

    func testHeaderBootSignaturePresent() throws {
        let image = buildMinimalImage(withBootSig: true)
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        XCTAssertEqual(result.header.bootSignature.0, 0xA1)
        XCTAssertEqual(result.header.bootSignature.1, 0x93)
    }

    func testHeaderBootSignatureMissing() throws {
        let image = buildMinimalImage(withBootSig: false)
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        XCTAssertEqual(result.header.bootSignature.0, 0x00)
        XCTAssertEqual(result.header.bootSignature.1, 0x00)
    }

    // MARK: - FAT summary

    func testFATFreeClusters() throws {
        // Clusters 0=reserved, 1-4=OS, 5+ free → free = 16 - 5 = 11, but total = 512 entries
        let image = buildMinimalImage()
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        // FAT has 512 entries (2 sectors × 256 each)
        XCTAssertEqual(result.fat.totalEntries, 512)
        // cluster 0 = 0x8000 → reserved
        XCTAssertEqual(result.fat.reservedClusters, 1)
        // clusters 1-4 = used (OS chain)
        // remaining 507 = free
        XCTAssertEqual(result.fat.freeClusters, 507)
        XCTAssertEqual(result.fat.usedClusters, 4)  // clusters 1→2→3→4→EOC
    }

    func testFATUsedWithBank() throws {
        let image = buildMinimalImage(numBanks: 1)
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        // OS: clusters 1,2,3,4 (4 used) + bank: clusters 5,6 (2 used) = 6 used
        XCTAssertEqual(result.fat.usedClusters, 6)
    }

    // MARK: - Bank parsing

    func testNoBanksOnEmptyDisk() throws {
        let image = buildMinimalImage(numBanks: 0)
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        // OS entry may appear but no user banks (we don't add any in slot 1+)
        let userBanks = result.banks.filter { $0.catalogIndex > 0 }
        XCTAssertEqual(userBanks.count, 0)
    }

    func testBankName() throws {
        let image = buildMinimalImage(numBanks: 1)
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        let bank = try XCTUnwrap(result.banks.first { $0.catalogIndex == 1 })
        XCTAssertEqual(bank.name, "TESTBANK")
    }

    func testBankStartCluster() throws {
        let image = buildMinimalImage(numBanks: 1)
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        let bank = try XCTUnwrap(result.banks.first { $0.catalogIndex == 1 })
        XCTAssertEqual(bank.startCluster, 5)
    }

    func testBankClusterCount() throws {
        let image = buildMinimalImage(numBanks: 1)
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        let bank = try XCTUnwrap(result.banks.first { $0.catalogIndex == 1 })
        XCTAssertEqual(bank.clusterCount, 2)
    }

    func testBankFlags() throws {
        let image = buildMinimalImage(numBanks: 1)
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        let bank = try XCTUnwrap(result.banks.first { $0.catalogIndex == 1 })
        XCTAssertEqual(bank.flags, 0x0081)
    }

    func testBankFATChainValid() throws {
        let image = buildMinimalImage(numBanks: 1)
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        let bank = try XCTUnwrap(result.banks.first { $0.catalogIndex == 1 })
        XCTAssertTrue(bank.fatChainValid)
        XCTAssertEqual(bank.fatChain, [5, 6])
    }

    func testBankSizeBytes() throws {
        let image = buildMinimalImage(numBanks: 1)
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        let bank = try XCTUnwrap(result.banks.first { $0.catalogIndex == 1 })
        // 2 clusters × 512 bytes = 1024 bytes
        XCTAssertEqual(bank.sizeBytes, 2 * 512)
    }

    // MARK: - OS info

    func testOSChainPresent() throws {
        let image = buildMinimalImage()
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        let os = try XCTUnwrap(result.os)
        XCTAssertEqual(os.startCluster, 1)
        XCTAssertEqual(os.clusterChain, [1, 2, 3, 4])
    }

    func testOSSizeBytes() throws {
        let image = buildMinimalImage()
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        let os = try XCTUnwrap(result.os)
        // 4 clusters × 512 bytes = 2048 bytes
        XCTAssertEqual(os.sizeBytes, 4 * 512)
    }

    func testNoOSWhenFAT1IsZero() throws {
        var image = buildMinimalImage()
        // Overwrite FAT[1] with 0x0000 (free)
        image[0x400 + 1*2] = 0x00
        image[0x400 + 1*2 + 1] = 0x00
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        XCTAssertNil(result.os)
    }

    // MARK: - Health warnings

    func testHealthNoWarningsOnCleanDisk() throws {
        let image = buildMinimalImage(numBanks: 1, withBootSig: true)
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        XCTAssertTrue(result.health.isEmpty, "Expected no health warnings, got: \(result.health)")
    }

    func testHealthMissingBootSig() throws {
        let image = buildMinimalImage(withBootSig: false)
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        XCTAssertTrue(result.health.contains(.missingBootSignature))
    }

    func testHealthBrokenFATChain() throws {
        var image = buildMinimalImage(numBanks: 1, withBootSig: true)
        // Break the bank FAT chain: set FAT[5] to 0x0000 (free cluster = broken)
        image[0x400 + 5*2]     = 0x00
        image[0x400 + 5*2 + 1] = 0x00
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)

        let hasBroken = result.health.contains { warning in
            if case .brokenFATChain(let name, _) = warning { return name == "TESTBANK" }
            return false
        }
        XCTAssertTrue(hasBroken, "Expected brokenFATChain warning for TESTBANK")
    }

    func testHealthOrphanClusters() throws {
        var image = buildMinimalImage(withBootSig: true)
        // Allocate cluster 10 in FAT without any bank referencing it
        image[0x400 + 10*2]     = 0xFF
        image[0x400 + 10*2 + 1] = 0x7F  // 0x7FFF = end-of-chain but unreferenced
        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)

        let hasOrphan = result.health.contains { warning in
            if case .orphanClusters(let list) = warning { return list.contains(10) }
            return false
        }
        XCTAssertTrue(hasOrphan, "Expected orphanClusters warning for cluster 10")
    }

    func testHealthDuplicateAllocations() throws {
        var image = buildMinimalImage(numBanks: 1, withBootSig: true)
        // Add a second bank also starting at cluster 5 (same as first → duplicate)
        let bntBase = 9 * 512
        let slot2 = bntBase + 2 * 32

        let name2 = "BANK2         "
        for (i, ch) in name2.utf8.prefix(14).enumerated() { image[slot2 + i] = ch }
        image[slot2 + 14] = 0x00; image[slot2 + 15] = 0x00
        // BNT layout: bankIndex at +16, startCluster at +18
        // bankIndex = 0x0100 (second user bank)
        image[slot2 + 16] = 0x00; image[slot2 + 17] = 0x01
        // startCluster = 5 (same as TESTBANK → duplicate allocation!)
        image[slot2 + 18] = 0x05; image[slot2 + 19] = 0x00
        // numPresets = 0
        image[slot2 + 20] = 0x00; image[slot2 + 21] = 0x00
        // flags = 0x0081
        image[slot2 + 26] = 0x81; image[slot2 + 27] = 0x00

        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)

        let hasDupe = result.health.contains { warning in
            if case .duplicateAllocations(let clusters) = warning {
                return clusters.contains(5)
            }
            return false
        }
        XCTAssertTrue(hasDupe, "Expected duplicateAllocations warning for cluster 5")
    }

    // MARK: - traceChainValidated (tested directly)

    func testTraceChainNormal() {
        var fat = [UInt16](repeating: 0, count: 20)
        fat[5] = 6; fat[6] = 7; fat[7] = 0x7FFF
        let (chain, valid) = DiskInspectorService.traceChainValidated(fat: fat, start: 5)
        XCTAssertEqual(chain, [5, 6, 7])
        XCTAssertTrue(valid)
    }

    func testTraceChainCycleDetected() {
        var fat = [UInt16](repeating: 0, count: 20)
        fat[5] = 6; fat[6] = 5  // cycle: 5→6→5
        let (_, valid) = DiskInspectorService.traceChainValidated(fat: fat, start: 5)
        XCTAssertFalse(valid)
    }

    func testTraceChainOutOfBounds() {
        var fat = [UInt16](repeating: 0, count: 10)
        fat[5] = 99  // 99 >= fat.count
        let (_, valid) = DiskInspectorService.traceChainValidated(fat: fat, start: 5)
        XCTAssertFalse(valid)
    }

    func testTraceChainPrematureFreeCluster() {
        var fat = [UInt16](repeating: 0, count: 20)
        fat[5] = 6; fat[6] = 0x0000  // unexpected free
        let (chain, valid) = DiskInspectorService.traceChainValidated(fat: fat, start: 5)
        XCTAssertEqual(chain, [5, 6])
        XCTAssertFalse(valid)
    }

    func testTraceOSChainStandard() {
        var fat = [UInt16](repeating: 0, count: 20)
        fat[0] = 0x8000
        fat[1] = 2; fat[2] = 3; fat[3] = 4; fat[4] = 0x7FFF
        let chain = DiskInspectorService.traceOSChain(fat: fat)
        XCTAssertEqual(chain, [1, 2, 3, 4])
    }

    func testTraceOSChainAbsentWhenFATIsZero() {
        var fat = [UInt16](repeating: 0, count: 10)
        fat[0] = 0x8000; fat[1] = 0x0000
        let chain = DiskInspectorService.traceOSChain(fat: fat)
        XCTAssertTrue(chain.isEmpty)
    }

    // MARK: - GUITAR/FLUTE reference BNT entry

    func testReferenceGUITARFLUTEBankEntry() throws {
        // Build image with a GUITAR/FLUTE BNT entry using the correct field layout.
        // Layout per BANK_HANDLING_ANALYSIS.md (authoritative, verified against real EMAX II disks):
        //   [0-15]:  name (16 bytes)
        //   [16-17]: bankIndex = 0x0000 (first user bank; (n-1)*256 formula)
        //   [18-19]: startCluster = 5 (actual FAT cluster — what EMAX II hardware reads)
        //   [20-21]: numPresets = 0
        //   [22-23]: fieldA = 0x68 (unknown)
        //   [24-25]: fieldB = 0x16 (unknown)
        //   [26-27]: flags = 0x0081
        var image = buildMinimalImage(withBootSig: true)

        // Set FAT chain for cluster 5→6→...→19→0x7FFF (15 clusters)
        for i in 5..<19 { image[0x400 + i*2] = UInt8(i + 1); image[0x400 + i*2 + 1] = 0x00 }
        image[0x400 + 19*2] = 0xFF; image[0x400 + 19*2 + 1] = 0x7F  // 0x7FFF

        // Write BNT entry with correct layout: bankIndex at +16, startCluster at +18
        let raw: [UInt8] = [
            0x47, 0x55, 0x49, 0x54, 0x41, 0x52, 0x2F, 0x46,  // "GUITAR/F"
            0x4C, 0x55, 0x54, 0x45, 0x20, 0x20, 0x00, 0x00,  // "LUTE  \0\0"
            0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x68, 0x00,  // bankIndex=0x0000, startCluster=5, numPresets=0, fieldA=0x68
            0x16, 0x00, 0x81, 0x00, 0x00, 0x00, 0x00, 0x00   // fieldB=0x16, flags=0x0081, zeros
        ]
        let bntSlot1 = 9 * 512 + 1 * 32
        for (i, b) in raw.enumerated() { image[bntSlot1 + i] = b }

        let url = try writeTempData(image)
        let result = try DiskInspectorService.inspectDisk(at: url)
        let bank = try XCTUnwrap(result.banks.first { $0.name == "GUITAR/FLUTE" })

        XCTAssertEqual(bank.startCluster, 5)   // startCluster at BNT +0x12 (offset 18)
        XCTAssertEqual(bank.clusterCount, 15)  // derived from FAT chain length
        XCTAssertEqual(bank.flags, 0x0081)
        XCTAssertTrue(bank.fatChainValid)
        XCTAssertEqual(bank.fatChain.count, 15)
        XCTAssertEqual(bank.fatChain.first, 5)
        XCTAssertEqual(bank.fatChain.last, 19)
    }

    // MARK: - Test helpers

    /// Build a minimal but structurally complete EMAX II disk image in memory.
    private func buildMinimalImage(
        numBanks: Int = 0,
        withBootSig: Bool = true
    ) -> Data {
        let bntStartSector  = 9
        let maxBanks        = 8
        let fatSectors      = 2   // 1 KB = 512 UInt16 entries
        let caStartSector   = 24
        let totalClusters   = 16
        let diskSectors     = caStartSector + totalClusters  // 40

        var image = Data(count: diskSectors * 512)

        // --- Header at offset 0 ---
        image.writeASCII("EMX2", at: 0)
        image.writeU32LE(UInt32(bntStartSector),  at: 0x10)
        image.writeU32LE(UInt32(maxBanks),         at: 0x14)
        image.writeU32LE(UInt32(fatSectors),       at: 0x1C)
        image.writeU32LE(UInt32(caStartSector),    at: 0x20)
        image.writeU32LE(UInt32(totalClusters),    at: 0x24)

        if withBootSig {
            image[0x1FE] = 0xA1
            image[0x1FF] = 0x93
        }

        // --- FAT at 0x400 ---
        // cluster 0: reserved (0x8000)
        image.writeU16LE(0x8000, at: 0x400 + 0*2)
        // OS chain: 1→2→3→4→0x7FFF
        image.writeU16LE(2,      at: 0x400 + 1*2)
        image.writeU16LE(3,      at: 0x400 + 2*2)
        image.writeU16LE(4,      at: 0x400 + 3*2)
        image.writeU16LE(0x7FFF, at: 0x400 + 4*2)

        if numBanks >= 1 {
            // Bank 1: cluster 5→6→0x7FFF
            image.writeU16LE(6,      at: 0x400 + 5*2)
            image.writeU16LE(0x7FFF, at: 0x400 + 6*2)

            // --- BNT entry at slot 1 (slot 0 = OS, skipped as all-zero) ---
            let slot1 = bntStartSector * 512 + 1 * 32
            // name: "TESTBANK      \0\0" (14 chars + 2 null bytes = 16 bytes)
            let name = "TESTBANK      "
            for (i, ch) in name.utf8.prefix(14).enumerated() { image[slot1 + i] = ch }
            image[slot1 + 14] = 0x00
            image[slot1 + 15] = 0x00
            // BNT layout (verified vs BANK_HANDLING_ANALYSIS.md):
            // +0x10 (offset 16): bankIndex = 0x0000 (first user bank)
            image.writeU16LE(0x0000, at: slot1 + 16)
            // +0x12 (offset 18): startCluster = 5 (actual FAT start cluster)
            image.writeU16LE(5,      at: slot1 + 18)
            // +0x14 (offset 20): numPresets = 0
            image.writeU16LE(0,      at: slot1 + 20)
            // +0x16 (offset 22): fieldA = 0
            image.writeU16LE(0x0000, at: slot1 + 22)
            // +0x18 (offset 24): fieldB = 0
            image.writeU16LE(0x0000, at: slot1 + 24)
            // +0x1A (offset 26): flags = 0x0081
            image.writeU16LE(0x0081, at: slot1 + 26)
        }

        return image
    }

    private func writeTempData(_ data: Data) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiskInspectorTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("test.hda")
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return url
    }
}

// MARK: - Data write helpers (test-local)

private extension Data {
    mutating func writeU16LE(_ value: UInt16, at offset: Int) {
        guard offset + 1 < count else { return }
        self[offset]     = UInt8(value & 0xFF)
        self[offset + 1] = UInt8(value >> 8)
    }

    mutating func writeU32LE(_ value: UInt32, at offset: Int) {
        guard offset + 3 < count else { return }
        self[offset]     = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8)  & 0xFF)
        self[offset + 2] = UInt8((value >> 16) & 0xFF)
        self[offset + 3] = UInt8((value >> 24) & 0xFF)
    }

    mutating func writeASCII(_ string: String, at offset: Int) {
        for (i, byte) in string.utf8.enumerated() {
            guard offset + i < count else { break }
            self[offset + i] = byte
        }
    }
}
