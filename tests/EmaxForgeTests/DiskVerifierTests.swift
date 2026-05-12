import XCTest
import Foundation
@testable import EmaxForge

/// Unit tests for DiskVerifier.verify() — the structural integrity checker.
///
/// All tests use synthetic in-memory disk images written to temp files.
/// Disk layout (identical to DiskInspectorTests helper):
///   sector  0    : header (512 bytes) — EMX2 magic + geometry fields
///   sectors 2-3  : FAT at 0x400 (2 × 512 = 1024 bytes → 512 UInt16 entries)
///   sectors 9-23 : BNT at 0x1200 (15 × 512 = 7680 bytes → 240 32-byte entries)
///   sectors 24+  : cluster area (16 × 512 = 8192 bytes)
///   Total        : 40 × 512 = 20 480 bytes
final class DiskVerifierTests: XCTestCase {

    // MARK: - File-level error cases

    func testVerifyRejectsFileSmallerThan0x2000() throws {
        let url = try writeTempData(Data(count: 0x1FFF))
        let result = DiskVerifier.verify(imageURL: url)
        XCTAssertFalse(result.passed)
        let fileCheck = result.checks.first { $0.name == "File size" }
        XCTAssertNotNil(fileCheck)
        XCTAssertFalse(fileCheck!.passed)
    }

    func testVerifyRejectsWrongMagic() throws {
        var data = Data(count: 0x2000)
        "FAKE".utf8.enumerated().forEach { data[$0.offset] = $0.element }
        let url = try writeTempData(data)
        let result = DiskVerifier.verify(imageURL: url)
        XCTAssertFalse(result.passed)
        let magicCheck = result.checks.first { $0.name == "EMX2 magic" }
        XCTAssertNotNil(magicCheck)
        XCTAssertFalse(magicCheck!.passed)
    }

    func testVerifyRejectsZeroMagic() throws {
        let url = try writeTempData(Data(count: 0x5000))
        let result = DiskVerifier.verify(imageURL: url)
        XCTAssertFalse(result.passed)
    }

    // MARK: - Valid minimal disk

    func testVerifyPassesMinimalValidDisk() throws {
        let image = buildMinimalImage()
        let url = try writeTempData(image)
        let result = DiskVerifier.verify(imageURL: url)
        // Collect any failed checks for a clear failure message
        let failed = result.checks.filter { !$0.passed }.map { "\($0.name): \($0.detail)" }
        XCTAssertTrue(result.passed, "Failed checks: \(failed); warnings: \(result.warnings)")
    }

    func testVerifyPassedResultHasNoWarnings() throws {
        let image = buildMinimalImage()
        let url = try writeTempData(image)
        let result = DiskVerifier.verify(imageURL: url)
        XCTAssertTrue(result.warnings.isEmpty, "Unexpected warnings: \(result.warnings)")
    }

    // MARK: - VerifyResult summary text

    func testSummaryAllPassedMessage() throws {
        let image = buildMinimalImage()
        let url = try writeTempData(image)
        let result = DiskVerifier.verify(imageURL: url)
        XCTAssertTrue(result.summary.contains("passed"), "Summary: \(result.summary)")
        XCTAssertFalse(result.summary.contains("FAILED"), "Unexpected failure in summary: \(result.summary)")
    }

    func testSummaryContainsFailedOnBadDisk() throws {
        var data = Data(count: 0x2000)
        "BADM".utf8.enumerated().forEach { data[$0.offset] = $0.element }
        let url = try writeTempData(data)
        let result = DiskVerifier.verify(imageURL: url)
        XCTAssertTrue(result.summary.contains("FAILED") || !result.passed)
    }

    func testQuickVerifyReturnsOKForValidDisk() throws {
        let image = buildMinimalImage()
        let url = try writeTempData(image)
        let (ok, summary) = DiskVerifier.quickVerify(imageURL: url)
        XCTAssertTrue(ok, "quickVerify failed: \(summary)")
        XCTAssertFalse(summary.isEmpty)
    }

