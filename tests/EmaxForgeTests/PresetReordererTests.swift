import XCTest
import Foundation
@testable import EmaxForge

/// Tests for PresetReorderer — preset swap/move error guards and error descriptions.
///
/// Error guards in swapPresets/movePreset fire before any disk I/O (before
/// loadGeometry is called), so fake URLs are safe for those tests.
/// ReorderError descriptions are pure value tests.
final class PresetReordererTests: XCTestCase {

    // MARK: - Helpers

    /// Minimal BankCatalogEntry — fields not used by the guards under test.
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

    /// Fake image URL — never opened; only passed after error guards fire.
    private var fakeURL: URL { URL(fileURLWithPath: "/dev/null/fake.hda") }

    // MARK: - ReorderError descriptions

    func testIndexOutOfRangeDescriptionContainsIndex() {
        let err = PresetReorderer.ReorderError.indexOutOfRange(42)
        XCTAssertTrue(err.errorDescription?.contains("42") == true)
    }

    func testIndexOutOfRangeDescriptionContainsRange() {
        let err = PresetReorderer.ReorderError.indexOutOfRange(0)
        // Should mention the valid range (0–255)
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testSameIndexDescriptionNonEmpty() {
        let err = PresetReorderer.ReorderError.sameIndex
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testBankReadErrorDescriptionContainsMessage() {
        let err = PresetReorderer.ReorderError.bankReadError("disk missing")
        XCTAssertTrue(err.errorDescription?.contains("disk missing") == true)
    }

    func testBankWriteErrorDescriptionContainsMessage() {
        let err = PresetReorderer.ReorderError.bankWriteError("no space")
        XCTAssertTrue(err.errorDescription?.contains("no space") == true)
    }

    // MARK: - ReorderResult struct

    func testReorderResultStoresSwappedPairs() {
        let r = PresetReorderer.ReorderResult(swappedPresets: [(1, 3), (2, 5)])
        XCTAssertEqual(r.swappedPresets.count, 2)
        XCTAssertEqual(r.swappedPresets[0].0, 1)
        XCTAssertEqual(r.swappedPresets[0].1, 3)
        XCTAssertEqual(r.swappedPresets[1].0, 2)
        XCTAssertEqual(r.swappedPresets[1].1, 5)
    }

    func testReorderResultEmptySwapsList() {
        let r = PresetReorderer.ReorderResult(swappedPresets: [])
        XCTAssertTrue(r.swappedPresets.isEmpty)
    }

    // MARK: - swapPresets: indexA out of range

    func testSwapPresetsThrowsWhenIndexAIsNegative() {
        XCTAssertThrowsError(
            try PresetReorderer.swapPresets(indexA: -1, indexB: 0, in: fakeEntry(), imageURL: fakeURL)
        ) { err in
            if case .indexOutOfRange(let i) = err as! PresetReorderer.ReorderError {
                XCTAssertEqual(i, -1)
            } else {
                XCTFail("Expected indexOutOfRange(-1), got \(err)")
            }
        }
    }

    func testSwapPresetsThrowsWhenIndexAIs256() {
        XCTAssertThrowsError(
            try PresetReorderer.swapPresets(indexA: 256, indexB: 0, in: fakeEntry(), imageURL: fakeURL)
        ) { err in
            if case .indexOutOfRange(let i) = err as! PresetReorderer.ReorderError {
                XCTAssertEqual(i, 256)
            } else {
                XCTFail("Expected indexOutOfRange(256)")
            }
        }
    }

    func testSwapPresetsThrowsWhenIndexAIs300() {
        XCTAssertThrowsError(
            try PresetReorderer.swapPresets(indexA: 300, indexB: 0, in: fakeEntry(), imageURL: fakeURL)
        ) { _ in }
    }

    // MARK: - swapPresets: indexB out of range

    func testSwapPresetsThrowsWhenIndexBIsNegative() {
        XCTAssertThrowsError(
            try PresetReorderer.swapPresets(indexA: 0, indexB: -1, in: fakeEntry(), imageURL: fakeURL)
        ) { err in
            if case .indexOutOfRange(let i) = err as! PresetReorderer.ReorderError {
                XCTAssertEqual(i, -1)
            } else {
                XCTFail("Expected indexOutOfRange(-1)")
            }
        }
    }

    func testSwapPresetsThrowsWhenIndexBIs256() {
        XCTAssertThrowsError(
            try PresetReorderer.swapPresets(indexA: 0, indexB: 256, in: fakeEntry(), imageURL: fakeURL)
        ) { err in
            if case .indexOutOfRange(let i) = err as! PresetReorderer.ReorderError {
                XCTAssertEqual(i, 256)
            } else {
                XCTFail("Expected indexOutOfRange(256)")
            }
        }
    }

    // MARK: - swapPresets: valid boundary indices pass guard

    func testSwapPresetsIndex0And255PassGuard() {
        // Both indices in range, different → passes both range guards → will throw
        // bankReadError (disk I/O fails) but NOT indexOutOfRange or sameIndex.
        XCTAssertThrowsError(
            try PresetReorderer.swapPresets(indexA: 0, indexB: 255, in: fakeEntry(), imageURL: fakeURL)
        ) { err in
            let e = err as! PresetReorderer.ReorderError
            if case .indexOutOfRange(_) = e {
                XCTFail("0 and 255 are valid indices")
            }
            if case .sameIndex = e {
                XCTFail("0 and 255 are different indices")
            }
        }
    }

    // MARK: - swapPresets: sameIndex

    func testSwapPresetsThrowsSameIndexWhenEqualIndices() {
        XCTAssertThrowsError(
            try PresetReorderer.swapPresets(indexA: 3, indexB: 3, in: fakeEntry(), imageURL: fakeURL)
        ) { err in
            if case .sameIndex = err as! PresetReorderer.ReorderError { } else {
                XCTFail("Expected sameIndex")
            }
        }
    }

    func testSwapPresetsThrowsSameIndexForZero() {
        XCTAssertThrowsError(
            try PresetReorderer.swapPresets(indexA: 0, indexB: 0, in: fakeEntry(), imageURL: fakeURL)
        ) { err in
            if case .sameIndex = err as! PresetReorderer.ReorderError { } else {
                XCTFail("Expected sameIndex for (0, 0)")
            }
        }
    }

    func testSwapPresetsThrowsSameIndexForMax() {
        XCTAssertThrowsError(
            try PresetReorderer.swapPresets(indexA: 255, indexB: 255, in: fakeEntry(), imageURL: fakeURL)
        ) { err in
            if case .sameIndex = err as! PresetReorderer.ReorderError { } else {
                XCTFail("Expected sameIndex for (255, 255)")
            }
        }
    }

    // MARK: - movePreset: source out of range

    func testMovePresetThrowsWhenSourceIsNegative() {
        XCTAssertThrowsError(
            try PresetReorderer.movePreset(from: -1, to: 5, in: fakeEntry(), imageURL: fakeURL)
        ) { err in
            if case .indexOutOfRange(let i) = err as! PresetReorderer.ReorderError {
                XCTAssertEqual(i, -1)
            } else {
                XCTFail("Expected indexOutOfRange(-1)")
            }
        }
    }

    func testMovePresetThrowsWhenSourceIs256() {
        XCTAssertThrowsError(
            try PresetReorderer.movePreset(from: 256, to: 5, in: fakeEntry(), imageURL: fakeURL)
        ) { err in
            if case .indexOutOfRange(let i) = err as! PresetReorderer.ReorderError {
                XCTAssertEqual(i, 256)
            } else {
                XCTFail("Expected indexOutOfRange(256)")
            }
        }
    }

    // MARK: - movePreset: destination out of range

    func testMovePresetThrowsWhenDestinationIsNegative() {
        XCTAssertThrowsError(
            try PresetReorderer.movePreset(from: 0, to: -1, in: fakeEntry(), imageURL: fakeURL)
        ) { err in
            if case .indexOutOfRange(let i) = err as! PresetReorderer.ReorderError {
                XCTAssertEqual(i, -1)
            } else {
                XCTFail("Expected indexOutOfRange(-1)")
            }
        }
    }

    func testMovePresetThrowsWhenDestinationIs256() {
        XCTAssertThrowsError(
            try PresetReorderer.movePreset(from: 0, to: 256, in: fakeEntry(), imageURL: fakeURL)
        ) { err in
            if case .indexOutOfRange(let i) = err as! PresetReorderer.ReorderError {
                XCTAssertEqual(i, 256)
            } else {
                XCTFail("Expected indexOutOfRange(256)")
            }
        }
    }

    // MARK: - movePreset: sameIndex

    func testMovePresetThrowsSameIndexWhenEqual() {
        XCTAssertThrowsError(
            try PresetReorderer.movePreset(from: 5, to: 5, in: fakeEntry(), imageURL: fakeURL)
        ) { err in
            if case .sameIndex = err as! PresetReorderer.ReorderError { } else {
                XCTFail("Expected sameIndex")
            }
        }
    }

    func testMovePresetThrowsSameIndexForZero() {
        XCTAssertThrowsError(
            try PresetReorderer.movePreset(from: 0, to: 0, in: fakeEntry(), imageURL: fakeURL)
        ) { err in
            if case .sameIndex = err as! PresetReorderer.ReorderError { } else {
                XCTFail("Expected sameIndex")
            }
        }
    }

    // MARK: - movePreset: valid boundary indices pass guards

    func testMovePresetIndex0To255PassesGuards() {
        // Both in range, different → passes all range/same guards → bankReadError from disk I/O.
        XCTAssertThrowsError(
            try PresetReorderer.movePreset(from: 0, to: 255, in: fakeEntry(), imageURL: fakeURL)
        ) { err in
            let e = err as! PresetReorderer.ReorderError
            if case .indexOutOfRange(_) = e { XCTFail("0 is a valid source index") }
            if case .sameIndex = e        { XCTFail("0 and 255 are different") }
        }
    }

    func testMovePresetIndex255To0PassesGuards() {
        XCTAssertThrowsError(
            try PresetReorderer.movePreset(from: 255, to: 0, in: fakeEntry(), imageURL: fakeURL)
        ) { err in
            let e = err as! PresetReorderer.ReorderError
            if case .indexOutOfRange(_) = e { XCTFail("255 is a valid source index") }
            if case .sameIndex = e        { XCTFail("255 and 0 are different") }
        }
    }
}
