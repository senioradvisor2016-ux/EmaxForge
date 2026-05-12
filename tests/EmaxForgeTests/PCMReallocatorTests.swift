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

    // MARK: - Loop address adjustment logic regression tests
    //
    // PCMReallocator.replaceSamplePCM (CASE 2: resize) adjusts start/end of every
    // subsequent sample by delta.  The bug: loop addresses (+0x0C,+0x10,+0x14,+0x18)
    // were not adjusted, leaving them pointing at the wrong PCM offsets after a resize.

    /// Simulate the CASE 2 loop-rebasing logic on a synthetic param block.
    func testPCMReallocatorLoopAddressRebaseAdjustsAllFourFields() {
        // Build a minimal bank data slice: just one param block for sample j=1
        // placed at EmaxIIFormat.sampleParamOffset + 1 × sampleParamSize
        let blockOffset = EmaxIIFormat.sampleParamOffset + EmaxIIFormat.sampleParamSize
        let dataSize = blockOffset + EmaxIIFormat.sampleParamSize
        var bankData = Data(count: dataSize)

        // Fill sample j=1's param block
        // jStart > oldStartRel (which is 0) — so adjustment will apply
        let jStart: UInt32   = 0x1000
        let jEnd: UInt32     = 0x2000
        let loopSS: UInt32   = 0x1200  // sustainLoopStart
        let loopSE: UInt32   = 0x1800  // sustainLoopEnd
        let loopRS: UInt32   = 0x1A00  // releaseLoopStart
        let loopRE: UInt32   = 0x1F00  // releaseLoopEnd

        writeU32LE(jStart, into: &bankData, at: blockOffset + EmaxIIFormat.paramStartAddr)
        writeU32LE(jEnd,   into: &bankData, at: blockOffset + EmaxIIFormat.paramEndAddr)
        writeU32LE(loopSS, into: &bankData, at: blockOffset + EmaxIIFormat.paramSustainLoopStart)
        writeU32LE(loopSE, into: &bankData, at: blockOffset + EmaxIIFormat.paramSustainLoopEnd)
        writeU32LE(loopRS, into: &bankData, at: blockOffset + EmaxIIFormat.paramReleaseLoopStart)
        writeU32LE(loopRE, into: &bankData, at: blockOffset + EmaxIIFormat.paramReleaseLoopEnd)

        // Apply the exact adjustment logic from PCMReallocator (CASE 2 inner loop)
        let oldStartRel = 0  // sample being replaced is at offset 0
        let delta = 0x800    // new PCM is 0x800 bytes larger

        for j in 1..<2 {
            let jBase = EmaxIIFormat.sampleParamOffset + j * EmaxIIFormat.sampleParamSize
            let jS = Int(readU32LE(bankData, at: jBase + EmaxIIFormat.paramStartAddr))
            let jE = Int(readU32LE(bankData, at: jBase + EmaxIIFormat.paramEndAddr))
            guard jS > 0 || jE > 0 else { continue }
            if jS > oldStartRel {
                writeU32LE(UInt32(jS + delta), into: &bankData, at: jBase + EmaxIIFormat.paramStartAddr)
                writeU32LE(UInt32(jE + delta), into: &bankData, at: jBase + EmaxIIFormat.paramEndAddr)
                for loopOff in [EmaxIIFormat.paramSustainLoopStart,
                                EmaxIIFormat.paramSustainLoopEnd,
                                EmaxIIFormat.paramReleaseLoopStart,
                                EmaxIIFormat.paramReleaseLoopEnd] {
                    guard jBase + loopOff + 4 <= bankData.count else { continue }
                    let raw = Int(readU32LE(bankData, at: jBase + loopOff))
                    if raw > 0 {
                        writeU32LE(UInt32(max(0, raw + delta)), into: &bankData, at: jBase + loopOff)
                    }
                }
            }
        }

        XCTAssertEqual(readU32LE(bankData, at: blockOffset + EmaxIIFormat.paramStartAddr),        jStart + UInt32(delta))
        XCTAssertEqual(readU32LE(bankData, at: blockOffset + EmaxIIFormat.paramEndAddr),          jEnd   + UInt32(delta))
        XCTAssertEqual(readU32LE(bankData, at: blockOffset + EmaxIIFormat.paramSustainLoopStart), loopSS + UInt32(delta))
        XCTAssertEqual(readU32LE(bankData, at: blockOffset + EmaxIIFormat.paramSustainLoopEnd),   loopSE + UInt32(delta))
        XCTAssertEqual(readU32LE(bankData, at: blockOffset + EmaxIIFormat.paramReleaseLoopStart), loopRS + UInt32(delta))
        XCTAssertEqual(readU32LE(bankData, at: blockOffset + EmaxIIFormat.paramReleaseLoopEnd),   loopRE + UInt32(delta))
    }

    /// Zero-valued loop addresses (disabled) must not be shifted.
    func testPCMReallocatorLoopAddressRebaseSkipsZeroFields() {
        let blockOffset = EmaxIIFormat.sampleParamOffset + EmaxIIFormat.sampleParamSize
        let dataSize = blockOffset + EmaxIIFormat.sampleParamSize
        var bankData = Data(count: dataSize)

        writeU32LE(0x2000, into: &bankData, at: blockOffset + EmaxIIFormat.paramStartAddr)
        writeU32LE(0x3000, into: &bankData, at: blockOffset + EmaxIIFormat.paramEndAddr)
        // All loop fields stay 0 (no loop)

        let delta = 0x1000
        let jBase = blockOffset
        let jS = Int(readU32LE(bankData, at: jBase + EmaxIIFormat.paramStartAddr))
        writeU32LE(UInt32(jS + delta), into: &bankData, at: jBase + EmaxIIFormat.paramStartAddr)
        for loopOff in [EmaxIIFormat.paramSustainLoopStart,
                        EmaxIIFormat.paramSustainLoopEnd,
                        EmaxIIFormat.paramReleaseLoopStart,
                        EmaxIIFormat.paramReleaseLoopEnd] {
            guard jBase + loopOff + 4 <= bankData.count else { continue }
            let raw = Int(readU32LE(bankData, at: jBase + loopOff))
            if raw > 0 {
                writeU32LE(UInt32(max(0, raw + delta)), into: &bankData, at: jBase + loopOff)
            }
        }

        // All four loop fields must remain 0
        for loopOff in [EmaxIIFormat.paramSustainLoopStart,
                        EmaxIIFormat.paramSustainLoopEnd,
                        EmaxIIFormat.paramReleaseLoopStart,
                        EmaxIIFormat.paramReleaseLoopEnd] {
            XCTAssertEqual(readU32LE(bankData, at: jBase + loopOff), 0,
                           "Zero loop field at offset \(loopOff) must not be modified")
        }
    }

    // MARK: - Private Data helpers

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