    func testQuickVerifyReturnsFalseForInvalidDisk() throws {
        let url = try writeTempData(Data(count: 100))
        let (ok, _) = DiskVerifier.quickVerify(imageURL: url)
        XCTAssertFalse(ok)
    }

    // MARK: - FAT checks

    func testVerifyFATReservedEntryCheck() throws {
        // FAT[0] must be 0x8000; corrupt it to trigger check failure
        var image = buildMinimalImage()
        image.writeU16LE(0x0000, at: 0x400 + 0)   // FAT[0] = 0 (wrong)
        let url = try writeTempData(image)
        let result = DiskVerifier.verify(imageURL: url)
        let fatCheck = result.checks.first { $0.name == "FAT[0] reserved" }
        XCTAssertNotNil(fatCheck)
        XCTAssertFalse(fatCheck!.passed, "FAT[0]=0x0000 should fail the reserved check")
    }

    func testVerifyFATReservedEntryPassesWhenCorrect() throws {
        let image = buildMinimalImage()
        let url = try writeTempData(image)
        let result = DiskVerifier.verify(imageURL: url)
        let fatCheck = result.checks.first { $0.name == "FAT[0] reserved" }
        XCTAssertNotNil(fatCheck)
        XCTAssertTrue(fatCheck!.passed)
    }

    func testVerifyFATChainIntegrityPassesForSimpleChain() throws {
        // The minimal image has a clean OS chain (1→2→3→4→0x7FFF); no loops expected
        let image = buildMinimalImage()
        let url = try writeTempData(image)
        let result = DiskVerifier.verify(imageURL: url)
        let chainCheck = result.checks.first { $0.name == "FAT chain integrity" }
        XCTAssertNotNil(chainCheck)
        XCTAssertTrue(chainCheck!.passed, "Chain detail: \(chainCheck!.detail)")
    }

    func testVerifyFATEntriesCheckPasses() throws {
        let image = buildMinimalImage()
        let url = try writeTempData(image)
        let result = DiskVerifier.verify(imageURL: url)
        let entryCheck = result.checks.first { $0.name == "FAT entries" }
        XCTAssertNotNil(entryCheck)
        XCTAssertTrue(entryCheck!.passed)
    }

    // MARK: - BNT / OS checks

    func testVerifyDetectsOSEntry() throws {
        let image = buildMinimalImage(withOS: true)
        let url = try writeTempData(image)
        let result = DiskVerifier.verify(imageURL: url)
        let osCheck = result.checks.first { $0.name == "OS entry" }
        XCTAssertNotNil(osCheck, "OS entry check should appear when OS is present")
    }

    func testVerifyOSEntryPassesWithCorrectLayout() throws {
        // bankIndex=0x7800 at BNT+16, startCluster=1 at BNT+18 → valid
        let image = buildMinimalImage(withOS: true)
        let url = try writeTempData(image)
        let result = DiskVerifier.verify(imageURL: url)
        let osCheck = result.checks.first { $0.name == "OS entry" }
        XCTAssertTrue(osCheck?.passed ?? false,
                      "OS entry should pass. Detail: \(osCheck?.detail ?? "n/a")")
    }

    func testVerifyOSEntryFailsIfStartClusterWrong() throws {
        // Write bankIndex=0x7800 but startCluster=0 (invalid)
        var image = buildMinimalImage(withOS: true)
        let bntOffset = 9 * 512  // bntStartSector=9
        // slot 0 = OS entry
        image.writeU16LE(0x7800, at: bntOffset + 16)  // bankIndex = 0x7800
        image.writeU16LE(0x0000, at: bntOffset + 18)  // startCluster = 0 (wrong!)
        let url = try writeTempData(image)
        let result = DiskVerifier.verify(imageURL: url)
        let osCheck = result.checks.first { $0.name == "OS entry" }
        XCTAssertNotNil(osCheck)
        XCTAssertFalse(osCheck!.passed,
                       "OS entry with startCluster=0 should fail. Detail: \(osCheck!.detail)")
    }

