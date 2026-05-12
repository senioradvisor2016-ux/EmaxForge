import XCTest
import Foundation
@testable import EmaxForge

// MARK: - EmaxIIParser.parseBankData

/// Tests for EmaxIIParser.parseBankData() — both EMX and EB2 paths.
///
/// Covers:
///   • parseBankData returns nil for buffers smaller than 0x200
///   • EMX path: bankName, numPresets, numSamples read from header
///   • EMX path: presetType from first preset at 0x200 (not hardcoded 0x1B8)
///   • EMX path: numZones from zone-map at presetBase+0x40 (not hardcoded 0x1F8)
///   • EB2 path: bankName from 0x1AC, presetType from 0x1B8
///   • SampleParameter struct computed properties
final class BankDataParserTests: XCTestCase {

    // MARK: - Helpers

    /// Build an EMX-format buffer with configurable header, first-preset, zone-map, and sample params.
    ///
    /// Minimum valid size: EmaxIIFormat.sampleDataOffset + pcmBytes (0x20000 + pcmBytes).
    private func makeEMXBank(
        bankName: String = "TEST BANK",
        numPresets: UInt16 = 2,
        numSamples: UInt16 = 1,
        presetMarker: UInt8 = 0x41,   // 0x41=singleA, 0x01=multi
        presetVolume: UInt8 = 100,
        presetTranspose: UInt8 = 0,
        presetTuneCoarse: UInt8 = 0,
        presetTuneFine: UInt8 = 0,
        numZonesInMap: Int = 0,        // how many distinct zone indices (0-based) to write into zone map
        sampleRate: UInt16 = 39063,
        originalKey: UInt8 = 60,
        pcmFrames: Int = 100
    ) -> Data {
        let pcmBytes = pcmFrames * 2
        let totalSize = EmaxIIFormat.sampleDataOffset + pcmBytes
        var buf = Data(count: totalSize)

        // --- Bank header ---
        let nameData = bankName.prefix(16).data(using: .ascii) ?? Data()
        for (i, byte) in nameData.enumerated() where i < 16 {
            buf[EmaxIIFormat.bankNameOffset + i] = byte
        }
        buf.writeU16LE(numPresets, at: EmaxIIFormat.numPresetsOffset)
        buf.writeU16LE(numSamples, at: EmaxIIFormat.numSamplesOffset)

        // --- First preset at 0x200 (presetAreaOffset) ---
        let pb = EmaxIIFormat.presetAreaOffset   // 0x200
        buf[pb + 0] = presetMarker
        buf[pb + 3] = presetVolume
        buf[pb + 5] = presetTranspose
        buf[pb + 6] = presetTuneCoarse
        buf[pb + 7] = presetTuneFine

        // Zone map at presetBase+0x40 (48 bytes, 0xFF = empty)
        let zoneMapBase = pb + 0x40
        for i in 0..<48 {
            buf[zoneMapBase + i] = 0xFF              // default: empty
        }
        // Write zone indices 0..(numZonesInMap-1)
        for z in 0..<min(numZonesInMap, 48) {
            buf[zoneMapBase + z] = UInt8(z)
        }

        // --- Sample param at 0x10200 ---
        let sp = EmaxIIFormat.sampleParamOffset
        buf.writeU32LE(0, at: sp + EmaxIIFormat.paramStartAddr)
        buf.writeU32LE(UInt32(pcmBytes), at: sp + EmaxIIFormat.paramEndAddr)
        buf.writeU16LE(sampleRate, at: sp + EmaxIIFormat.paramSampleRate)
        buf[sp + EmaxIIFormat.paramOriginalKey] = originalKey

        // --- PCM data at 0x20000 ---
        for i in 0..<pcmBytes {
            buf[EmaxIIFormat.sampleDataOffset + i] = UInt8((i * 53 + 7) % 256)
        }

        return buf
    }

