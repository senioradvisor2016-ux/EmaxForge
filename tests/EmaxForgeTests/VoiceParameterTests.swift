import XCTest
import Foundation
@testable import EmaxForge

// MARK: - VoiceParameters

/// Tests for VoiceParameters — pure struct: default init, toData/init(from:) round-trip,
/// normalized computed properties, panLabel, and filterCutoffHz.
final class VoiceParameterTests: XCTestCase {

    // MARK: - Default init

    func testDefaultAttenuationIsZero() {
        XCTAssertEqual(VoiceParameters().attenuation, 0x0000)
    }

    func testDefaultTuneIsCentre() {
        XCTAssertEqual(VoiceParameters().tune, 0x4000)
    }

    func testDefaultPanIsCentre() {
        XCTAssertEqual(VoiceParameters().pan, 0x4000)
    }

    func testDefaultFilterCutoffIsWideOpen() {
        XCTAssertEqual(VoiceParameters().filterCutoff, 0x7F00)
    }

    func testDefaultFilterQIsZero() {
        XCTAssertEqual(VoiceParameters().filterQ, 0x0000)
    }

    func testDefaultVCASustainIsMax() {
        XCTAssertEqual(VoiceParameters().vcaSustain, 0xFF00)
    }

    // MARK: - toData() size

    func testToDataReturns32Bytes() {
        XCTAssertEqual(VoiceParameters().toData().count, 32)
    }

    // MARK: - Binary round-trip

    func testRoundTripPreservesAttenuation() {
        var vp = VoiceParameters()
        vp.attenuation = 0x1234
        let data = vp.toData()
        let decoded = VoiceParameters(from: data, offset: 0)
        XCTAssertEqual(decoded.attenuation, 0x1234)
    }

    func testRoundTripPreservesTune() {
        var vp = VoiceParameters()
        vp.tune = 0x5678
        let data = vp.toData()
        let decoded = VoiceParameters(from: data, offset: 0)
        XCTAssertEqual(decoded.tune, 0x5678)
    }

    func testRoundTripPreservesPan() {
        var vp = VoiceParameters()
        vp.pan = 0x0001   // Hard left
        let data = vp.toData()
        let decoded = VoiceParameters(from: data, offset: 0)
        XCTAssertEqual(decoded.pan, 0x0001)
    }

    func testRoundTripPreservesFilterCutoff() {
        var vp = VoiceParameters()
        vp.filterCutoff = 0x2000
        let data = vp.toData()
        let decoded = VoiceParameters(from: data, offset: 0)
        XCTAssertEqual(decoded.filterCutoff, 0x2000)
    }

    func testRoundTripPreservesAllFields() {
        var vp = VoiceParameters()
        vp.attenuation = 0x1000
        vp.tune        = 0x2000
        vp.delay       = 0x3000
        vp.vcaAttack   = 0x0200
        vp.chorus      = 0x0050
        let data = vp.toData()
        let rt = VoiceParameters(from: data)
        XCTAssertEqual(rt.attenuation, 0x1000)
        XCTAssertEqual(rt.tune,        0x2000)
        XCTAssertEqual(rt.delay,       0x3000)
        XCTAssertEqual(rt.vcaAttack,   0x0200)
        XCTAssertEqual(rt.chorus,      0x0050)
    }

    func testInitFromTooSmallDataFallsBackToDefaults() {
        // Data shorter than 32 bytes → uses default values
        let vp = VoiceParameters(from: Data(count: 10), offset: 0)
        XCTAssertEqual(vp.tune, 0x4000, "Fallback default: tune=0x4000")
        XCTAssertEqual(vp.pan, 0x4000, "Fallback default: pan=0x4000")
    }

    func testInitFromDataWithNonZeroOffset() {
        // Write a vp at offset 16 in a 48-byte buffer
        var vp = VoiceParameters()
        vp.attenuation = 0xABCD
        let vpData = vp.toData()
        var buffer = Data(count: 48)
        buffer.replaceSubrange(16..<48, with: vpData)
        let decoded = VoiceParameters(from: buffer, offset: 16)
        XCTAssertEqual(decoded.attenuation, 0xABCD)
    }

    // MARK: - Normalized computed properties

    func testAttenuationNormZeroIsZero() {
        var vp = VoiceParameters()
        vp.attenuation = 0
        XCTAssertEqual(vp.attenuationNorm, 0.0, accuracy: 0.0001)
    }

    func testAttenuationNormMaxIsApprox1() {
        var vp = VoiceParameters()
        vp.attenuation = 0xFFFF
        XCTAssertEqual(vp.attenuationNorm, 1.0, accuracy: 0.001)
    }

    func testPanNormCentreIsApprox025() {
        // Default pan = 0x4000 = 16384; 16384/65535 ≈ 0.25
        let vp = VoiceParameters()
        XCTAssertEqual(vp.panNorm, Double(0x4000) / 65535.0, accuracy: 0.001)
    }

    func testFilterCutoffNormMaxIsApprox1() {
        var vp = VoiceParameters()
        vp.filterCutoff = 0xFFFF
        XCTAssertEqual(vp.filterCutoffNorm, 1.0, accuracy: 0.001)
    }

    // MARK: - panLabel

    func testPanLabelLeftForLowPan() {
        var vp = VoiceParameters()
        vp.pan = 0x0000
        XCTAssertEqual(vp.panLabel, "L")
    }

    func testPanLabelCentreForDefaultPan() {
        // pan = 0x4000 (default): not < 0x2000, not > 0x6000 → "C"
        let vp = VoiceParameters()
        XCTAssertEqual(vp.panLabel, "C")
    }