    // MARK: - Bank count

    func testVerifyBankCountCheckPresent() throws {
        let image = buildMinimalImage(numBanks: 1)
        let url = try writeTempData(image)
        let result = DiskVerifier.verify(imageURL: url)
        let bankCheck = result.checks.first { $0.name == "Bank count" }
        XCTAssertNotNil(bankCheck)
        XCTAssertTrue(bankCheck!.passed)
        XCTAssertTrue(bankCheck!.detail.contains("1"), "Detail should mention 1 bank: \(bankCheck!.detail)")
    }

    func testVerifyZeroBanksAllowed() throws {
        let image = buildMinimalImage(numBanks: 0)
        let url = try writeTempData(image)
        let result = DiskVerifier.verify(imageURL: url)
        let bankCheck = result.checks.first { $0.name == "Bank count" }
        XCTAssertNotNil(bankCheck)
        XCTAssertTrue(bankCheck!.passed)
    }

    // MARK: - Cluster conflicts

    func testVerifyNoClusterConflictsOnCleanDisk() throws {
        let image = buildMinimalImage(numBanks: 1)
        let url = try writeTempData(image)
        let result = DiskVerifier.verify(imageURL: url)
        let conflictCheck = result.checks.first { $0.name == "No cluster conflicts" }
        XCTAssertNotNil(conflictCheck)
        XCTAssertTrue(conflictCheck!.passed)
    }

    func testVerifyDetectsClusterConflict() throws {
        // Two banks both claim cluster 5
        var image = buildMinimalImage(numBanks: 1)
        // Add a second BNT slot also claiming cluster 5
        let bntBase = 9 * 512
        let slot2 = bntBase + 2 * 32
        let name = "BANK2         "
        for (i, ch) in name.utf8.prefix(14).enumerated() { image[slot2 + i] = ch }
        image[slot2 + 14] = 0x00; image[slot2 + 15] = 0x00
        image.writeU16LE(0x0100, at: slot2 + 16)  // bankIndex = 0x0100 (second user bank)
        image.writeU16LE(5,      at: slot2 + 18)  // startCluster = 5 — CONFLICT with slot 1
        image.writeU16LE(0x0081, at: slot2 + 26)  // flags = active
        let url = try writeTempData(image)
        let result = DiskVerifier.verify(imageURL: url)
        let conflictCheck = result.checks.first { $0.name == "No cluster conflicts" }
        XCTAssertNotNil(conflictCheck)
        XCTAssertFalse(conflictCheck!.passed, "Two banks claiming cluster 5 should trigger conflict")
    }

    // MARK: - Cluster area bounds

    func testVerifyClusterAreaBoundsPass() throws {
        let image = buildMinimalImage()
        let url = try writeTempData(image)
        let result = DiskVerifier.verify(imageURL: url)
        let boundsCheck = result.checks.first { $0.name == "Cluster area bounds" }
        XCTAssertNotNil(boundsCheck)
        XCTAssertTrue(boundsCheck!.passed, "Detail: \(boundsCheck!.detail)")
    }

    // MARK: - Checks collection

    func testVerifyCheckCountForCleanDisk() throws {
        let image = buildMinimalImage()
        let url = try writeTempData(image)
        let result = DiskVerifier.verify(imageURL: url)
        // Minimum expected check names
        let checkNames = result.checks.map(\.name)
        XCTAssertTrue(checkNames.contains("EMX2 magic"))
        XCTAssertTrue(checkNames.contains("FAT[0] reserved"))
        XCTAssertTrue(checkNames.contains("FAT entries"))
        XCTAssertTrue(checkNames.contains("FAT chain integrity"))
        XCTAssertTrue(checkNames.contains("Bank count"))
        XCTAssertTrue(checkNames.contains("No cluster conflicts"))
        XCTAssertTrue(checkNames.contains("Cluster area bounds"))
    }

    // MARK: - printReport smoke test

