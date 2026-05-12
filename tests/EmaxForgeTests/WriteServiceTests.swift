import XCTest
import Foundation
@testable import EmaxForge

// MARK: - PresetWriteService

/// Tests for PresetWriteService — error descriptions and index guard
/// (fires before any disk I/O so fakeURL + fakeBankEntry is sufficient).
final class PresetWriteServiceTests: XCTestCase {

    private func fakeBankEntry() -> BankCatalogEntry {
        BankCatalogEntry(
            catalogIndex: 0, name: "FAKE", bankIndex: 0,
            startCluster: 2, numPresets: 1,
            fieldA: 0, fieldB: 0, flags: 0x81,
            clusterChain: [2], sizeBytes: 489472
        )
    }

    private var fakeURL: URL { URL(fileURLWithPath: "/dev/null/fake.hda") }

    // MARK: - Error descriptions

    func testPresetIndexOutOfRangeDescriptionContainsIndex() {
        let err = PresetWriteService.PresetWriteError.presetIndexOutOfRange(300)
        XCTAssertTrue(err.errorDescription?.contains("300") == true)
    }

    func testPresetIndexOutOfRangeDescriptionMentionsRange() {
        let err = PresetWriteService.PresetWriteError.presetIndexOutOfRange(-1)
        XCTAssertTrue(err.errorDescription?.contains("255") == true,
                      "Description should mention the 0–255 range")
    }

    func testBankDataTooSmallDescriptionContainsSize() {
        let err = PresetWriteService.PresetWriteError.bankDataTooSmall(1024)
        XCTAssertTrue(err.errorDescription?.contains("1024") == true)
    }

    func testInvalidKeyMapDescriptionContainsSize() {
        let err = PresetWriteService.PresetWriteError.invalidKeyMap(64)
        XCTAssertTrue(err.errorDescription?.contains("64") == true)
        XCTAssertTrue(err.errorDescription?.contains("88") == true,
                      "Should mention the required 88-byte size")
    }

    func testInvalidVoiceRecordSizeDescriptionContainsIndexAndSize() {
        let err = PresetWriteService.PresetWriteError.invalidVoiceRecordSize(index: 2, size: 16)
        XCTAssertTrue(err.errorDescription?.contains("2") == true)
        XCTAssertTrue(err.errorDescription?.contains("16") == true)
    }

    func testTooManyZonesDescriptionContainsCount() {
        let err = PresetWriteService.PresetWriteError.tooManyZones(100)
        XCTAssertTrue(err.errorDescription?.contains("100") == true)
    }

    func testNameTooLongDescriptionContainsName() {
        let err = PresetWriteService.PresetWriteError.nameTooLong("VERYLONGNAME123")
        XCTAssertTrue(err.errorDescription?.contains("VERYLONGNAME123") == true)
    }

    func testUnderlyingErrorDescriptionForwards() {
        struct MockError: LocalizedError {
            var errorDescription: String? { "underlying failure" }
        }
        let err = PresetWriteService.PresetWriteError.underlyingError(MockError())
        XCTAssertTrue(err.errorDescription?.contains("underlying failure") == true)
    }

    func testAllPresetWriteErrorsHaveNonEmptyDescriptions() {
        struct MockError: LocalizedError {
            var errorDescription: String? { "e" }
        }
        let errors: [PresetWriteService.PresetWriteError] = [
            .presetIndexOutOfRange(0), .bankDataTooSmall(0), .invalidKeyMap(0),
            .invalidVoiceRecordSize(index: 0, size: 0), .tooManyZones(0),
            .nameTooLong("x"), .underlyingError(MockError())
        ]
        for err in errors {
            XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
        }
    }

    // MARK: - PresetUpdate struct

    func testPresetUpdateDefaultAllNil() {
        let u = PresetWriteService.PresetUpdate()
        XCTAssertNil(u.name)
        XCTAssertNil(u.voiceRecords)
        XCTAssertNil(u.keyMap)
    }

    func testPresetUpdateFieldAccess() {
        var u = PresetWriteService.PresetUpdate()
        u.name = "STRINGS"
        u.keyMap = Data(count: 88)
        XCTAssertEqual(u.name, "STRINGS")
        XCTAssertEqual(u.keyMap?.count, 88)
    }

    // MARK: - updatePreset: index guard (fires before disk I/O)

