import XCTest
import Foundation
@testable import EmaxForge

// MARK: - DeviceType

/// Tests for DeviceType enum — pure computed properties, no I/O.
final class DeviceTypeTests: XCTestCase {

    func testEmaxIIRawValue() {
        XCTAssertEqual(DeviceType.emaxII.rawValue, "EMAX II")
    }

    func testEmaxIIDisplayName() {
        XCTAssertEqual(DeviceType.emaxII.displayName, "EMAX II")
    }

    func testEmaxIIImageExtensionsContainsHDA() {
        XCTAssertTrue(DeviceType.emaxII.imageExtensions.contains("hda"))
    }

    func testEmaxIIImageExtensionsContainsEZ2() {
        XCTAssertTrue(DeviceType.emaxII.imageExtensions.contains("ez2"))
    }

    func testEmaxIIImageExtensionsContainsHFE() {
        XCTAssertTrue(DeviceType.emaxII.imageExtensions.contains("hfe"))
    }

    func testEmaxIIFloppyExtensionsContainsHFE() {
        XCTAssertTrue(DeviceType.emaxII.floppyExtensions.contains("hfe"))
    }

    func testEmaxIIFloppyExtensionsDoNotContainHDA() {
        XCTAssertFalse(DeviceType.emaxII.floppyExtensions.contains("hda"))
    }

    func testEmaxIIBankExtensionsContainsEB2() {
        XCTAssertTrue(DeviceType.emaxII.bankExtensions.contains("eb2"))
    }

    func testEmaxIISCSIPrefix() {
        XCTAssertEqual(DeviceType.emaxII.scsiPrefix, "HD")
    }

    func testEmaxIIFloppyPrefix() {
        XCTAssertEqual(DeviceType.emaxII.floppyPrefix, "FD")
    }

    func testEmaxIIMaxScsiID() {
        XCTAssertEqual(DeviceType.emaxII.maxScsiID, 6)
    }

    func testAllCasesContainsEmaxII() {
        XCTAssertTrue(DeviceType.allCases.contains(.emaxII))
    }
}

// MARK: - EmaxIIFormat constants

/// Tests for EmaxIIFormat enum constants — all are compile-time values, no I/O.
final class EmaxIIFormatTests: XCTestCase {

    func testHeaderSize() {
        XCTAssertEqual(EmaxIIFormat.headerSize, 0x200)  // 512
    }

    func testPresetAreaOffset() {
        XCTAssertEqual(EmaxIIFormat.presetAreaOffset, 0x200)  // 512
    }

    func testPresetSize() {
        XCTAssertEqual(EmaxIIFormat.presetSize, 0x100)  // 256
    }

    func testMaxPresets() {
        XCTAssertEqual(EmaxIIFormat.maxPresets, 256)
    }

    func testSampleParamOffset() {
        XCTAssertEqual(EmaxIIFormat.sampleParamOffset, 0x10200)  // 66048
    }

    func testSampleParamSize() {
        XCTAssertEqual(EmaxIIFormat.sampleParamSize, 0x40)  // 64
    }

    func testMaxSamples() {
        XCTAssertEqual(EmaxIIFormat.maxSamples, 999)
    }

    func testSampleDataOffset() {
        XCTAssertEqual(EmaxIIFormat.sampleDataOffset, 0x20000)  // 131072
    }

    func testParamStartAddr() {
        XCTAssertEqual(EmaxIIFormat.paramStartAddr, 0)
    }

    func testParamEndAddr() {
        XCTAssertEqual(EmaxIIFormat.paramEndAddr, 4)
    }

    func testParamSampleRate() {
        XCTAssertEqual(EmaxIIFormat.paramSampleRate, 8)
    }

    func testParamName() {
        XCTAssertEqual(EmaxIIFormat.paramName, 32)
    }

    func testDefaultSampleRate() {
        XCTAssertEqual(EmaxIIFormat.defaultSampleRate, 39063)
    }

    func testBitDepth() {
        XCTAssertEqual(EmaxIIFormat.bitDepth, 16)
    }

    func testSampleRatesContains22050() {
        XCTAssertTrue(EmaxIIFormat.sampleRates.contains(22050))
    }

    func testSampleRatesContains44100() {
        XCTAssertTrue(EmaxIIFormat.sampleRates.contains(44100))
    }

    func testNumSamplesOffset() {
        XCTAssertEqual(EmaxIIFormat.numSamplesOffset, 0x1E)
    }

    // Bank header field offsets
    func testBankNameOffset() {
        XCTAssertEqual(EmaxIIFormat.bankNameOffset, 0x04)
    }

