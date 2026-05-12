import XCTest
import Foundation
@testable import EmaxForge

// MARK: - ChatMessage & AIConnectionState

/// Tests for AIAssistantService types — pure struct/enum logic, no network calls.
final class ChatMessageTests: XCTestCase {

    func testChatMessageUserRoleIsUser() {
        let msg = ChatMessage(role: .user, content: "hello", timestamp: Date())
        XCTAssertTrue(msg.isUser)
        XCTAssertFalse(msg.isAssistant)
    }

    func testChatMessageAssistantRoleIsAssistant() {
        let msg = ChatMessage(role: .assistant, content: "hello", timestamp: Date())
        XCTAssertTrue(msg.isAssistant)
        XCTAssertFalse(msg.isUser)
    }

    func testChatMessageContentIsMutable() {
        var msg = ChatMessage(role: .user, content: "original", timestamp: Date())
        msg.content = "updated"
        XCTAssertEqual(msg.content, "updated")
    }

    func testAIConnectionStateIsConnectedOnlyForConnected() {
        XCTAssertTrue(AIConnectionState.connected.isConnected)
        XCTAssertFalse(AIConnectionState.disconnected.isConnected)
        XCTAssertFalse(AIConnectionState.connecting.isConnected)
        XCTAssertFalse(AIConnectionState.error("x").isConnected)
    }

    func testAIConnectionStateEquality() {
        XCTAssertEqual(AIConnectionState.disconnected, AIConnectionState.disconnected)
        XCTAssertEqual(AIConnectionState.connected, AIConnectionState.connected)
        XCTAssertNotEqual(AIConnectionState.connected, AIConnectionState.disconnected)
    }
}

// MARK: - BackupManager

/// Tests for BackupManager error descriptions and structs — no disk I/O.
final class BackupManagerTests: XCTestCase {

    // MARK: - BackupError descriptions