    func testPanLabelRightForHighPan() {
        var vp = VoiceParameters()
        vp.pan = 0x7FFF
        XCTAssertEqual(vp.panLabel, "R")
    }

    func testPanLabelBoundaryLeft() {
        // pan = 0x1FFF < 0x2000 → "L"
        var vp = VoiceParameters()
        vp.pan = 0x1FFF
        XCTAssertEqual(vp.panLabel, "L")
    }

    func testPanLabelBoundaryRight() {
        // pan = 0x6001 > 0x6000 → "R"
        var vp = VoiceParameters()
        vp.pan = 0x6001
        XCTAssertEqual(vp.panLabel, "R")
    }

    // MARK: - filterCutoffHz

    func testFilterCutoffHzAtZeroIsMinimum() {
        var vp = VoiceParameters()
        vp.filterCutoff = 0x0000
        // normalized = 0.0 → Hz = 20 + 19980 * 0 = 20
        XCTAssertEqual(vp.filterCutoffHz, 20)
    }

    func testFilterCutoffHzAtMaxIsApproxMaximum() {
        var vp = VoiceParameters()
        vp.filterCutoff = 0xFFFF
        // normalized ≈ 1.0 → Hz ≈ 20 + 19980 = 20000
        XCTAssertEqual(vp.filterCutoffHz, 20000)
    }

    func testFilterCutoffHzIsBetweenMinAndMax() {
        let vp = VoiceParameters()  // default filterCutoff = 0x7F00
        XCTAssertGreaterThan(vp.filterCutoffHz, 20)
        XCTAssertLessThan(vp.filterCutoffHz, 20000)
    }
}

// MARK: - PresetInfo

/// Tests for PresetInfo struct and computed properties.
final class PresetInfoTests: XCTestCase {

    private func makePreset(
        name: String = "INIT PRESET",
        bankName: String = "STRINGS",
        presetIndex: Int = 0,
        voiceCount: Int = 4,
        samples: [String] = ["SAM1", "SAM2"],
        keyRangeLow: Int = 60,
        keyRangeHigh: Int = 72,
        velocityLayers: Int = 1
    ) -> PresetInfo {
        PresetInfo(
            name: name, bankName: bankName, presetIndex: presetIndex,
            voiceCount: voiceCount, samples: samples,
            keyRangeLow: keyRangeLow, keyRangeHigh: keyRangeHigh,
            velocityLayers: velocityLayers
        )
    }

    // MARK: - Basic field access

    func testPresetInfoFieldAccess() {
        let p = makePreset(name: "PIANO", bankName: "GRAND", presetIndex: 3,
                           voiceCount: 8, samples: ["S1", "S2", "S3"])
        XCTAssertEqual(p.name, "PIANO")
        XCTAssertEqual(p.bankName, "GRAND")
        XCTAssertEqual(p.presetIndex, 3)
        XCTAssertEqual(p.voiceCount, 8)
        XCTAssertEqual(p.velocityLayers, 1)
    }

    // MARK: - sampleCount

    func testSampleCountMatchesSamplesArray() {
        let p = makePreset(samples: ["A", "B", "C"])
        XCTAssertEqual(p.sampleCount, 3)
    }

    func testSampleCountZeroForNoSamples() {
        let p = makePreset(samples: [])
        XCTAssertEqual(p.sampleCount, 0)
    }

    // MARK: - voiceDescription

    func testVoiceDescriptionSingular() {
        let p = makePreset(voiceCount: 1)
        XCTAssertEqual(p.voiceDescription, "1 voice")
    }

    func testVoiceDescriptionPlural() {
        let p = makePreset(voiceCount: 4)
        XCTAssertEqual(p.voiceDescription, "4 voices")
    }

    func testVoiceDescriptionZero() {
        let p = makePreset(voiceCount: 0)
        XCTAssertEqual(p.voiceDescription, "0 voices")
    }

    // MARK: - keyRangeDescription (calls midiNoteName)

    func testKeyRangeDescriptionC4toC5() {
        // MIDI 60 = C4, 72 = C5
        let p = makePreset(keyRangeLow: 60, keyRangeHigh: 72)
        XCTAssertEqual(p.keyRangeDescription, "C4 - C5")
    }

    func testKeyRangeDescriptionA4() {
        // MIDI 69 = A4
        let p = makePreset(keyRangeLow: 69, keyRangeHigh: 69)
        XCTAssertEqual(p.keyRangeDescription, "A4 - A4")
    }

    func testKeyRangeDescriptionA0() {
        // MIDI 21 = A0 (lowest piano key)
        let p = makePreset(keyRangeLow: 21, keyRangeHigh: 21)
        XCTAssertEqual(p.keyRangeDescription, "A0 - A0")
    }

    // MARK: - PresetAnalyzer.AnalysisResult

    func testAnalysisResultFieldAccess() {
        let r = PresetAnalyzer.AnalysisResult(
            presets: [],
            totalPresets: 24,
            totalVoices: 96,
            averageVoicesPerPreset: 4.0
        )
        XCTAssertEqual(r.totalPresets, 24)
        XCTAssertEqual(r.totalVoices, 96)
        XCTAssertEqual(r.averageVoicesPerPreset, 4.0, accuracy: 0.001)
    }

    func testAnalysisResultFormattedStats() {
        let r = PresetAnalyzer.AnalysisResult(
            presets: [], totalPresets: 10, totalVoices: 40, averageVoicesPerPreset: 4.0
        )
        XCTAssertTrue(r.formattedStats.contains("10 presets"))
        XCTAssertTrue(r.formattedStats.contains("40 voices"))
        XCTAssertTrue(r.formattedStats.contains("4.0"))
    }
}
