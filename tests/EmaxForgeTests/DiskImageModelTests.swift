import XCTest
import Foundation
@testable import EmaxForge

// MARK: - FloppySize

/// Tests for FloppySize enum — raw values, displayNames, and detect(bytes:).
final class FloppySizeTests: XCTestCase {

    // MARK: - Raw values

    func testSingleDensityRawValue() {
        XCTAssertEqual(FloppySize.singleDensity.rawValue, 184_320)
    }

    func testDoubleDensityRawValue() {
        XCTAssertEqual(FloppySize.doubleDensity.rawValue, 819_200)
    }

    func testHighDensityRawValue() {
        XCTAssertEqual(FloppySize.highDensity.rawValue, 1_474_560)
    }

    func testAllCasesCount() {
        XCTAssertEqual(FloppySize.allCases.count, 3)
    }

    // MARK: - displayName

    func testSingleDensityDisplayName() {
        XCTAssertEqual(FloppySize.singleDensity.displayName, "180 KB (SD)")
    }

    func testDoubleDensityDisplayName() {
        XCTAssertEqual(FloppySize.doubleDensity.displayName, "800 KB (DD)")
    }

    func testHighDensityDisplayName() {
        XCTAssertEqual(FloppySize.highDensity.displayName, "1.44 MB (HD)")
    }

    // MARK: - detect(bytes:)

    func testDetectExactSingleDensity() {
        XCTAssertEqual(FloppySize.detect(bytes: 184_320), .singleDensity)
    }

    func testDetectExactDoubleDensity() {
        XCTAssertEqual(FloppySize.detect(bytes: 819_200), .doubleDensity)
    }

    func testDetectExactHighDensity() {
        XCTAssertEqual(FloppySize.detect(bytes: 1_474_560), .highDensity)
    }

    func testDetectDoubleDensityWithToleranceUnder5Percent() {
        // 819_200 * 0.04 ≈ 32_768 — well within 5%
        XCTAssertEqual(FloppySize.detect(bytes: 819_200 + 20_000), .doubleDensity)
    }

    func testDetectNilForUnrecognisedSize() {
        XCTAssertNil(FloppySize.detect(bytes: 12_345_678))
    }

    func testDetectNilForSmallFile() {
        XCTAssertNil(FloppySize.detect(bytes: 100))
    }
}

// MARK: - DiskImage computed properties

/// Tests for DiskImage computed properties — all constructed in-memory, no real disk.
final class DiskImageComputedTests: XCTestCase {

    // Convenience factory — does NOT use DiskImage.parse() (that reads fileSize from disk)
    private func makeHD(
        filename: String = "HD10.hda",
        fileSize: Int64 = 250_398_720,
        scsiID: Int? = 1,
        imageIndex: Int? = 0,
        label: String? = nil
    ) -> DiskImage {
        DiskImage(
            url: URL(fileURLWithPath: "/Volumes/SD/\(filename)"),
            filename: filename,
            fileSize: fileSize,
            scsiID: scsiID,
            imageIndex: imageIndex,
            label: label,
            deviceType: .emaxII
        )
    }

    private func makeFD(
        filename: String = "FD00.img",
        fileSize: Int64 = 819_200,
        scsiID: Int? = 0,
        imageIndex: Int? = nil,
        label: String? = nil
    ) -> DiskImage {
        DiskImage(
            url: URL(fileURLWithPath: "/Volumes/SD/\(filename)"),
            filename: filename,
            fileSize: fileSize,
            scsiID: scsiID,
            imageIndex: imageIndex,
            label: label,
            deviceType: .emaxII
        )
    }

    // MARK: - isFloppy

    func testHDPrefixIsNotFloppy() {
        XCTAssertFalse(makeHD(filename: "HD10.hda").isFloppy)
    }

    func testFDPrefixIsFloppy() {
        XCTAssertTrue(makeFD(filename: "FD00.img").isFloppy)
    }