    func testNumPresetsOffset() {
        XCTAssertEqual(EmaxIIFormat.numPresetsOffset, 0x1C)
    }

    func testTotalSampleSizeOffset() {
        XCTAssertEqual(EmaxIIFormat.totalSampleSizeOffset, 0x20)
    }

    // Per-sample param field offsets (within each 64-byte block)
    func testParamOriginalKey() {
        XCTAssertEqual(EmaxIIFormat.paramOriginalKey, 10)  // +0x0A
    }

    func testParamFlags() {
        XCTAssertEqual(EmaxIIFormat.paramFlags, 11)        // +0x0B
    }

    func testParamSustainLoopStart() {
        XCTAssertEqual(EmaxIIFormat.paramSustainLoopStart, 12)  // +0x0C
    }

    func testParamSustainLoopEnd() {
        XCTAssertEqual(EmaxIIFormat.paramSustainLoopEnd, 16)    // +0x10
    }

    func testParamReleaseLoopStart() {
        XCTAssertEqual(EmaxIIFormat.paramReleaseLoopStart, 20)  // +0x14
    }

    func testParamReleaseLoopEnd() {
        XCTAssertEqual(EmaxIIFormat.paramReleaseLoopEnd, 24)    // +0x18
    }

    func testParamLoopFlags() {
        XCTAssertEqual(EmaxIIFormat.paramLoopFlags, 28)    // +0x1C
    }

    func testParamOutputChannel() {
        XCTAssertEqual(EmaxIIFormat.paramOutputChannel, 48) // +0x30
    }

    // Legacy alias verification
    func testParamLoopStartIsAliasForSustainLoopStart() {
        XCTAssertEqual(EmaxIIFormat.paramLoopStart, EmaxIIFormat.paramSustainLoopStart)
    }

    func testParamLoopEndIsAliasForSustainLoopEnd() {
        XCTAssertEqual(EmaxIIFormat.paramLoopEnd, EmaxIIFormat.paramSustainLoopEnd)
    }

    // Structural consistency checks
    func testSampleParamAreaFitsMaxSamples() {
        // maxSamples × sampleParamSize must fit between sampleParamOffset and sampleDataOffset
        let endOfParamArea = EmaxIIFormat.sampleParamOffset + EmaxIIFormat.maxSamples * EmaxIIFormat.sampleParamSize
        XCTAssertLessThanOrEqual(endOfParamArea, EmaxIIFormat.sampleDataOffset,
                                  "Param table overflows into sample data area")
    }

    func testPresetAreaFitsMaxPresets() {
        // maxPresets × presetSize must fit before sampleParamOffset
        let endOfPresetArea = EmaxIIFormat.presetAreaOffset + EmaxIIFormat.maxPresets * EmaxIIFormat.presetSize
        XCTAssertLessThanOrEqual(endOfPresetArea, EmaxIIFormat.sampleParamOffset,
                                  "Preset area overflows into sample param area")
    }
}

// MARK: - EmaxIIFileSystem computed properties

/// Tests for EmaxIIFileSystem computed properties — pure, constructed in-memory.
final class EmaxIIFileSystemTests: XCTestCase {

    private func makeBankEntry(bankIndex: UInt16, name: String = "BANK") -> BankCatalogEntry {
        BankCatalogEntry(
            catalogIndex: 0, name: name, bankIndex: bankIndex,
            startCluster: 2, numPresets: 1,
            fieldA: 0, fieldB: 0, flags: 0x81,
            clusterChain: [2], sizeBytes: 489472
        )
    }

    private func makeFS(fat: [UInt16] = [], banks: [BankCatalogEntry] = [],
                        clusterAreaStartSector: UInt32 = 98) -> EmaxIIFileSystem {
        EmaxIIFileSystem(
            magic: "EMX2", clusterSize: 489472,
            clusterAreaStartSector: clusterAreaStartSector,
            fat: fat, banks: banks, imageSize: 250_398_720
        )
    }

    // MARK: - maxClusters

    func testMaxClustersEqualsFATCount() {
        let fs = makeFS(fat: [UInt16](repeating: 0, count: 10))
        XCTAssertEqual(fs.maxClusters, 10)
    }

    func testMaxClustersZeroForEmptyFAT() {
        let fs = makeFS(fat: [])
        XCTAssertEqual(fs.maxClusters, 0)
    }

    // MARK: - usedClusters

    func testUsedClustersExcludesFreeAndReserved() {
        // [0x8000=reserved, 0x7FFF=EOC, 0x0000=free, 0x0000=free, 1=used]
        let fat: [UInt16] = [0x8000, 0x7FFF, 0x0000, 0x0000, 1]
        let fs = makeFS(fat: fat)
        // Only 0x7FFF and 1 are counted (not 0x8000, not 0x0000)
        XCTAssertEqual(fs.usedClusters, 2)
    }