    func testVolumeNotFoundDescription() {
        let err = BackupManager.BackupError.volumeNotFound
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testNoImagesToBackupDescription() {
        let err = BackupManager.BackupError.noImagesToBackup
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testBackupFailedDescriptionContainsMessage() {
        let err = BackupManager.BackupError.backupFailed("disk full")
        XCTAssertTrue(err.errorDescription?.contains("disk full") == true)
    }

    func testRestoreFailedDescriptionContainsMessage() {
        let err = BackupManager.BackupError.restoreFailed("checksum mismatch")
        XCTAssertTrue(err.errorDescription?.contains("checksum mismatch") == true)
    }

    func testInvalidArchiveDescription() {
        let err = BackupManager.BackupError.invalidArchive
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testInsufficientSpaceDescription() {
        let err = BackupManager.BackupError.insufficientSpace
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testAllBackupErrorsHaveNonEmptyDescriptions() {
        let errors: [BackupManager.BackupError] = [
            .volumeNotFound, .noImagesToBackup, .backupFailed("x"),
            .restoreFailed("x"), .invalidArchive, .insufficientSpace
        ]
        for err in errors {
            XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
        }
    }

    // MARK: - BackupInfo struct

    func testBackupInfoFieldAccess() {
        let ts = Date(timeIntervalSince1970: 0)
        let info = BackupManager.BackupInfo(
            timestamp: ts,
            volumeName: "MySD",
            deviceType: "emaxII",
            imageCount: 3,
            totalSize: 750_000_000,
            emaxForgeVersion: "1.0",
            fileList: ["HD10.hda", "HD20.hda"]
        )
        XCTAssertEqual(info.volumeName, "MySD")
        XCTAssertEqual(info.imageCount, 3)
        XCTAssertEqual(info.totalSize, 750_000_000)
        XCTAssertEqual(info.emaxForgeVersion, "1.0")
        XCTAssertEqual(info.fileList.count, 2)
    }

    func testBackupInfoFormattedDateIsNonEmpty() {
        let info = BackupManager.BackupInfo(
            timestamp: Date(),
            volumeName: "V", deviceType: "emaxII",
            imageCount: 1, totalSize: 0,
            emaxForgeVersion: "1.0", fileList: []
        )
        XCTAssertFalse(info.formattedDate.isEmpty)
    }

    // MARK: - BackupResult struct

    func testBackupResultFieldAccess() {
        let info = BackupManager.BackupInfo(
            timestamp: Date(), volumeName: "V", deviceType: "emaxII",
            imageCount: 0, totalSize: 0, emaxForgeVersion: "1.0", fileList: []
        )
        let r = BackupManager.BackupResult(
            archiveURL: URL(fileURLWithPath: "/tmp/backup.zip"),
            backupInfo: info,
            compressedSize: 5_000_000,
            compressionRatio: 0.75
        )
        XCTAssertEqual(r.compressedSize, 5_000_000)
        XCTAssertEqual(r.compressionRatio, 0.75, accuracy: 0.001)
    }

    // MARK: - RestoreResult struct

    func testRestoreResultFieldAccess() {
        let r = BackupManager.RestoreResult(
            restoredFiles: ["HD10.hda", "HD20.hda"],
            totalSize: 500_000_000
        )
        XCTAssertEqual(r.restoredFiles.count, 2)
        XCTAssertEqual(r.totalSize, 500_000_000)
    }
}

// MARK: - SampleExporter

/// Tests for SampleExporter types — enum values, error descriptions, struct access.
final class SampleExporterTests: XCTestCase {

    // MARK: - ExportFormat enum

    func testExportFormatWAVRawValue() {
        XCTAssertEqual(SampleExporter.ExportFormat.wav.rawValue, "WAV")
    }

    func testExportFormatAIFFRawValue() {
        XCTAssertEqual(SampleExporter.ExportFormat.aiff.rawValue, "AIFF")
    }

    func testExportFormatWAVExtension() {
        XCTAssertEqual(SampleExporter.ExportFormat.wav.fileExtension, "wav")
    }

    func testExportFormatAIFFExtension() {
        XCTAssertEqual(SampleExporter.ExportFormat.aiff.fileExtension, "aiff")
    }

    func testExportFormatAllCasesHasTwoCases() {
        XCTAssertEqual(SampleExporter.ExportFormat.allCases.count, 2)
    }

    // MARK: - ExportError descriptions

    func testNoSampleDataDescription() {
        let err = SampleExporter.ExportError.noSampleData
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testCreateFileFailedDescription() {
        let err = SampleExporter.ExportError.createFileFailed
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testWriteFailedDescriptionContainsMessage() {
        let err = SampleExporter.ExportError.writeFailed("permission denied")
        XCTAssertTrue(err.errorDescription?.contains("permission denied") == true)
    }

    func testInvalidFormatDescription() {
        let err = SampleExporter.ExportError.invalidFormat
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testAllExportErrorsHaveNonEmptyDescriptions() {
        let errors: [SampleExporter.ExportError] = [
            .noSampleData, .createFileFailed, .writeFailed("x"), .invalidFormat
        ]
        for err in errors {
            XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
        }
    }

    // MARK: - ExportResult struct

    func testExportResultFieldAccess() {
        let r = SampleExporter.ExportResult(
            sampleName: "KICK",
            outputURL: URL(fileURLWithPath: "/tmp/KICK.wav"),
            duration: 0.5,
            sampleRate: 22050,
            fileSize: 22050
        )
        XCTAssertEqual(r.sampleName, "KICK")
        XCTAssertEqual(r.duration, 0.5, accuracy: 0.001)
        XCTAssertEqual(r.sampleRate, 22050)
        XCTAssertEqual(r.fileSize, 22050)
    }
}

// MARK: - SampleExtractorService

/// Tests for SampleExtractorService types — error descriptions and ExtractionResult
/// computed properties. No subprocess calls.
final class SampleExtractorServiceTests: XCTestCase {

    func testExtractErrorScriptNotFoundDescription() {
        let err = SampleExtractorService.ExtractError.scriptNotFound
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testExtractErrorScriptFailedDescriptionContainsMessage() {
        let err = SampleExtractorService.ExtractError.scriptFailed("timeout")
        XCTAssertTrue(err.errorDescription?.contains("timeout") == true)
    }

    func testExtractErrorInvalidOutputDescription() {
        let err = SampleExtractorService.ExtractError.invalidOutput
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testExtractionResultFormattedSize() {
        let r = SampleExtractorService.ExtractionResult(
            outputURL: URL(fileURLWithPath: "/tmp/out.wav"),
            sampleRate: 22050,
            duration: 1.0,
            fileSize: 2048
        )
        XCTAssertEqual(r.formattedSize, "2.0 KB")
    }

    func testExtractionResultFormattedDuration() {
        let r = SampleExtractorService.ExtractionResult(
            outputURL: URL(fileURLWithPath: "/tmp/out.wav"),
            sampleRate: 22050,
            duration: 0.75,
            fileSize: 0
        )
        XCTAssertEqual(r.formattedDuration, "0.75 s")
    }
}

// MARK: - SamplePlayer

/// Tests for SamplePlayer static pure functions and constants — no AVAudio engine.
final class SamplePlayerTests: XCTestCase {

    // MARK: - sampleRates constant

    func testSampleRatesContains22050() {
        XCTAssertTrue(SamplePlayer.sampleRates.contains(22050))
    }

    func testSampleRatesContains44100() {
        XCTAssertTrue(SamplePlayer.sampleRates.contains(44100))
    }

    func testSampleRatesDoNotContain48000() {
        XCTAssertFalse(SamplePlayer.sampleRates.contains(48000))
    }

    func testSampleRatesHasSixEntries() {
        XCTAssertEqual(SamplePlayer.sampleRates.count, 6)
    }

    // MARK: - waveformSamples (pure)

    private func pcm(_ values: [Int16]) -> Data {
        var data = Data(capacity: values.count * 2)
        for v in values {
            var le = v.littleEndian
            data.append(Data(bytes: &le, count: 2))
        }
        return data
    }

    func testWaveformSamplesEmptyInputReturnsEmpty() {
        XCTAssertTrue(SamplePlayer.waveformSamples(from: Data()).isEmpty)
    }

    func testWaveformSamplesOutputCountIsTargetPoints() {
        // 200 frames, targetPoints=10 → 10 output points
        let data = pcm(Array(repeating: 1000, count: 200))
        let result = SamplePlayer.waveformSamples(from: data, targetPoints: 10)
        XCTAssertEqual(result.count, 10)
    }

    func testWaveformSamplesNormalizedBetween0And1() {
        let data = pcm(Array(repeating: 16384, count: 400))
        let result = SamplePlayer.waveformSamples(from: data, targetPoints: 20)
        for v in result {
            XCTAssertGreaterThanOrEqual(v, 0.0, "Waveform values must be ≥ 0")
            XCTAssertLessThanOrEqual(v, 1.0, "Waveform values must be ≤ 1")
        }
    }

    func testWaveformSamplesAllSilentIsAllZero() {
        let data = pcm(Array(repeating: 0, count: 200))
        let result = SamplePlayer.waveformSamples(from: data, targetPoints: 10)
        for v in result {
            XCTAssertEqual(v, 0.0, accuracy: 0.0001)
        }
    }

    func testWaveformSamplesFewerFramesThanTargetPoints() {
        // 5 frames, targetPoints=20 → output count capped to frameCount
        let data = pcm([100, 200, 300, 400, 500])
        let result = SamplePlayer.waveformSamples(from: data, targetPoints: 20)
        XCTAssertLessThanOrEqual(result.count, 20,
                                  "Output count cannot exceed targetPoints")
        XCTAssertGreaterThan(result.count, 0)
    }

    // MARK: - formatDuration (pure)

    func testFormatDurationZero() {
        XCTAssertEqual(SamplePlayer.formatDuration(0.0), "0:00.0")
    }

    func testFormatDurationOneMinute() {
        // 60s → "1:00.0"
        XCTAssertEqual(SamplePlayer.formatDuration(60.0), "1:00.0")
    }

    func testFormatDurationFractionalSeconds() {
        // 1.5s → "0:01.5"
        XCTAssertEqual(SamplePlayer.formatDuration(1.5), "0:01.5")
    }

    func testFormatDuration90Seconds() {
        // 90s = 1min 30s → "1:30.0"
        XCTAssertEqual(SamplePlayer.formatDuration(90.0), "1:30.0")
    }
}

// MARK: - OSManager

/// Tests for OSManager error descriptions and OSInfo struct.
final class OSManagerTests: XCTestCase {

    func testDiskReadFailedDescription() {
        let err = OSManager.OSError.diskReadFailed
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testDiskWriteFailedDescription() {
        let err = OSManager.OSError.diskWriteFailed
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testInvalidDiskStructureDescription() {
        let err = OSManager.OSError.invalidDiskStructure
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testOSNotFoundDescription() {
        let err = OSManager.OSError.osNotFound
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testOSReadFailedDescription() {
        let err = OSManager.OSError.osReadFailed
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testOSWriteFailedDescription() {
        let err = OSManager.OSError.osWriteFailed
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testInvalidOSFileDescription() {
        let err = OSManager.OSError.invalidOSFile
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testAllOSErrorsHaveNonEmptyDescriptions() {
        let errors: [OSManager.OSError] = [
            .diskReadFailed, .diskWriteFailed, .invalidDiskStructure,
            .osNotFound, .osReadFailed, .osWriteFailed, .invalidOSFile
        ]
        for err in errors {
            XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
        }
    }

    func testOSInfoFieldAccess() {
        let info = OSManager.OSInfo(version: "2.26", size: 489472, location: "Cluster 1")
        XCTAssertEqual(info.version, "2.26")
        XCTAssertEqual(info.size, 489472)
        XCTAssertEqual(info.location, "Cluster 1")
    }
}

// MARK: - MultiImageManager

/// Tests for MultiImageManager struct types and pure static methods.
final class MultiImageManagerTests: XCTestCase {

    private func makeDiskImage(
        filename: String,
        scsiID: Int? = nil,
        imageIndex: Int? = nil,
        label: String? = nil
    ) -> DiskImage {
        DiskImage(
            url: URL(fileURLWithPath: "/fake/\(filename)"),
            filename: filename,
            fileSize: 250_000_000,
            scsiID: scsiID,
            imageIndex: imageIndex,
            label: label,
            deviceType: .emaxII
        )
    }

    // MARK: - ImageSlot displayName

    func testImageSlotDisplayNameWithLabel() {
        let image = makeDiskImage(filename: "HD10.hda", scsiID: 1, imageIndex: 0, label: "Strings")
        let slot = MultiImageManager.ImageSlot(scsiID: 1, slotIndex: 0, image: image)
        XCTAssertEqual(slot.displayName, "Strings (Slot 0)")
    }

    func testImageSlotDisplayNameWithoutLabel() {
        let image = makeDiskImage(filename: "HD10.hda", scsiID: 1, imageIndex: 1, label: nil)
        let slot = MultiImageManager.ImageSlot(scsiID: 1, slotIndex: 1, image: image)
        XCTAssertEqual(slot.displayName, "Slot 1")
    }

    func testImageSlotDisplayNameWithEmptyLabel() {
        let image = makeDiskImage(filename: "HD10.hda", scsiID: 1, imageIndex: 2, label: "")
        let slot = MultiImageManager.ImageSlot(scsiID: 1, slotIndex: 2, image: image)
        XCTAssertEqual(slot.displayName, "Slot 2", "Empty label should fall back to 'Slot N'")
    }

    // MARK: - SlotGroup computed properties

    func testSlotGroupDisplayName() {
        let group = MultiImageManager.SlotGroup(id: 3, scsiID: 3, slots: [])
        XCTAssertEqual(group.displayName, "SCSI ID 3")
    }

    func testSlotGroupHasMultipleSlotsTrue() {
        let img = makeDiskImage(filename: "a.hda")
        let slot1 = MultiImageManager.ImageSlot(scsiID: 1, slotIndex: 0, image: img)
        let slot2 = MultiImageManager.ImageSlot(scsiID: 1, slotIndex: 1, image: img)
        let group = MultiImageManager.SlotGroup(id: 1, scsiID: 1, slots: [slot1, slot2])
        XCTAssertTrue(group.hasMultipleSlots)
    }

    func testSlotGroupHasMultipleSlotsFalse() {
        let img = makeDiskImage(filename: "a.hda")
        let slot = MultiImageManager.ImageSlot(scsiID: 1, slotIndex: 0, image: img)
        let group = MultiImageManager.SlotGroup(id: 1, scsiID: 1, slots: [slot])
        XCTAssertFalse(group.hasMultipleSlots)
    }

    // MARK: - groupImagesBySlot

    func testGroupImagesBySlotSkipsImagesWithoutSCSIID() {
        let images = [makeDiskImage(filename: "noID.hda", scsiID: nil)]
        let groups = MultiImageManager.groupImagesBySlot(images)
        XCTAssertTrue(groups.isEmpty, "Images without SCSI ID should be skipped")
    }

    func testGroupImagesBySlotSingleImageSingleGroup() {
        let images = [makeDiskImage(filename: "HD10.hda", scsiID: 1, imageIndex: 0)]
        let groups = MultiImageManager.groupImagesBySlot(images)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].scsiID, 1)
        XCTAssertEqual(groups[0].slots.count, 1)
    }

    func testGroupImagesBySlotTwoSCSIIDsProduceTwoGroups() {
        let images = [
            makeDiskImage(filename: "HD10.hda", scsiID: 1, imageIndex: 0),
            makeDiskImage(filename: "HD20.hda", scsiID: 2, imageIndex: 0)
        ]
        let groups = MultiImageManager.groupImagesBySlot(images)
        XCTAssertEqual(groups.count, 2)
    }

    func testGroupImagesBySlotMultiSlotSameID() {
        let images = [
            makeDiskImage(filename: "HD10.hda", scsiID: 1, imageIndex: 0),
            makeDiskImage(filename: "HD11.hda", scsiID: 1, imageIndex: 1)
        ]
        let groups = MultiImageManager.groupImagesBySlot(images)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].slots.count, 2)
        XCTAssertTrue(groups[0].hasMultipleSlots)
    }

    func testGroupImagesBySlotSortedBySCSIID() {
        let images = [
            makeDiskImage(filename: "HD50.hda", scsiID: 5, imageIndex: 0),
            makeDiskImage(filename: "HD20.hda", scsiID: 2, imageIndex: 0),
            makeDiskImage(filename: "HD30.hda", scsiID: 3, imageIndex: 0)
        ]
        let groups = MultiImageManager.groupImagesBySlot(images)
        let ids = groups.map { $0.scsiID }
        XCTAssertEqual(ids, [2, 3, 5], "Groups should be sorted by SCSI ID ascending")
    }

    // MARK: - hasMultiImageSetup

    func testHasMultiImageSetupFalseForSingleSlots() {
        let images = [
            makeDiskImage(filename: "HD10.hda", scsiID: 1, imageIndex: 0),
            makeDiskImage(filename: "HD20.hda", scsiID: 2, imageIndex: 0)
        ]
        XCTAssertFalse(MultiImageManager.hasMultiImageSetup(images))
    }

    func testHasMultiImageSetupTrueForMultiSlot() {
        let images = [
            makeDiskImage(filename: "HD10.hda", scsiID: 1, imageIndex: 0),
            makeDiskImage(filename: "HD11.hda", scsiID: 1, imageIndex: 1)
        ]
        XCTAssertTrue(MultiImageManager.hasMultiImageSetup(images))
    }

    // MARK: - BankExtractor.ExtractedBank struct

    func testExtractedBankFieldAccess() {
        let bank = BankExtractor.ExtractedBank(
            name: "STRINGS",
            data: Data(count: 489472),
            clusterCount: 1
        )
        XCTAssertEqual(bank.name, "STRINGS")
        XCTAssertEqual(bank.data.count, 489472)
        XCTAssertEqual(bank.clusterCount, 1)
    }
}