    func testHFEExtensionIsFloppy() {
        // HFE extension → floppyExtensions for emaxII
        let img = DiskImage(
            url: URL(fileURLWithPath: "/Volumes/SD/EMAX.hfe"),
            filename: "EMAX.hfe",
            fileSize: 1_474_560,
            scsiID: nil,
            imageIndex: nil,
            label: nil,
            deviceType: .emaxII
        )
        XCTAssertTrue(img.isFloppy)
    }

    // MARK: - fileExtension

    func testFileExtensionHDA() {
        XCTAssertEqual(makeHD(filename: "HD10.hda").fileExtension, "hda")
    }

    func testFileExtensionIsLowercased() {
        let img = DiskImage(
            url: URL(fileURLWithPath: "/SD/DISK.HDA"),
            filename: "DISK.HDA",
            fileSize: 1024,
            scsiID: nil,
            imageIndex: nil,
            label: nil,
            deviceType: .emaxII
        )
        XCTAssertEqual(img.fileExtension, "hda")
    }

    func testFileExtensionIMG() {
        XCTAssertEqual(makeFD(filename: "FD00.img").fileExtension, "img")
    }

    // MARK: - floppySize

    func testFloppySizeNilForHDImage() {
        XCTAssertNil(makeHD().floppySize)
    }

    func testFloppySizeDoubleDensityFor800K() {
        let fd = makeFD(filename: "FD00.img", fileSize: 819_200)
        XCTAssertEqual(fd.floppySize, .doubleDensity)
    }

    func testFloppySizeHighDensityFor144MB() {
        let fd = makeFD(filename: "FD00.img", fileSize: 1_474_560)
        XCTAssertEqual(fd.floppySize, .highDensity)
    }

    // MARK: - formattedSize

    func testFormattedSizeIsNonEmpty() {
        XCTAssertFalse(makeHD(fileSize: 250_398_720).formattedSize.isEmpty)
    }

    func testFormattedSizeForMBRangeContainsMB() {
        // 250 MB should show "MB" in output
        let s = makeHD(fileSize: 250_000_000).formattedSize
        XCTAssertTrue(s.contains("MB") || s.contains("Mb") || s.contains("mb"),
                      "Expected MB unit in '\(s)'")
    }

    // MARK: - zuluSCSIName — HD images

    func testZuluSCSINameHDNoImageIndexNoLabel() {
        let img = makeHD(filename: "HD10.hda", scsiID: 1, imageIndex: nil, label: nil)
        XCTAssertEqual(img.zuluSCSIName, "HD1.hda")
    }

    func testZuluSCSINameHDWithImageIndex() {
        let img = makeHD(filename: "HD10.hda", scsiID: 1, imageIndex: 0, label: nil)
        XCTAssertEqual(img.zuluSCSIName, "HD1_0.hda")
    }

    func testZuluSCSINameHDWithLabel() {
        let img = makeHD(filename: "HD10.hda", scsiID: 1, imageIndex: 0, label: "Strings")
        XCTAssertEqual(img.zuluSCSIName, "HD1_0_Strings.hda")
    }

    func testZuluSCSINameHDWithEmptyLabelOmitsLabel() {
        let img = makeHD(filename: "HD10.hda", scsiID: 1, imageIndex: 0, label: "")
        XCTAssertEqual(img.zuluSCSIName, "HD1_0.hda")
    }

    func testZuluSCSINameFallsBackToFilenameWhenNoSCSIID() {
        let img = makeHD(filename: "unknown.hda", scsiID: nil, imageIndex: nil, label: nil)
        XCTAssertEqual(img.zuluSCSIName, "unknown.hda")
    }

    // MARK: - zuluSCSIName — FD images

    func testZuluSCSINameFDNoImageIndex() {
        let fd = makeFD(filename: "FD00.img", scsiID: 0, imageIndex: nil, label: nil)
        XCTAssertEqual(fd.zuluSCSIName, "FD0.img")
    }

