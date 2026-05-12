import XCTest
import Foundation
@testable import EmaxForge

/// Tests for PCMReallocator — error descriptions, result struct, and the
/// invalidPCMData guard that fires before any disk I/O.
///
/// All other code paths (replaceSamplePCM) require a real EMX2 disk image,
/// so they are integration-level tests handled elsewhere.
final class PCMReallocatorTests: XCTestCase {

    // MARK: - Helpers

    private func fakeEntry() -> BankCatalogEntry {
        BankCatalogEntry(
            catalogIndex: 0,
            name: "TESTBANK",
            bankIndex: 0,
            startCluster: 2,
            numPresets: 1,
            fieldA: 0,
            fieldB: 0,
            flags: 0x81,
            clusterChain: [2],
            sizeBytes: 489472
        )
    }

    private var fakeURL: URL { URL(fileURLWithPath: "/dev/null/fake.hda") }

    // MARK: - ReplacementError descriptions

    func testBankNotFoundDescriptionContainsName() {
        let err = PCMReallocator.ReplacementError.bankNotFound("PIANO")
        XCTAssertTrue(err.errorDescription?.contains("PIANO") == true)
    }

    func testSampleIndexOutOfRangeDescriptionContainsIndex() {
        let err = PCMReallocator.ReplacementError.sampleIndexOutOfRange(7)
        XCTAssertTrue(err.errorDescription?.contains("7") == true)
    }

    func testInvalidPCMDataDescriptionContainsReason() {
        let err = PCMReallocator.ReplacementError.invalidPCMData("too short")
        XCTAssertTrue(err.errorDescription?.contains("too short") == true)
    }

    func testNoFreeClusterSpaceDescriptionContainsNeededAndAvailable() {
        let err = PCMReallocator.ReplacementError.noFreeClusterSpace(needed: 5, available: 2)
        let desc = err.errorDescription ?? ""
        XCTAssertTrue(desc.contains("5"), "Description should mention needed count")
        XCTAssertTrue(desc.contains("2"), "Description should mention available count")
    }

    func testReadErrorDescriptionContainsMessage() {
        let err = PCMReallocator.ReplacementError.readError("header corrupt")
        XCTAssertTrue(err.errorDescription?.contains("header corrupt") == true)
    }

    func testWriteErrorDescriptionContainsMessage() {
        let err = PCMReallocator.ReplacementError.writeError("disk full")
        XCTAssertTrue(err.errorDescription?.contains("disk full") == true)
    }

    func testAllErrorDescriptionsNonEmpty() {
        let errors: [PCMReallocator.ReplacementError] = [
            .bankNotFound("X"),
            .sampleIndexOutOfRange(0),
            .invalidPCMData("bad"),
            .noFreeClusterSpace(needed: 1, available: 0),
            .readError("r"),
            .writeError("w")
        ]
        for err in errors {
            XCTAssertFalse(err.errorDescription?.isEmpty ?? true,
                           "Error \(err) has empty description")
        }
    }

    // MARK: - ReplacementResult struct

    func testReplacementResultFieldAccess() {
        let r = PCMReallocator.ReplacementResult(
            sampleIndex: 3,
            oldSizeBytes: 1000,
            newSizeBytes: 2000,
            clustersAdded: 1,
            clustersFreed: 0
        )
        XCTAssertEqual(r.sampleIndex, 3)
        XCTAssertEqual(r.oldSizeBytes, 1000)
        XCTAssertEqual(r.newSizeBytes, 2000)
        XCTAssertEqual(r.clustersAdded, 1)
        XCTAssertEqual(r.clustersFreed, 0)
    }

    func testReplacementResultSameSizeCase() {
        let r = PCMReallocator.ReplacementResult(
            sampleIndex: 0,
            oldSizeBytes: 500,
            newSizeBytes: 500,
            clustersAdded: 0,
            clustersFreed: 0
        )
        XCTAssertEqual(r.oldSizeBytes, r.newSizeBytes)
        XCTAssertEqual(r.clustersAdded, 0)
        XCTAssertEqual(r.clustersFreed, 0)
    }

    func testReplacementResultFreedClustersCase() {
        let r = PCMReallocator.ReplacementResult(
            sampleIndex: 1,
            oldSizeBytes: 4000,
            newSizeBytes: 100,
            clustersAdded: 0,
            clustersFreed: 3
        )
        XCTAssertLessThan(r.newSizeBytes, r.oldSizeBytes)
        XCTAssertEqual(r.clustersFreed, 3)
        XCTAssertEqual(r.clustersAdded, 0)
    }

    // MARK: - invalidPCMData guard (fires before FileHandle open)

    func testReplaceSampleThrowsOnEmptyPCMData() {
        // count == 0 < 2 → invalidPCMData guard fires before disk is opened
        XCTAssertThrowsError(
            try PCMReallocator.replaceSamplePCM(
                bankEntry: fakeEntry(),
                sampleIndex: 0,
                newPCM: Data(),
                imageURL: fakeURL
            )
        ) { err in
            if case .invalidPCMData(_) = err as! PCMReallocator.ReplacementError { } else {
                XCTFail("Expected invalidPCMData for empty PCM, got \(err)")
            }
        }
    }

    func testReplaceSampleThrowsOnOneBytePCMData() {
        // count == 1 < 2 → same guard
        XCTAssertThrowsError(
            try PCMReallocator.replaceSamplePCM(
                bankEntry: fakeEntry(),
                sampleIndex: 0,
                newPCM: Data([0x00]),
                imageURL: fakeURL
            )
        ) { err in
            if case .invalidPCMData(_) = err as! PCMReallocator.ReplacementError { } else {
                XCTFail("Expected invalidPCMData for 1-byte PCM, got \(err)")
            }
        }
    }

    func testReplaceSampleTwoBytesPassesPCMGuard() {
        // count == 2 → passes the PCM guard → then fails on file open (writeError or readError)
        XCTAssertThrowsError(
            try PCMReallocator.replaceSamplePCM(
                bankEntry: fakeEntry(),
                sampleIndex: 0,
                newPCM: Data([0x00, 0x01]),
                imageURL: fakeURL
            )
        ) { err in
            let e = err as! PCMReallocator.ReplacementError
            if case .invalidPCMData(_) = e {
                XCTFail("2-byte PCM should pass the invalidPCMData guard")
            }
        }
    }
}