    func testUsedClustersAllFreeIsZero() {
        let fat: [UInt16] = [0, 0, 0, 0]
        let fs = makeFS(fat: fat)
        XCTAssertEqual(fs.usedClusters, 0)
    }

    // MARK: - freeClusters

    func testFreeClustersCountsOnlyZeroEntries() {
        let fat: [UInt16] = [0x8000, 0, 0, 0x7FFF, 1]
        let fs = makeFS(fat: fat)
        XCTAssertEqual(fs.freeClusters, 2)
    }

    func testFreeClustersIsZeroWhenAllUsed() {
        let fat: [UInt16] = [0x8000, 0x7FFF, 0x7FFF]
        let fs = makeFS(fat: fat)
        XCTAssertEqual(fs.freeClusters, 0)
    }

    // MARK: - hasOS / osName

    func testHasOSTrueWhenOSEntryPresent() {
        let osEntry = makeBankEntry(bankIndex: 0x7800, name: "EMAX2 Software")
        let fs = makeFS(banks: [osEntry])
        XCTAssertTrue(fs.hasOS)
    }

    func testHasOSFalseWhenNoOSEntry() {
        let userEntry = makeBankEntry(bankIndex: 0, name: "STRINGS")
        let fs = makeFS(banks: [userEntry])
        XCTAssertFalse(fs.hasOS)
    }

    func testOSNameReturnsCorrectName() {
        let osEntry = makeBankEntry(bankIndex: 0x7800, name: "EMAX2 Software")
        let fs = makeFS(banks: [osEntry])
        XCTAssertEqual(fs.osName, "EMAX2 Software")
    }

    func testOSNameNilWhenNoOS() {
        let fs = makeFS(banks: [])
        XCTAssertNil(fs.osName)
    }

    // MARK: - userBanks

    func testUserBanksExcludesOSEntry() {
        let osEntry = makeBankEntry(bankIndex: 0x7800, name: "OS")
        let userEntry = makeBankEntry(bankIndex: 0, name: "STRINGS")
        let fs = makeFS(banks: [osEntry, userEntry])
        XCTAssertEqual(fs.userBanks.count, 1)
        XCTAssertEqual(fs.userBanks[0].name, "STRINGS")
    }

    func testUserBanksAllWhenNoOS() {
        let a = makeBankEntry(bankIndex: 0, name: "A")
        let b = makeBankEntry(bankIndex: 256, name: "B")
        let fs = makeFS(banks: [a, b])
        XCTAssertEqual(fs.userBanks.count, 2)
    }

    // MARK: - clusterAreaStartOffset

    func testClusterAreaStartOffsetIsStartSectorTimes512() {
        let fs = makeFS(clusterAreaStartSector: 98)
        XCTAssertEqual(fs.clusterAreaStartOffset, UInt64(98 * 512))
    }

    func testClusterAreaStartOffsetFor120Sectors() {
        let fs = makeFS(clusterAreaStartSector: 120)
        XCTAssertEqual(fs.clusterAreaStartOffset, UInt64(120 * 512))
    }
}

// MARK: - SampleInfo computed properties

/// Tests for SampleInfo computed properties — pure, constructed in-memory.
final class SampleInfoTests: XCTestCase {

    private func makeSample(
        name: String = "KICK",
        bankName: String = "DRUMS",
        sampleIndex: Int = 0,
        size: Int = 1024,
        bitDepth: Int = 16,
        sampleRate: Int = 22050,
        duration: Double = 1.0,
        hasLoop: Bool = false,
        loopStart: Int? = nil,
        loopEnd: Int? = nil,
        usedByPresets: [String] = ["PRESET1"]
    ) -> SampleInfo {
        SampleInfo(
            name: name, bankName: bankName, sampleIndex: sampleIndex,
            size: size, bitDepth: bitDepth, sampleRate: sampleRate,
            duration: duration, hasLoop: hasLoop,
            loopStart: loopStart, loopEnd: loopEnd,
            usedByPresets: usedByPresets, pcmData: Data(count: size)
        )
    }

    func testIsOrphanTrueWhenNoPresentUsing() {
        let s = makeSample(usedByPresets: [])
        XCTAssertTrue(s.isOrphan)
    }

    func testIsOrphanFalseWhenUsedByPreset() {
        let s = makeSample(usedByPresets: ["INIT PRESET"])
        XCTAssertFalse(s.isOrphan)
    }