    func testZuluSCSINameFDWithImageIndex() {
        let fd = makeFD(filename: "FD00.img", scsiID: 0, imageIndex: 1, label: nil)
        XCTAssertEqual(fd.zuluSCSIName, "FD0_1.img")
    }

    func testZuluSCSINameFDAlwaysGetsImgExtension() {
        let fd = makeFD(filename: "FD00.hfe", scsiID: 0, imageIndex: nil, label: nil)
        XCTAssertTrue(fd.zuluSCSIName.hasSuffix(".img"))
    }
}

// MARK: - MountedVolume

/// Tests for MountedVolume computed properties — pure struct, no I/O.
final class MountedVolumeTests: XCTestCase {

    private func makeVolume(totalSize: Int64 = 1000, freeSpace: Int64 = 250) -> MountedVolume {
        MountedVolume(
            url: URL(fileURLWithPath: "/Volumes/SD"),
            name: "SD Card",
            isRemovable: true,
            totalSize: totalSize,
            freeSpace: freeSpace
        )
    }

    func testUsagePercentBasic() {
        // used = 750 / 1000 = 0.75
        let v = makeVolume(totalSize: 1000, freeSpace: 250)
        XCTAssertEqual(v.usagePercent, 0.75, accuracy: 0.001)
    }

    func testUsagePercentZeroForZeroTotalSize() {
        let v = makeVolume(totalSize: 0, freeSpace: 0)
        XCTAssertEqual(v.usagePercent, 0.0, accuracy: 0.001)
    }

    func testUsagePercentZeroWhenFreeEqualsTotal() {
        let v = makeVolume(totalSize: 1000, freeSpace: 1000)
        XCTAssertEqual(v.usagePercent, 0.0, accuracy: 0.001)
    }

    func testUsagePercentFullWhenNoFreeSpace() {
        let v = makeVolume(totalSize: 1000, freeSpace: 0)
        XCTAssertEqual(v.usagePercent, 1.0, accuracy: 0.001)
    }

    func testFormattedTotalIsNonEmpty() {
        XCTAssertFalse(makeVolume(totalSize: 1_000_000_000).formattedTotal.isEmpty)
    }

    func testFormattedFreeIsNonEmpty() {
        XCTAssertFalse(makeVolume(freeSpace: 500_000_000).formattedFree.isEmpty)
    }

    func testFieldAccess() {
        let v = makeVolume()
        XCTAssertEqual(v.name, "SD Card")
        XCTAssertTrue(v.isRemovable)
        XCTAssertEqual(v.totalSize, 1000)
        XCTAssertEqual(v.freeSpace, 250)
    }
}

// MARK: - NavigationDestination

/// Tests for NavigationDestination.title and .icon — pure enum computed properties.
final class NavigationDestinationTests: XCTestCase {

    // Shared DiskImage for cases that need one
    private var img: DiskImage {
        DiskImage(
            url: URL(fileURLWithPath: "/Volumes/SD/HD10.hda"),
            filename: "HD10.hda",
            fileSize: 250_398_720,
            scsiID: 1,
            imageIndex: 0,
            label: nil,
            deviceType: .emaxII
        )
    }

    // Shared BankSampleData.SampleEntry
    private var sampleEntry: BankSampleData.SampleEntry {
        BankSampleData.SampleEntry(
            index: 0,
            name: "KICK",
            pcmData: Data(count: 100),
            sampleRate: 22050,
            loopStart: nil,
            loopEnd: nil,
            rootKey: 60
        )
    }

    // MARK: - title

    func testImageDetailTitleIsFilename() {
        XCTAssertEqual(NavigationDestination.imageDetail(img).title, "HD10.hda")
    }

