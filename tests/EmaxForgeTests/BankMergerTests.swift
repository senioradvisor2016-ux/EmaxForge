import XCTest
import Foundation
@testable import EmaxForge

/// Tests for BankMerger — error types, MergeOptions defaults, MergeResult struct.
///
/// The full merge() pipeline requires real disk images with cluster chains;
/// those are integration-level tests. These unit tests cover the public type
/// surface that is testable without any disk I/O.
final class BankMergerTests: XCTestCase {

    // MARK: - MergeError descriptions

    func testTargetBankFullDescriptionContainsMaxPresets() {
        let err = BankMerger.MergeError.targetBankFull(maxPresets: 256)
        XCTAssertTrue(err.errorDescription?.contains("256") == true)
    }

    func testInsufficientDiskSpaceDescriptionContainsNeededAndAvailable() {
        let err = BankMerger.MergeError.insufficientDiskSpace(needed: 5, available: 2)
        let desc = err.errorDescription ?? ""
        XCTAssertTrue(desc.contains("5"), "Description should mention needed clusters")
        XCTAssertTrue(desc.contains("2"), "Description should mention available clusters")
    }

    func testSourceReadErrorDescriptionContainsMessage() {
        let err = BankMerger.MergeError.sourceReadError("corrupt chain")
        XCTAssertTrue(err.errorDescription?.contains("corrupt chain") == true)
    }

    func testTargetWriteErrorDescriptionContainsMessage() {
        let err = BankMerger.MergeError.targetWriteError("disk full")
        XCTAssertTrue(err.errorDescription?.contains("disk full") == true)
    }

    func testAllErrorDescriptionsNonEmpty() {
        let errors: [BankMerger.MergeError] = [
            .targetBankFull(maxPresets: 256),
            .insufficientDiskSpace(needed: 1, available: 0),
            .sourceReadError("e"),
            .targetWriteError("e")
        ]
        for err in errors {
            XCTAssertFalse(err.errorDescription?.isEmpty ?? true,
                           "Error \(err) has empty description")
        }
    }

    // MARK: - MergeOptions defaults

    func testMergeOptionsDefaultSkipDuplicatePresetNamesIsTrue() {
        let opts = BankMerger.MergeOptions()
        XCTAssertTrue(opts.skipDuplicatePresetNames)
    }

    func testMergeOptionsDefaultSkipDuplicateSampleNamesIsFalse() {
        let opts = BankMerger.MergeOptions()
        XCTAssertFalse(opts.skipDuplicateSampleNames)
    }

    func testMergeOptionsDefaultMaxPresetsIs256() {
        let opts = BankMerger.MergeOptions()
        XCTAssertEqual(opts.maxPresetsInTarget, 256)
    }

    func testMergeOptionsCanBeCustomized() {
        let opts = BankMerger.MergeOptions(
            skipDuplicatePresetNames: false,
            skipDuplicateSampleNames: true,
            maxPresetsInTarget: 64
        )
        XCTAssertFalse(opts.skipDuplicatePresetNames)
        XCTAssertTrue(opts.skipDuplicateSampleNames)
        XCTAssertEqual(opts.maxPresetsInTarget, 64)
    }

    // MARK: - MergeResult struct

    func testMergeResultAllAddedFields() {
        let r = BankMerger.MergeResult(
            presetsAdded: 5,
            presetNamesSkipped: ["OLD_BASS"],
            samplesAdded: 12,
            sampleNamesSkipped: [],
            clustersUsed: 3
        )
        XCTAssertEqual(r.presetsAdded, 5)
        XCTAssertEqual(r.presetNamesSkipped, ["OLD_BASS"])
        XCTAssertEqual(r.samplesAdded, 12)
        XCTAssertTrue(r.sampleNamesSkipped.isEmpty)
        XCTAssertEqual(r.clustersUsed, 3)
    }

    func testMergeResultZeroAdded() {
        let r = BankMerger.MergeResult(
            presetsAdded: 0,
            presetNamesSkipped: ["P1", "P2"],
            samplesAdded: 0,
            sampleNamesSkipped: ["S1"],
            clustersUsed: 0
        )
        XCTAssertEqual(r.presetsAdded, 0)
        XCTAssertEqual(r.presetNamesSkipped.count, 2)
        XCTAssertEqual(r.samplesAdded, 0)
        XCTAssertEqual(r.sampleNamesSkipped.count, 1)
        XCTAssertEqual(r.clustersUsed, 0)
    }

    func testMergeResultNothingSkipped() {
        let r = BankMerger.MergeResult(
            presetsAdded: 8,
            presetNamesSkipped: [],
            samplesAdded: 20,
            sampleNamesSkipped: [],
            clustersUsed: 2
        )
        XCTAssertTrue(r.presetNamesSkipped.isEmpty)
        XCTAssertTrue(r.sampleNamesSkipped.isEmpty)
        XCTAssertEqual(r.presetsAdded + r.samplesAdded, 28)
    }
}