    func testPrintReportDoesNotCrash() throws {
        let image = buildMinimalImage()
        let url = try writeTempData(image)
        // Just ensure it doesn't crash — output goes to console
        DiskVerifier.printReport(imageURL: url)
    }

    // MARK: - Helpers

    /// Build a minimal valid EMX2 disk image.
    ///
    /// - Parameters:
    ///   - numBanks: Number of user bank BNT entries to write (0 or 1).
    ///   - withOS: If true, write OS BNT entry at slot 0 with bankIndex=0x7800, startCluster=1.
    private func buildMinimalImage(numBanks: Int = 0, withOS: Bool = false) -> Data {
        let bntStartSector  = 9
        let maxBanks        = 90
        let fatSectors      = 2   // 2 × 512 = 1024 bytes → 512 entries
        let caStartSector   = 24
        let totalClusters   = 16
        let clusterSize     = 512
        let diskSectors     = caStartSector + totalClusters   // 40

        var image = Data(count: diskSectors * 512)

        // --- Header ---
        image.writeASCII("EMX2", at: 0)
        image.writeU32LE(UInt32(clusterSize),      at: 0x04)
        image.writeU32LE(UInt32(bntStartSector),   at: 0x10)
        image.writeU32LE(UInt32(maxBanks),          at: 0x14)
        image.writeU32LE(UInt32(fatSectors),        at: 0x1C)
        image.writeU32LE(UInt32(caStartSector),     at: 0x20)
        image.writeU32LE(UInt32(totalClusters),     at: 0x24)

        // --- FAT at 0x400 ---
        image.writeU16LE(0x8000, at: 0x400 + 0*2)   // FAT[0] reserved
        // OS chain: 1→2→3→4→0x7FFF
        image.writeU16LE(2,      at: 0x400 + 1*2)
        image.writeU16LE(3,      at: 0x400 + 2*2)
        image.writeU16LE(4,      at: 0x400 + 3*2)
        image.writeU16LE(0x7FFF, at: 0x400 + 4*2)

        if numBanks >= 1 {
            // Bank 1 chain: 5→6→0x7FFF
            image.writeU16LE(6,      at: 0x400 + 5*2)
            image.writeU16LE(0x7FFF, at: 0x400 + 6*2)
        }

        let bntBase = bntStartSector * 512

        // --- OS BNT entry at slot 0 ---
        if withOS {
            let slot0 = bntBase + 0 * 32
            let osName = "EMAX2 Software"
            for (i, ch) in osName.utf8.prefix(14).enumerated() { image[slot0 + i] = ch }
            image[slot0 + 14] = 0x00; image[slot0 + 15] = 0x00
            image.writeU16LE(0x7800, at: slot0 + 16)  // bankIndex = OS marker
            image.writeU16LE(1,      at: slot0 + 18)  // startCluster = 1
            image.writeU16LE(0x0080, at: slot0 + 26)  // flags = OS

            // Put non-zero bytes in OS cluster (cluster 1, 0-based: caOffset + 1*clusterSize)
            let osDataOffset = caStartSector * 512 + 1 * clusterSize
            image[osDataOffset] = 0xAB
            image[osDataOffset + 1] = 0xCD
        }

        // --- User bank BNT entry at slot 1 ---
        if numBanks >= 1 {
            let slot1 = bntBase + 1 * 32
            let name = "TESTBANK      "
            for (i, ch) in name.utf8.prefix(14).enumerated() { image[slot1 + i] = ch }
            image[slot1 + 14] = 0x00; image[slot1 + 15] = 0x00
            image.writeU16LE(0x0000, at: slot1 + 16)  // bankIndex = first user bank
            image.writeU16LE(5,      at: slot1 + 18)  // startCluster = 5
            image.writeU16LE(0x0081, at: slot1 + 26)  // flags = active
        }

        return image
    }

    private func writeTempData(_ data: Data) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiskVerifierTests_\(UUID().uuidString)")
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
        self[offset + 1] = UInt8((value >>  8) & 0xFF)
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