    func testBankBrowserTitleIsBanks() {
        let fs = EmaxIIFileSystem(
            magic: "EMX2", clusterSize: 489472, clusterAreaStartSector: 98,
            fat: [], banks: [], imageSize: 250_398_720
        )
        XCTAssertEqual(NavigationDestination.bankBrowser(image: img, fileSystem: fs).title, "Banks")
    }

    func testSampleEditorTitleIsSampleName() {
        XCTAssertEqual(NavigationDestination.sampleEditor(sample: sampleEntry, bankName: "DRUMS").title, "KICK")
    }

    func testPresetEditorTitleIsPresetName() {
        let vp = VoiceParameters()
        XCTAssertEqual(NavigationDestination.presetEditor(params: vp, presetName: "BRASS").title, "BRASS")
    }

    func testBatchRenameTitleIsBatchRename() {
        XCTAssertEqual(NavigationDestination.batchRename(img).title, "Batch Rename")
    }

    func testHexViewerTitleIsHexView() {
        XCTAssertEqual(NavigationDestination.hexViewer(img).title, "Hex View")
    }

    func testImportBanksTitleIsImportBanks() {
        XCTAssertEqual(NavigationDestination.importBanks(img).title, "Import Banks")
    }

    func testConvertSamplesTitleIsConvertSamples() {
        XCTAssertEqual(NavigationDestination.convertSamples(img).title, "Convert Samples")
    }

    func testSlotManagerTitleIsSlotManager() {
        XCTAssertEqual(NavigationDestination.slotManager.title, "Slot Manager")
    }

    // MARK: - icon

    func testImageDetailIconIsInternaldrive() {
        XCTAssertEqual(NavigationDestination.imageDetail(img).icon, "internaldrive")
    }

    func testBankBrowserIconIsMusicNoteList() {
        let fs = EmaxIIFileSystem(
            magic: "EMX2", clusterSize: 489472, clusterAreaStartSector: 98,
            fat: [], banks: [], imageSize: 250_398_720
        )
        XCTAssertEqual(NavigationDestination.bankBrowser(image: img, fileSystem: fs).icon, "music.note.list")
    }

    func testSampleEditorIconIsWaveformPath() {
        XCTAssertEqual(NavigationDestination.sampleEditor(sample: sampleEntry, bankName: "DRUMS").icon, "waveform.path")
    }

    func testPresetEditorIconIsSliderHorizontal3() {
        let vp = VoiceParameters()
        XCTAssertEqual(NavigationDestination.presetEditor(params: vp, presetName: "X").icon, "slider.horizontal.3")
    }

    func testSlotManagerIconIsSquareGrid3x3() {
        XCTAssertEqual(NavigationDestination.slotManager.icon, "square.grid.3x3")
    }

    // MARK: - Equality

    func testSlotManagerEqualsItself() {
        XCTAssertEqual(NavigationDestination.slotManager, NavigationDestination.slotManager)
    }

    func testImageDetailEqualsForSameImage() {
        // Store once so both uses share the same UUID
        let image = img
        let dest1 = NavigationDestination.imageDetail(image)
        let dest2 = NavigationDestination.imageDetail(image)
        XCTAssertEqual(dest1, dest2)
    }

    func testImageDetailNotEqualForDifferentImages() {
        let img1 = DiskImage(url: URL(fileURLWithPath: "/a.hda"), filename: "a.hda",
                             fileSize: 1, scsiID: nil, imageIndex: nil, label: nil, deviceType: .emaxII)
        let img2 = DiskImage(url: URL(fileURLWithPath: "/b.hda"), filename: "b.hda",
                             fileSize: 1, scsiID: nil, imageIndex: nil, label: nil, deviceType: .emaxII)
        XCTAssertNotEqual(NavigationDestination.imageDetail(img1), NavigationDestination.imageDetail(img2))
    }

    func testPresetEditorEqualsForSamePresetName() {
        let vp = VoiceParameters()
        let d1 = NavigationDestination.presetEditor(params: vp, presetName: "PIANO")
        let d2 = NavigationDestination.presetEditor(params: vp, presetName: "PIANO")
        XCTAssertEqual(d1, d2)
    }
}

