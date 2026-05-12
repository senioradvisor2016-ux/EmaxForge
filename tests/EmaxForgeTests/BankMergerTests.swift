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

    // MARK: - Loop address offset regression tests
    //
    // These verify the canonical offsets from EmaxIIFormat used by BankMerger
    // when rebasing loop-point addresses after a merge.  Keeping them in sync
    // prevents a recurrence of the bug where only startAddr/endAddr were
    // adjusted while sustainLoop*/releaseLoop* were left pointing at the
    // source bank's PCM area.

    /// Sustain loop start is at param +0x0C (decimal 12).
    func testEmaxIIFormatSustainLoopStartOffset() {
        XCTAssertEqual(EmaxIIFormat.paramSustainLoopStart, 0x0C)
    }

    /// Sustain loop end is at param +0x10 (decimal 16).
    func testEmaxIIFormatSustainLoopEndOffset() {
        XCTAssertEqual(EmaxIIFormat.paramSustainLoopEnd, 0x10)
    }

    /// Release loop start is at param +0x14 (decimal 20).
    func testEmaxIIFormatReleaseLoopStartOffset() {
        XCTAssertEqual(EmaxIIFormat.paramReleaseLoopStart, 0x14)
    }

    /// Release loop end is at param +0x18 (decimal 24).
    func testEmaxIIFormatReleaseLoopEndOffset() {
        XCTAssertEqual(EmaxIIFormat.paramReleaseLoopEnd, 0x18)
    }

    /// Simulate the BankMerger loop-address rebase logic on a synthetic 64-byte
    /// param block and confirm all four loop fields are offset correctly.
    func testLoopAddressRebaseLogicAdjustsAllFourFields() {
        // Build a 64-byte param block with known values at each loop field.
        var block = Data(count: 64)

        // startAddr (+0x00) = 0x1000, endAddr (+0x04) = 0x2000
        writeU32LE(0x1000, into: &block, at: 0x00)
        writeU32LE(0x2000, into: &block, at: 0x04)

        // Loop addresses — each set to a small positive value.
        let origSustainStart:  UInt32 = 0x1200
        let origSustainEnd:    UInt32 = 0x1800
        let origReleaseStart:  UInt32 = 0x1A00
        let origReleaseEnd:    UInt32 = 0x1F00
        writeU32LE(origSustainStart,  into: &block, at: 0x0C)
        writeU32LE(origSustainEnd,    into: &block, at: 0x10)
        writeU32LE(origReleaseStart,  into: &block, at: 0x14)
        writeU32LE(origReleaseEnd,    into: &block, at: 0x18)

        // Append offset — the amount by which PCM data is shifted in the merged bank.
        let appendOffset: UInt32 = 0x40000

        // Apply the exact conditional rebase logic from BankMerger.merge().
        for off in [0x0C, 0x10, 0x14, 0x18] {
            let raw = readU32LE(block, at: off)
            if raw > 0 {
                writeU32LE(raw &+ appendOffset, into: &block, at: off)
            }
        }

        XCTAssertEqual(readU32LE(block, at: 0x0C), origSustainStart  + appendOffset)
        XCTAssertEqual(readU32LE(block, at: 0x10), origSustainEnd    + appendOffset)
        XCTAssertEqual(readU32LE(block, at: 0x14), origReleaseStart  + appendOffset)
        XCTAssertEqual(readU32LE(block, at: 0x18), origReleaseEnd    + appendOffset)
    }

    /// Zero-valued loop addresses (disabled) must NOT be adjusted.
    func testLoopAddressRebaseSkipsZeroValues() {
        var block = Data(count: 64)
        // All loop fields stay at 0 (disabled — no loop).
        let appendOffset: UInt32 = 0x40000

        for off in [0x0C, 0x10, 0x14, 0x18] {
            let raw = readU32LE(block, at: off)
            if raw > 0 {
                writeU32LE(raw &+ appendOffset, into: &block, at: off)
            }
        }

        // Should remain 0.
        for off in [0x0C, 0x10, 0x14, 0x18] {
            XCTAssertEqual(readU32LE(block, at: off), 0,
                           "Zero loop field at +0x\(String(off, radix: 16)) must not be modified")
        }
    }

    /// Only the loop fields change — startAddr / endAddr are unaffected by the loop loop.
    func testLoopAddressRebaseDoesNotTouchStartEndAddr() {
        var block = Data(count: 64)
        writeU32LE(0x5000, into: &block, at: 0x00)
        writeU32LE(0x6000, into: &block, at: 0x04)
        writeU32LE(0x5200, into: &block, at: 0x0C)

        let appendOffset: UInt32 = 0x40000
        for off in [0x0C, 0x10, 0x14, 0x18] {
            let raw = readU32LE(block, at: off)
            if raw > 0 {
                writeU32LE(raw &+ appendOffset, into: &block, at: off)
            }
        }

        // Start/end untouched.
        XCTAssertEqual(readU32LE(block, at: 0x00), 0x5000)
        XCTAssertEqual(readU32LE(block, at: 0x04), 0x6000)
        // Sustain start adjusted.
        XCTAssertEqual(readU32LE(block, at: 0x0C), 0x5200 + appendOffset)
    }

    // MARK: - Private Data helpers (mirrors bm_readU32LE / bm_writeU32LE)

    private func readU32LE(_ data: Data, at offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return data.withUnsafeBytes {
            $0.baseAddress!.advanced(by: offset).loadUnaligned(as: UInt32.self)
        }
    }

    private func writeU32LE(_ value: UInt32, into data: inout Data, at offset: Int) {
        guard offset + 4 <= data.count else { return }
        data[offset]     = UInt8(value & 0xFF)
        data[offset + 1] = UInt8((value >> 8)  & 0xFF)
        data[offset + 2] = UInt8((value >> 16) & 0xFF)
        data[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
}