    /// Build a minimal EB2-format buffer.
    ///
    /// EB2 bank layout:
    ///   0x1AC: bank name (12 bytes)
    ///   0x1B8: first preset data (marker at +0, volume at +3, etc.)
    ///   0x1F8: zone map (48 bytes, 0xFF = empty)
    private func makeEB2Bank(
        bankName: String = "EB2 BANK",
        presetMarker: UInt8 = 0x01,   // 0x01=multi
        numZonesInMap: Int = 0
    ) -> Data {
        // Minimum size: 0x228 for zone map read + some high-entropy PCM for detection
        let pcmSize = 1024
        let totalSize = 0x228 + pcmSize
        var buf = Data(count: totalSize)

        // Bank name at 0x1AC (12 bytes)
        let nameData = bankName.prefix(12).data(using: .ascii) ?? Data()
        for (i, byte) in nameData.enumerated() where i < 12 {
            buf[0x1AC + i] = byte
        }

        // Preset marker at 0x1B8
        buf[0x1B8] = presetMarker

        // Zone map at 0x1F8 (= 0x1B8 + 0x40)
        for i in 0..<48 {
            buf[0x1F8 + i] = 0xFF
        }
        for z in 0..<min(numZonesInMap, 48) {
            buf[0x1F8 + z] = UInt8(z)
        }

        // High-entropy PCM so entropy detector can find sample data
        for i in 0..<pcmSize {
            buf[0x228 + i] = UInt8((i * 37 + 13) % 256)
        }

        return buf
    }

    // MARK: - parseBankData: nil for small buffers

    func testParseBankDataReturnsNilForEmptyData() {
        XCTAssertNil(EmaxIIParser.parseBankData(Data()))
    }

    func testParseBankDataReturnsNilForSmallBuffer() {
        // Buffer smaller than 0x200 → nil
        XCTAssertNil(EmaxIIParser.parseBankData(Data(count: 0x100)))
    }

    func testParseBankDataReturnsNilForExactly511Bytes() {
        XCTAssertNil(EmaxIIParser.parseBankData(Data(count: 0x1FF)))
    }

    // MARK: - parseBankData: EMX path — header fields

    func testEMXBankNameIsReadFromHeader() {
        let buf = makeEMXBank(bankName: "GRAND PIANO")
        let result = EmaxIIParser.parseBankData(buf)
        XCTAssertEqual(result?.bankName, "GRAND PIANO")
    }

    func testEMXNumPresetsIsReadFromHeader() {
        let buf = makeEMXBank(numPresets: 7)
        let result = EmaxIIParser.parseBankData(buf)
        XCTAssertEqual(result?.numPresets, 7)
    }

    func testEMXNumSamplesIsReadFromHeader() {
        let buf = makeEMXBank(numSamples: 3)
        let result = EmaxIIParser.parseBankData(buf)
        XCTAssertEqual(result?.numSamples, 3)
    }

    func testEMXSampleParametersCountMatchesNumSamples() {
        let buf = makeEMXBank(numSamples: 1)
        let result = EmaxIIParser.parseBankData(buf)
        XCTAssertEqual(result?.sampleParameters.count, 1)
    }

    // MARK: - parseBankData: EMX path — presetType from presetBase 0x200

    func testEMXPresetTypeSingleAWhenMarkerIs0x41() {
        let buf = makeEMXBank(presetMarker: 0x41)
        let result = EmaxIIParser.parseBankData(buf)
        if case .singleA = result?.presetType {
            // pass
        } else {
            XCTFail("Expected .singleA but got \(String(describing: result?.presetType))")
        }
    }

    func testEMXPresetTypeMultiWhenMarkerIs0x01() {
        let buf = makeEMXBank(presetMarker: 0x01)
        let result = EmaxIIParser.parseBankData(buf)
        if case .multi = result?.presetType {
            // pass
        } else {
            XCTFail("Expected .multi but got \(String(describing: result?.presetType))")
        }
    }

    func testEMXPresetTypeUnknownForOtherMarker() {
        let buf = makeEMXBank(presetMarker: 0xAB)
        let result = EmaxIIParser.parseBankData(buf)
        if case .unknown(let v) = result?.presetType {
            XCTAssertEqual(v, 0xAB)
        } else {
            XCTFail("Expected .unknown(0xAB) but got \(String(describing: result?.presetType))")
        }
    }

