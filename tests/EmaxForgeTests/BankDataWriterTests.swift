import XCTest
import Foundation
@testable import EmaxForge

/// Tests for BankDataWriter — BankDataError descriptions and DiskGeometry
/// computed properties (all pure: struct construction, no disk I/O needed).
final class BankDataWriterTests: XCTestCase {

    // MARK: - BankDataError descriptions

    func testNotEmaxImageDescription() {
        let err = BankDataWriter.BankDataError.notEmaxImage
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
        XCTAssertTrue(err.errorDescription?.contains("EMX2") == true)
    }

    func testImageTooSmallDescription() {
        let err = BankDataWriter.BankDataError.imageTooSmall
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testCannotOpenImageDescriptionContainsPath() {
        let err = BankDataWriter.BankDataError.cannotOpenImage("/tmp/test.hda")
        XCTAssertTrue(err.errorDescription?.contains("/tmp/test.hda") == true)
    }

    func testDataTooLargeDescriptionContainsNeededAndAvailable() {
        let err = BankDataWriter.BankDataError.dataTooLarge(needed: 5_000_000, available: 2_000_000)
        let desc = err.errorDescription ?? ""
        XCTAssertTrue(desc.contains("5000000"), "Description should mention needed bytes")
        XCTAssertTrue(desc.contains("2000000"), "Description should mention available bytes")
    }

    func testInvalidClusterChainDescription() {
        let err = BankDataWriter.BankDataError.invalidClusterChain
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testWriteErrorDescriptionContainsMessage() {
        let err = BankDataWriter.BankDataError.writeError("disk full")
        XCTAssertTrue(err.errorDescription?.contains("disk full") == true)
    }

    func testAllErrorDescriptionsNonEmpty() {
        let errors: [BankDataWriter.BankDataError] = [
            .notEmaxImage, .imageTooSmall, .cannotOpenImage("x"),
            .dataTooLarge(needed: 1, available: 0),
            .invalidClusterChain, .writeError("e")
        ]
        for err in errors {
            XCTAssertFalse(err.errorDescription?.isEmpty ?? true,
                           "Error \(err) has empty description")
        }
    }

    // MARK: - DiskGeometry: constant properties

    func testFATOffsetIsAlways0x400() {
        let geo = BankDataWriter.DiskGeometry(
            clusterSize: 489472, fatSectors: 4,
            bntStartSector: 8, maxBanks: 90,
            clusterAreaStartSector: 98, totalClusters: 955
        )
        XCTAssertEqual(geo.fatOffset, 0x400)
    }

    // MARK: - DiskGeometry: fatSize

    func testFATSizeIsFatSectorsTimes512() {
        let geo = BankDataWriter.DiskGeometry(
            clusterSize: 489472, fatSectors: 4,
            bntStartSector: 8, maxBanks: 90,
            clusterAreaStartSector: 98, totalClusters: 955
        )
        XCTAssertEqual(geo.fatSize, 4 * 512)  // 2048
    }

    func testFATSizeFor6Sectors() {
        let geo = BankDataWriter.DiskGeometry(
            clusterSize: 196352, fatSectors: 6,
            bntStartSector: 9, maxBanks: 111,
            clusterAreaStartSector: 120, totalClusters: 1533
        )
        XCTAssertEqual(geo.fatSize, 6 * 512)  // 3072
    }

    // MARK: - DiskGeometry: fatEntryCount

    func testFATEntryCountIsFatSizeOver2() {
        let geo = BankDataWriter.DiskGeometry(
            clusterSize: 489472, fatSectors: 4,
            bntStartSector: 8, maxBanks: 90,
            clusterAreaStartSector: 98, totalClusters: 955
        )
        XCTAssertEqual(geo.fatEntryCount, (4 * 512) / 2)  // 1024
    }

    // MARK: - DiskGeometry: bntOffset

    func testBNTOffsetIsBntStartSectorTimes512() {
        let geo = BankDataWriter.DiskGeometry(
            clusterSize: 489472, fatSectors: 4,
            bntStartSector: 8, maxBanks: 90,
            clusterAreaStartSector: 98, totalClusters: 955
        )
        XCTAssertEqual(geo.bntOffset, UInt64(8 * 512))  // 4096
    }

    func testBNTOffsetFor96MBDisk() {
        // 96 MB: bntStartSector=9
        let geo = BankDataWriter.DiskGeometry(
            clusterSize: 196352, fatSectors: 6,
            bntStartSector: 9, maxBanks: 111,
            clusterAreaStartSector: 120, totalClusters: 1533
        )
        XCTAssertEqual(geo.bntOffset, UInt64(9 * 512))  // 4608
    }

    // MARK: - DiskGeometry: clusterAreaOffset

    func testClusterAreaOffsetIsClusterAreaStartSectorTimes512() {
        let geo = BankDataWriter.DiskGeometry(
            clusterSize: 489472, fatSectors: 4,
            bntStartSector: 8, maxBanks: 90,
            clusterAreaStartSector: 98, totalClusters: 955
        )
        XCTAssertEqual(geo.clusterAreaOffset, UInt64(98 * 512))  // 50176
    }

    // MARK: - DiskGeometry: clusterOffset

    func testClusterOffset0IsClusterAreaOffset() {
        let geo = BankDataWriter.DiskGeometry(
            clusterSize: 489472, fatSectors: 4,
            bntStartSector: 8, maxBanks: 90,
            clusterAreaStartSector: 98, totalClusters: 955
        )
        XCTAssertEqual(geo.clusterOffset(0), geo.clusterAreaOffset)
    }

    func testClusterOffset1IsClusterAreaOffsetPlusOneClusterSize() {
        let geo = BankDataWriter.DiskGeometry(
            clusterSize: 489472, fatSectors: 4,
            bntStartSector: 8, maxBanks: 90,
            clusterAreaStartSector: 98, totalClusters: 955
        )
        XCTAssertEqual(geo.clusterOffset(1), geo.clusterAreaOffset + UInt64(489472))
    }

    func testClusterOffset10() {
        let geo = BankDataWriter.DiskGeometry(
            clusterSize: 489472, fatSectors: 4,
            bntStartSector: 8, maxBanks: 90,
            clusterAreaStartSector: 98, totalClusters: 955
        )
        XCTAssertEqual(geo.clusterOffset(10),
                       geo.clusterAreaOffset + UInt64(10 * 489472))
    }

    func testClusterOffsetFor96MBDisk() {
        // 96 MB: clusterSize=196352, caStartSector=120
        let geo = BankDataWriter.DiskGeometry(
            clusterSize: 196352, fatSectors: 6,
            bntStartSector: 9, maxBanks: 111,
            clusterAreaStartSector: 120, totalClusters: 1533
        )
        let caOffset = UInt64(120 * 512)
        XCTAssertEqual(geo.clusterOffset(0), caOffset)
        XCTAssertEqual(geo.clusterOffset(1), caOffset + UInt64(196352))
        XCTAssertEqual(geo.clusterOffset(2), caOffset + UInt64(2 * 196352))
    }

    func testClusterOffsetIncreasesMonotonically() {
        let geo = BankDataWriter.DiskGeometry(
            clusterSize: 489472, fatSectors: 4,
            bntStartSector: 8, maxBanks: 90,
            clusterAreaStartSector: 98, totalClusters: 955
        )
        for i in 0..<10 {
            XCTAssertLessThan(geo.clusterOffset(i), geo.clusterOffset(i + 1),
                              "cluster \(i) offset must be less than cluster \(i+1) offset")
        }
    }
}