    func testUpdatePresetThrowsForNegativeIndex() {
        XCTAssertThrowsError(
            try PresetWriteService.updatePreset(
                at: -1, update: PresetWriteService.PresetUpdate(),
                in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if case .presetIndexOutOfRange(let i) = err as! PresetWriteService.PresetWriteError {
                XCTAssertEqual(i, -1)
            } else {
                XCTFail("Expected presetIndexOutOfRange(-1)")
            }
        }
    }

    func testUpdatePresetThrowsFor256() {
        XCTAssertThrowsError(
            try PresetWriteService.updatePreset(
                at: 256, update: PresetWriteService.PresetUpdate(),
                in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if case .presetIndexOutOfRange(_) = err as! PresetWriteService.PresetWriteError { } else {
                XCTFail("Expected presetIndexOutOfRange(256)")
            }
        }
    }

    func testUpdatePresetPassesGuardForIndex0() {
        // Index 0 passes guard → fails on disk I/O (not presetIndexOutOfRange)
        XCTAssertThrowsError(
            try PresetWriteService.updatePreset(
                at: 0, update: PresetWriteService.PresetUpdate(),
                in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if let writeErr = err as? PresetWriteService.PresetWriteError,
               case .presetIndexOutOfRange(_) = writeErr {
                XCTFail("Index 0 should pass the guard")
            }
            // Any other error type means the guard passed
        }
    }

    func testUpdatePresetPassesGuardFor255() {
        XCTAssertThrowsError(
            try PresetWriteService.updatePreset(
                at: 255, update: PresetWriteService.PresetUpdate(),
                in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if let writeErr = err as? PresetWriteService.PresetWriteError,
               case .presetIndexOutOfRange(_) = writeErr {
                XCTFail("Index 255 should pass the guard")
            }
        }
    }
}

// MARK: - SampleParamWriteService

/// Tests for SampleParamWriteService — error descriptions, SampleParamUpdate struct,
/// and index guard.
final class SampleParamWriteServiceTests: XCTestCase {

    private func fakeBankEntry() -> BankCatalogEntry {
        BankCatalogEntry(
            catalogIndex: 0, name: "FAKE", bankIndex: 0,
            startCluster: 2, numPresets: 1,
            fieldA: 0, fieldB: 0, flags: 0x81,
            clusterChain: [2], sizeBytes: 489472
        )
    }

    private var fakeURL: URL { URL(fileURLWithPath: "/dev/null/fake.hda") }

    // MARK: - Error descriptions

    func testSampleIndexOutOfRangeDescriptionContainsIndex() {
        let err = SampleParamWriteService.SampleWriteError.sampleIndexOutOfRange(1000)
        XCTAssertTrue(err.errorDescription?.contains("1000") == true)
    }

    func testSampleIndexOutOfRangeDescriptionMentionsRange() {
        let err = SampleParamWriteService.SampleWriteError.sampleIndexOutOfRange(-5)
        XCTAssertTrue(err.errorDescription?.contains("998") == true ||
                      err.errorDescription?.contains("0") == true)
    }

    func testBankDataTooSmallDescriptionContainsSize() {
        let err = SampleParamWriteService.SampleWriteError.bankDataTooSmall(512)
        XCTAssertTrue(err.errorDescription?.contains("512") == true)
    }

    func testNameTooLongDescriptionContainsName() {
        let err = SampleParamWriteService.SampleWriteError.nameTooLong("VERYLONGSAMPLENAME")
        XCTAssertTrue(err.errorDescription?.contains("VERYLONGSAMPLENAME") == true)
    }

    func testUnderlyingErrorDescriptionForwards() {
        struct MockError: LocalizedError {
            var errorDescription: String? { "read failure" }
        }
        let err = SampleParamWriteService.SampleWriteError.underlyingError(MockError())
        XCTAssertTrue(err.errorDescription?.contains("read failure") == true)
    }

    func testAllSampleWriteErrorsHaveNonEmptyDescriptions() {
        struct MockError: LocalizedError {
            var errorDescription: String? { "e" }
        }
        let errors: [SampleParamWriteService.SampleWriteError] = [
            .sampleIndexOutOfRange(0), .bankDataTooSmall(0),
            .nameTooLong("x"), .underlyingError(MockError())
        ]
        for err in errors {
            XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
        }
    }

    // MARK: - SampleParamUpdate struct

    func testSampleParamUpdateDefaultAllNil() {
        let u = SampleParamWriteService.SampleParamUpdate()
        XCTAssertNil(u.startAddress)
        XCTAssertNil(u.endAddress)
        XCTAssertNil(u.sampleRate)
        XCTAssertNil(u.name)
    }

    func testSampleParamUpdateFieldAccess() {
        var u = SampleParamWriteService.SampleParamUpdate()
        u.startAddress = 0
        u.endAddress = 44100
        u.sampleRate = 22050
        u.name = "KICK_01"
        XCTAssertEqual(u.startAddress, 0)
        XCTAssertEqual(u.endAddress, 44100)
        XCTAssertEqual(u.sampleRate, 22050)
        XCTAssertEqual(u.name, "KICK_01")
    }

    // MARK: - updateSampleParam: index guard (fires before disk I/O)

    func testUpdateSampleParamThrowsForNegativeIndex() {
        XCTAssertThrowsError(
            try SampleParamWriteService.updateSampleParam(
                at: -1, update: SampleParamWriteService.SampleParamUpdate(),
                in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if case .sampleIndexOutOfRange(let i) = err as! SampleParamWriteService.SampleWriteError {
                XCTAssertEqual(i, -1)
            } else {
                XCTFail("Expected sampleIndexOutOfRange(-1)")
            }
        }
    }

    func testUpdateSampleParamPassesGuardForIndex0() {
        XCTAssertThrowsError(
            try SampleParamWriteService.updateSampleParam(
                at: 0, update: SampleParamWriteService.SampleParamUpdate(),
                in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if let writeErr = err as? SampleParamWriteService.SampleWriteError,
               case .sampleIndexOutOfRange(_) = writeErr {
                XCTFail("Index 0 should pass the guard")
            }
        }
    }
}

// MARK: - VoiceZoneEditor

/// Tests for VoiceZoneEditor — error descriptions, struct access, and guards
/// (presetIndex, midiKey bounds, invalidKeyRange all fire before disk I/O).
final class VoiceZoneEditorTests: XCTestCase {

    private func fakeBankEntry() -> BankCatalogEntry {
        BankCatalogEntry(
            catalogIndex: 0, name: "FAKE", bankIndex: 0,
            startCluster: 2, numPresets: 1,
            fieldA: 0, fieldB: 0, flags: 0x81,
            clusterChain: [2], sizeBytes: 489472
        )
    }

    private var fakeURL: URL { URL(fileURLWithPath: "/dev/null/fake.hda") }

    // MARK: - EditError descriptions

    func testInvalidMidiKeyDescriptionContainsKey() {
        let err = VoiceZoneEditor.EditError.invalidMidiKey(10)
        XCTAssertTrue(err.errorDescription?.contains("10") == true)
    }

    func testInvalidKeyRangeDescriptionContainsBothKeys() {
        let err = VoiceZoneEditor.EditError.invalidKeyRange(low: 80, high: 60)
        XCTAssertTrue(err.errorDescription?.contains("80") == true)
        XCTAssertTrue(err.errorDescription?.contains("60") == true)
    }

    func testPresetIndexOutOfRangeDescriptionContainsIndex() {
        let err = VoiceZoneEditor.EditError.presetIndexOutOfRange(300)
        XCTAssertTrue(err.errorDescription?.contains("300") == true)
    }

    func testBankReadErrorDescriptionContainsMessage() {
        let err = VoiceZoneEditor.EditError.bankReadError("seek failed")
        XCTAssertTrue(err.errorDescription?.contains("seek failed") == true)
    }

    func testBankWriteErrorDescriptionContainsMessage() {
        let err = VoiceZoneEditor.EditError.bankWriteError("disk full")
        XCTAssertTrue(err.errorDescription?.contains("disk full") == true)
    }

    func testInvalidVoiceRecordDescriptionContainsMessage() {
        let err = VoiceZoneEditor.EditError.invalidVoiceRecord("bad length")
        XCTAssertTrue(err.errorDescription?.contains("bad length") == true)
    }

    func testAllVoiceZoneEditErrorsHaveNonEmptyDescriptions() {
        let errors: [VoiceZoneEditor.EditError] = [
            .invalidMidiKey(0), .invalidKeyRange(low: 30, high: 20),
            .presetIndexOutOfRange(0), .bankReadError("x"),
            .bankWriteError("x"), .invalidVoiceRecord("x")
        ]
        for err in errors {
            XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
        }
    }

    // MARK: - ZoneDescriptor struct

    func testZoneDescriptorFieldAccess() {
        var z = VoiceZoneEditor.ZoneDescriptor(voiceGroup: 2, velocityLow: 0, velocityHigh: 127)
        XCTAssertEqual(z.voiceGroup, 2)
        XCTAssertEqual(z.velocityLow, 0)
        XCTAssertEqual(z.velocityHigh, 127)
        z.voiceGroup = 5
        XCTAssertEqual(z.voiceGroup, 5)
    }

    // MARK: - assignSampleToKeyRange: guards (fire before disk I/O)

    func testAssignThrowsForPresetIndexNegative() {
        XCTAssertThrowsError(
            try VoiceZoneEditor.assignSampleToKeyRange(
                presetIndex: -1, midiKeyLow: 60, midiKeyHigh: 72,
                sampleIndex: 0, in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if case .presetIndexOutOfRange(_) = err as! VoiceZoneEditor.EditError { } else {
                XCTFail("Expected presetIndexOutOfRange for -1")
            }
        }
    }

    func testAssignThrowsForPresetIndex256() {
        XCTAssertThrowsError(
            try VoiceZoneEditor.assignSampleToKeyRange(
                presetIndex: 256, midiKeyLow: 60, midiKeyHigh: 72,
                sampleIndex: 0, in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if case .presetIndexOutOfRange(_) = err as! VoiceZoneEditor.EditError { } else {
                XCTFail("Expected presetIndexOutOfRange(256)")
            }
        }
    }

    func testAssignThrowsForMidiKeyLowBelow21() {
        XCTAssertThrowsError(
            try VoiceZoneEditor.assignSampleToKeyRange(
                presetIndex: 0, midiKeyLow: 10, midiKeyHigh: 72,
                sampleIndex: 0, in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if case .invalidMidiKey(let k) = err as! VoiceZoneEditor.EditError {
                XCTAssertEqual(k, 10)
            } else {
                XCTFail("Expected invalidMidiKey(10)")
            }
        }
    }

    func testAssignThrowsForMidiKeyHighAbove108() {
        XCTAssertThrowsError(
            try VoiceZoneEditor.assignSampleToKeyRange(
                presetIndex: 0, midiKeyLow: 60, midiKeyHigh: 120,
                sampleIndex: 0, in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if case .invalidMidiKey(let k) = err as! VoiceZoneEditor.EditError {
                XCTAssertEqual(k, 120)
            } else {
                XCTFail("Expected invalidMidiKey(120)")
            }
        }
    }

    func testAssignThrowsForInvertedKeyRange() {
        XCTAssertThrowsError(
            try VoiceZoneEditor.assignSampleToKeyRange(
                presetIndex: 0, midiKeyLow: 72, midiKeyHigh: 60,
                sampleIndex: 0, in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if case .invalidKeyRange(let lo, let hi) = err as! VoiceZoneEditor.EditError {
                XCTAssertEqual(lo, 72)
                XCTAssertEqual(hi, 60)
            } else {
                XCTFail("Expected invalidKeyRange(72, 60)")
            }
        }
    }

    func testAssignPassesAllGuardsForValidInput() {
        // presetIndex=0, keys 60-72 (valid range) → passes all guards → fails on disk I/O
        XCTAssertThrowsError(
            try VoiceZoneEditor.assignSampleToKeyRange(
                presetIndex: 0, midiKeyLow: 60, midiKeyHigh: 72,
                sampleIndex: 0, in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if let vzErr = err as? VoiceZoneEditor.EditError {
                if case .presetIndexOutOfRange(_) = vzErr {
                    XCTFail("Should not throw presetIndexOutOfRange for valid input")
                }
                if case .invalidMidiKey(_) = vzErr {
                    XCTFail("Should not throw invalidMidiKey for valid input")
                }
                if case .invalidKeyRange(_, _) = vzErr {
                    XCTFail("Should not throw invalidKeyRange for valid input")
                }
            }
            // bankReadError or other disk-I/O error is expected
        }
    }

    // MARK: - EditResult struct

    func testEditResultFieldAccess() {
        let r = VoiceZoneEditor.EditResult(
            presetIndex: 3,
            zoneCount: 4,
            keyMapBytesWritten: 13
        )
        XCTAssertEqual(r.presetIndex, 3)
        XCTAssertEqual(r.zoneCount, 4)
        XCTAssertEqual(r.keyMapBytesWritten, 13)
    }
}