// MARK: - AutoSaveState (Codable)

/// Tests for AutoSaveState Codable round-trip — no disk I/O via FileManager.
final class AutoSaveStateTests: XCTestCase {

    func testRoundTripWithPaths() throws {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let state = AutoSaveState(
            selectedVolumePath: "/Volumes/SD",
            selectedImagePath: "/tmp/disk.hda",
            timestamp: timestamp
        )
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(AutoSaveState.self, from: data)
        XCTAssertEqual(decoded.selectedVolumePath, "/Volumes/SD")
        XCTAssertEqual(decoded.selectedImagePath, "/tmp/disk.hda")
        XCTAssertEqual(decoded.timestamp.timeIntervalSince1970,
                       timestamp.timeIntervalSince1970, accuracy: 0.001)
    }

    func testRoundTripWithNilPaths() throws {
        let state = AutoSaveState(
            selectedVolumePath: nil,
            selectedImagePath: nil,
            timestamp: Date()
        )
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(AutoSaveState.self, from: data)
        XCTAssertNil(decoded.selectedVolumePath)
        XCTAssertNil(decoded.selectedImagePath)
    }

    func testEncodesToValidJSON() throws {
        let state = AutoSaveState(
            selectedVolumePath: "/Volumes/SD",
            selectedImagePath: "/disk.hda",
            timestamp: Date()
        )
        let data = try JSONEncoder().encode(state)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertNotNil(json?["selectedVolumePath"])
        XCTAssertNotNil(json?["selectedImagePath"])
    }
}

// MARK: - BankSampleData.SampleEntry

/// Tests for BankSampleData.SampleEntry computed properties — pure, in-memory.
final class BankSampleDataEntryTests: XCTestCase {

    private func makeEntry(frames: Int = 100, sampleRate: Int = 22050) -> BankSampleData.SampleEntry {
        // pcmData.count / 2 = frames → pcmData = 2*frames bytes (16-bit)
        BankSampleData.SampleEntry(
            index: 0,
            name: "KICK",
            pcmData: Data(count: frames * 2),
            sampleRate: sampleRate,
            loopStart: nil,
            loopEnd: nil,
            rootKey: 60
        )
    }

    func testFrameCountIsHalfPCMDataCount() {
        let entry = makeEntry(frames: 100)
        XCTAssertEqual(entry.frameCount, 100)
    }

    func testFrameCountZeroForEmptyData() {
        let entry = makeEntry(frames: 0)
        XCTAssertEqual(entry.frameCount, 0)
    }

    func testDurationIsFrameCountDividedBySampleRate() {
        // 22050 frames at 22050 Hz = 1.0 second
        let entry = makeEntry(frames: 22050, sampleRate: 22050)
        XCTAssertEqual(entry.duration, 1.0, accuracy: 0.0001)
    }

    func testDurationZeroForZeroSampleRate() {
        let entry = makeEntry(frames: 100, sampleRate: 0)
        XCTAssertEqual(entry.duration, 0.0, accuracy: 0.0001)
    }

    func testDurationHalfSecond() {
        // 11025 frames at 22050 Hz = 0.5 s
        let entry = makeEntry(frames: 11025, sampleRate: 22050)
        XCTAssertEqual(entry.duration, 0.5, accuracy: 0.0001)
    }

    func testNameFieldAccess() {
        let entry = makeEntry()
        XCTAssertEqual(entry.name, "KICK")
    }

    func testRootKeyFieldAccess() {
        let entry = makeEntry()
        XCTAssertEqual(entry.rootKey, 60)
    }

    func testLoopStartNilByDefault() {
        XCTAssertNil(makeEntry().loopStart)
    }

    func testLoopEndNilByDefault() {
        XCTAssertNil(makeEntry().loopEnd)
    }
}