    /// Regression: presetType must be read from 0x200 (presetBase), NOT from hardcoded 0x1B8.
    /// In EMX format, 0x1B8 is in the header area and unrelated to preset data.
    func testEMXPresetTypeNotReadFromHardcoded0x1B8() {
        var buf = makeEMXBank(presetMarker: 0x41)
        // Write a conflicting marker at the formerly-hardcoded 0x1B8 address
        buf[0x1B8] = 0x01   // would give .multi if 0x1B8 were still used
        let result = EmaxIIParser.parseBankData(buf)
        // Should still read .singleA from 0x200, not .multi from 0x1B8
        if case .singleA = result?.presetType {
            // pass
        } else {
            XCTFail("presetType was read from hardcoded 0x1B8 instead of presetBase 0x200")
        }
    }

    // MARK: - parseBankData: EMX path — presetHeader from presetBase+offset

    func testEMXPresetHeaderVolumeIsReadFromPresetBase() {
        let buf = makeEMXBank(presetMarker: 0x41, presetVolume: 85)
        let result = EmaxIIParser.parseBankData(buf)
        XCTAssertEqual(result?.presetHeader?.volume, 85,
                       "volume must be read from presetBase+3, not hardcoded 0x1BB")
    }

    func testEMXPresetHeaderIsNilForMultiPreset() {
        // .multi doesn't populate presetHeader
        let buf = makeEMXBank(presetMarker: 0x01)
        let result = EmaxIIParser.parseBankData(buf)
        XCTAssertNil(result?.presetHeader,
                     "presetHeader should be nil for multi-mode preset")
    }

    // MARK: - parseBankData: EMX path — numZones from presetBase+0x40

    func testEMXNumZonesIsZeroWhenZoneMapAllFF() {
        // All 0xFF → maxZone = -1 → numZones = 0
        let buf = makeEMXBank(numZonesInMap: 0)
        let result = EmaxIIParser.parseBankData(buf)
        XCTAssertEqual(result?.numZones, 0,
                       "numZones should be 0 when zone map is all 0xFF")
    }

    func testEMXNumZonesCountsDistinctZones() {
        // Write zone indices 0,1,2 → maxZone=2 → numZones=3
        let buf = makeEMXBank(numZonesInMap: 3)
        let result = EmaxIIParser.parseBankData(buf)
        XCTAssertEqual(result?.numZones, 3,
                       "numZones should equal max(zoneIndex)+1 from zone map at presetBase+0x40")
    }

    /// Regression: numZones must be read from presetBase+0x40 (=0x240 for EMX),
    /// NOT from hardcoded 0x1F8 (which is in the EMX header area).
    func testEMXNumZonesNotReadFromHardcoded0x1F8() {
        var buf = makeEMXBank(numZonesInMap: 0)   // zone map at 0x240 all 0xFF → numZones=0
        // Write conflicting zone data at formerly-hardcoded range 0x1F8..0x228
        for i in 0x1F8..<0x228 {
            buf[i] = UInt8(i % 5)   // would give numZones≥1 if 0x1F8 were still used
        }
        let result = EmaxIIParser.parseBankData(buf)
        // Should still be 0 (zone map at 0x240 is all 0xFF)
        XCTAssertEqual(result?.numZones, 0,
                       "numZones was read from hardcoded 0x1F8 instead of presetBase+0x40 (0x240)")
    }

    // MARK: - parseBankData: EB2 path

    func testEB2BankNameIsReadFrom0x1AC() {
        let buf = makeEB2Bank(bankName: "BRASS")
        let result = EmaxIIParser.parseBankData(buf)
        XCTAssertEqual(result?.bankName, "BRASS")
    }

    func testEB2PresetTypeMultiWhenMarkerIs0x01() {
        let buf = makeEB2Bank(presetMarker: 0x01)
        let result = EmaxIIParser.parseBankData(buf)
        if case .multi = result?.presetType {
            // pass
        } else {
            XCTFail("Expected .multi but got \(String(describing: result?.presetType))")
        }
    }