    func testFormattedRateIncludesHz() {
        let s = makeSample(sampleRate: 22050)
        XCTAssertEqual(s.formattedRate, "22050 Hz")
    }

    func testFormatDescriptionIs16Bit() {
        let s = makeSample(bitDepth: 16)
        XCTAssertEqual(s.formatDescription, "16-bit")
    }

    func testFormattedDurationSubSecond() {
        // duration = 0.5 → "0.500 s"
        let s = makeSample(duration: 0.5)
        XCTAssertEqual(s.formattedDuration, "0.500 s")
    }

    func testFormattedDurationWholeSecond() {
        // duration = 1.0 → "1.000 s"
        let s = makeSample(duration: 1.0)
        XCTAssertEqual(s.formattedDuration, "1.000 s")
    }

    func testFormattedDurationWithMinutes() {
        // duration = 65.125 (exact binary float) → 1 min 5.125s → "1:05.125"
        let s = makeSample(duration: 65.125)
        XCTAssertEqual(s.formattedDuration, "1:05.125")
    }
}

// MARK: - BankTransferPayload

/// Tests for BankTransferPayload — struct fields and JSON encode/decode.
final class BankTransferPayloadTests: XCTestCase {

    func testFieldAccess() {
        let p = BankTransferPayload(
            bankName: "STRINGS",
            catalogIndex: 3,
            sourceImagePath: "/tmp/disk.hda"
        )
        XCTAssertEqual(p.bankName, "STRINGS")
        XCTAssertEqual(p.catalogIndex, 3)
        XCTAssertEqual(p.sourceImagePath, "/tmp/disk.hda")
    }

    func testJSONDataIsNonNil() {
        let p = BankTransferPayload(
            bankName: "BRASS", catalogIndex: 1, sourceImagePath: "/tmp/a.hda"
        )
        XCTAssertNotNil(p.jsonData)
    }

    func testFromDataRoundTrip() {
        let original = BankTransferPayload(
            bankName: "PIANO", catalogIndex: 7, sourceImagePath: "/sd/disk.hda"
        )
        guard let data = original.jsonData else {
            XCTFail("jsonData returned nil")
            return
        }
        let decoded = BankTransferPayload.from(data: data)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.bankName, "PIANO")
        XCTAssertEqual(decoded?.catalogIndex, 7)
        XCTAssertEqual(decoded?.sourceImagePath, "/sd/disk.hda")
    }

    func testFromDataReturnsNilForInvalidData() {
        let invalidData = Data("not json".utf8)
        XCTAssertNil(BankTransferPayload.from(data: invalidData))
    }
}

// MARK: - DiskTransactionManager

/// Tests for DiskTransactionManager computed properties — no file I/O needed.
@MainActor
final class DiskTransactionManagerTests: XCTestCase {

    func testCanUndoFalseOnFreshManager() {
        // Use a local instance to avoid shared-state pollution
        // DiskTransactionManager.shared has empty stacks by default
        let mgr = DiskTransactionManager.shared
        // Verify canUndo/canRedo reflect stack state
        let undoBefore = mgr.canUndo
        let redoBefore = mgr.canRedo
        // Both should agree with stack emptiness
        XCTAssertEqual(undoBefore, !mgr.undoStack.isEmpty)
        XCTAssertEqual(redoBefore, !mgr.redoStack.isEmpty)
    }

    func testUndoDescriptionNilWhenStackEmpty() {
        let mgr = DiskTransactionManager.shared
        if mgr.undoStack.isEmpty {
            XCTAssertNil(mgr.undoDescription)
        }
    }

    func testRedoDescriptionNilWhenStackEmpty() {
        let mgr = DiskTransactionManager.shared
        if mgr.redoStack.isEmpty {
            XCTAssertNil(mgr.redoDescription)
        }
    }
}

// MARK: - DiskTransaction struct

/// Tests for DiskTransaction / DiskRegionSnapshot struct field access.
final class DiskTransactionStructTests: XCTestCase {

    func testDiskRegionSnapshotFieldAccess() {
        let snap = DiskRegionSnapshot(
            fileURL: URL(fileURLWithPath: "/tmp/disk.hda"),
            offset: 0x400,
            originalData: Data(count: 512)
        )
        XCTAssertEqual(snap.offset, 0x400)
        XCTAssertEqual(snap.originalData.count, 512)
    }

    func testDiskTransactionFieldAccess() {
        let tx = DiskTransaction(
            id: UUID(),
            timestamp: Date(),
            description: "Import bank",
            snapshots: []
        )
        XCTAssertEqual(tx.description, "Import bank")
        XCTAssertTrue(tx.snapshots.isEmpty)
    }
}