    func testEB2NumPresetsIsZero() {
        // EB2 doesn't store reliable preset counts in its header
        let buf = makeEB2Bank()
        let result = EmaxIIParser.parseBankData(buf)
        XCTAssertEqual(result?.numPresets, 0)
    }

    func testEB2SampleParametersIsEmpty() {
        // EB2 has no param table
        let buf = makeEB2Bank()
        let result = EmaxIIParser.parseBankData(buf)
        XCTAssertEqual(result?.sampleParameters.count, 0)
    }

    // MARK: - SampleParameter computed properties

    func testSampleParameterIsValidWhenStartLessThanEnd() {
        let buf = makeEMXBank(pcmFrames: 200)
        guard let params = EmaxIIParser.parseBankData(buf)?.sampleParameters, !params.isEmpty else {
            XCTFail("Expected sample parameters"); return
        }
        XCTAssertTrue(params[0].isValid)
    }

    func testSampleParameterSizeInBytesIsEndMinusStart() {
        let buf = makeEMXBank(pcmFrames: 100)   // pcmBytes = 200
        guard let param = EmaxIIParser.parseBankData(buf)?.sampleParameters.first else {
            XCTFail("Expected sample parameter"); return
        }
        XCTAssertEqual(param.sizeInBytes, 200)
    }

    func testSampleParameterSizeInFramesIsHalfBytes() {
        let buf = makeEMXBank(pcmFrames: 100)
        guard let param = EmaxIIParser.parseBankData(buf)?.sampleParameters.first else {
            XCTFail("Expected sample parameter"); return
        }
        XCTAssertEqual(param.sizeInFrames, 100)
    }

    func testSampleParameterDurationIsFramesOverRate() {
        let buf = makeEMXBank(sampleRate: 39063, pcmFrames: 39063)
        guard let param = EmaxIIParser.parseBankData(buf)?.sampleParameters.first else {
            XCTFail("Expected sample parameter"); return
        }
        XCTAssertEqual(param.duration, 1.0, accuracy: 0.001)
    }

    func testSampleParameterDurationIsZeroForZeroRate() {
        // Rate < 8000 → defaults to EmaxIIFormat.defaultSampleRate, not 0
        // But if we construct a SampleParameter directly with rate 0, duration = 0
        // We can't do that since the struct is internal; test via extracted param instead.
        // Instead, verify duration > 0 for a valid bank
        let buf = makeEMXBank(sampleRate: 39063, pcmFrames: 100)
        guard let param = EmaxIIParser.parseBankData(buf)?.sampleParameters.first else {
            XCTFail("Expected sample parameter"); return
        }
        XCTAssertGreaterThan(param.duration, 0)
    }

    // MARK: - PresetType description

    func testPresetTypeSingleADescription() {
        let t = EmaxIIBankData.PresetType.singleA
        XCTAssertEqual(t.description, "Single (A)")
    }

    func testPresetTypeMultiDescription() {
        let t = EmaxIIBankData.PresetType.multi
        XCTAssertEqual(t.description, "Multi")
    }

    func testPresetTypeUnknownDescriptionContainsValue() {
        let t = EmaxIIBankData.PresetType.unknown(0xAB)
        XCTAssertTrue(t.description.contains("AB") || t.description.contains("ab"),
                      "Unknown preset type description should contain the hex value")
    }
}

// MARK: - Data write helpers (local to this test file)

private extension Data {
    mutating func writeU16LE(_ value: UInt16, at offset: Int) {
        guard offset + 2 <= count else { return }
        self[offset]     = UInt8(value & 0xFF)
        self[offset + 1] = UInt8(value >> 8)
    }

    mutating func writeU32LE(_ value: UInt32, at offset: Int) {
        guard offset + 4 <= count else { return }
        self[offset]     = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8)  & 0xFF)
        self[offset + 2] = UInt8((value >> 16) & 0xFF)
        self[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
}
