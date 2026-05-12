import XCTest
import Foundation
@testable import EmaxForge

/// Tests for error descriptions and pure struct logic in services that otherwise
/// require Wine, subprocess CLIs, or real disk files.
///
/// Covered: EB2Converter, AudioConversionService, SampleTrimmerService,
///          SoundFontConverter, BankTemplateService, ImageValidator.
final class MiscServiceTests: XCTestCase {

    // MARK: - EB2Converter.ConversionError descriptions

    func testEB2ConversionErrorStandardNotFoundDescription() {
        let err = EB2Converter.ConversionError.standardNotFound
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
        XCTAssertTrue(err.errorDescription?.contains("standard") == true)
    }

    func testEB2ConversionErrorWineNotFoundDescription() {
        let err = EB2Converter.ConversionError.wineNotFound
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
        XCTAssertTrue(err.errorDescription?.lowercased().contains("wine") == true ||
                      err.errorDescription?.lowercased().contains("whisky") == true)
    }

    func testEB2ConversionErrorConversionFailedDescriptionContainsMessage() {
        let err = EB2Converter.ConversionError.conversionFailed("disk full")
        XCTAssertTrue(err.errorDescription?.contains("disk full") == true)
    }

    func testEB2ConversionErrorExtractionFailedDescription() {
        let err = EB2Converter.ConversionError.extractionFailed
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testAllEB2ConversionErrorsHaveNonEmptyDescriptions() {
        let errors: [EB2Converter.ConversionError] = [
            .standardNotFound, .wineNotFound, .conversionFailed("x"), .extractionFailed
        ]
        for err in errors {
            XCTAssertFalse(err.errorDescription?.isEmpty ?? true,
                           "Error \(err) has empty description")
        }
    }

    // MARK: - AudioConversionService.ConversionError descriptions

    func testAudioConversionErrorConversionFailedContainsMessage() {
        let err = AudioConversionService.ConversionError.conversionFailed("timeout")
        XCTAssertTrue(err.errorDescription?.contains("timeout") == true)
    }

    func testAudioConversionErrorInvalidInputDescription() {
        let err = AudioConversionService.ConversionError.invalidInput
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testAudioConversionErrorCLINotFoundDescription() {
        let err = AudioConversionService.ConversionError.cliNotFound
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    // MARK: - AudioConversionService.ConversionOptions defaults

    func testAudioConversionOptionsDefaultTargetRate() {
        let opts = AudioConversionService.ConversionOptions()
        XCTAssertEqual(opts.targetRate, 42000,
                       "Default target rate should be 42000 (EMAX II standard)")
    }

    func testAudioConversionOptionsDefaultConvertToMono() {
        let opts = AudioConversionService.ConversionOptions()
        XCTAssertTrue(opts.convertToMono)
    }

    func testAudioConversionOptionsDefaultNormalize() {
        let opts = AudioConversionService.ConversionOptions()
        XCTAssertTrue(opts.normalize)
    }

    func testAudioConversionOptionsEmaxStandardPreset() {
        let opts = AudioConversionService.ConversionOptions.emaxStandard
        XCTAssertEqual(opts.targetRate, 42000)
        XCTAssertTrue(opts.convertToMono)
        XCTAssertTrue(opts.normalize)
    }

    // MARK: - AudioConversionService.ConversionResult struct

    func testAudioConversionResultFieldAccess() {
        let r = AudioConversionService.ConversionResult(
            inputPath: "/tmp/in.wav",
            outputPath: "/tmp/out.raw",
            inputRate: 44100,
            outputRate: 42000,
            channels: 1,
            frames: 88200
        )
        XCTAssertEqual(r.inputPath, "/tmp/in.wav")
        XCTAssertEqual(r.outputPath, "/tmp/out.raw")
        XCTAssertEqual(r.inputRate, 44100)
        XCTAssertEqual(r.outputRate, 42000)
        XCTAssertEqual(r.channels, 1)
        XCTAssertEqual(r.frames, 88200)
    }

    // MARK: - SampleTrimmerService.TrimError descriptions

    func testTrimErrorScriptNotFoundDescription() {
        let err = SampleTrimmerService.TrimError.scriptNotFound
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testTrimErrorScriptFailedDescriptionContainsMessage() {
        let err = SampleTrimmerService.TrimError.scriptFailed("out of memory")
        XCTAssertTrue(err.errorDescription?.contains("out of memory") == true)
    }

    func testTrimErrorInvalidOutputDescription() {
        let err = SampleTrimmerService.TrimError.invalidOutput
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testAllTrimErrorsHaveNonEmptyDescriptions() {
        let errors: [SampleTrimmerService.TrimError] = [
            .scriptNotFound, .scriptFailed("e"), .invalidOutput
        ]
        for err in errors {
            XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
        }
    }

    // MARK: - SampleTrimmerService.TrimResult computed properties

    func testTrimResultFormattedSavings() {
        let r = SampleTrimmerService.TrimResult(
            outputURL: URL(fileURLWithPath: "/tmp/out.wav"),
            originalSamples: 1000,
            originalDuration: 1.0,
            originalSize: 2048,
            trimmedSamples: 800,
            trimmedDuration: 0.8,
            trimmedSize: 1638,
            trimStart: 50,
            trimEnd: 950,
            removedStart: 50,
            removedEnd: 50,
            savingsPercent: 20.0,
            dryRun: false
        )
        XCTAssertEqual(r.formattedSavings, "20.0%")
    }

    func testTrimResultFormattedOriginalSize() {
        let r = SampleTrimmerService.TrimResult(
            outputURL: URL(fileURLWithPath: "/tmp/out.wav"),
            originalSamples: 0, originalDuration: 0,
            originalSize: 1024,
            trimmedSamples: 0, trimmedDuration: 0, trimmedSize: 0,
            trimStart: 0, trimEnd: 0, removedStart: 0, removedEnd: 0,
            savingsPercent: 0, dryRun: false
        )
        // 1024 bytes → 1.0 KB
        XCTAssertEqual(r.formattedOriginalSize, "1.0 KB")
    }

    // MARK: - SoundFontConverter.SoundFontError descriptions

    func testSoundFontErrorInvalidFileDescription() {
        let err = SoundFontConverter.SoundFontError.invalidFile
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testSoundFontErrorUnsupportedVersionDescription() {
        let err = SoundFontConverter.SoundFontError.unsupportedVersion
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
        XCTAssertTrue(err.errorDescription?.contains("SF2") == true)
    }

    func testSoundFontErrorNoPresetsDescription() {
        let err = SoundFontConverter.SoundFontError.noPresets
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testSoundFontErrorNoSamplesDescription() {
        let err = SoundFontConverter.SoundFontError.noSamples
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testSoundFontErrorReadErrorDescriptionContainsMessage() {
        let err = SoundFontConverter.SoundFontError.readError("EOF")
        XCTAssertTrue(err.errorDescription?.contains("EOF") == true)
    }

    func testAllSoundFontErrorsHaveNonEmptyDescriptions() {
        let errors: [SoundFontConverter.SoundFontError] = [
            .invalidFile, .unsupportedVersion, .noPresets, .noSamples, .readError("x")
        ]
        for err in errors {
            XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
        }
    }

    // MARK: - SoundFontConverter struct field access

    func testSoundFontPresetFieldAccess() {
        let p = SoundFontConverter.Preset(
            name: "Grand Piano", bank: 0, preset: 0,
            presetBagIndex: 1, library: 0, genre: 0, morphology: 0
        )
        XCTAssertEqual(p.name, "Grand Piano")
        XCTAssertEqual(p.bank, 0)
        XCTAssertEqual(p.preset, 0)
    }

    func testSoundFontSampleFieldAccess() {
        let s = SoundFontConverter.Sample(
            name: "C4", start: 0, end: 44100,
            startLoop: 100, endLoop: 44000,
            sampleRate: 44100, originalPitch: 60,
            pitchCorrection: 0, sampleLink: 0, sampleType: 1,
            data: Data(count: 88200)
        )
        XCTAssertEqual(s.name, "C4")
        XCTAssertEqual(s.sampleRate, 44100)
        XCTAssertEqual(s.originalPitch, 60)
        XCTAssertEqual(s.data.count, 88200)
    }

    func testSoundFontInstrumentFieldAccess() {
        let i = SoundFontConverter.Instrument(name: "Piano", instrumentBagIndex: 3)
        XCTAssertEqual(i.name, "Piano")
        XCTAssertEqual(i.instrumentBagIndex, 3)
    }

    // MARK: - BankTemplateService.Template struct

    func testBankTemplateFieldAccess() {
        let t = BankTemplateService.Template(
            id: "INIT",
            name: "Init Bank",
            description: "Empty initialized bank",
            presets: 128
        )
        XCTAssertEqual(t.id, "INIT")
        XCTAssertEqual(t.name, "Init Bank")
        XCTAssertEqual(t.description, "Empty initialized bank")
        XCTAssertEqual(t.presets, 128)
    }

    // MARK: - BankTemplateService.CreateResult struct

    func testBankTemplateCreateResultFieldAccess() {
        let r = BankTemplateService.CreateResult(
            file: "/tmp/INIT.eb2",
            size: 489472,
            presets: 128
        )
        XCTAssertEqual(r.file, "/tmp/INIT.eb2")
        XCTAssertEqual(r.size, 489472)
        XCTAssertEqual(r.presets, 128)
    }

    // MARK: - ImageValidator.ValidatorError descriptions

    func testImageValidatorFileNotFoundDescription() {
        let err = ImageValidator.ValidatorError.fileNotFound
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testImageValidatorFileTooSmallDescription() {
        let err = ImageValidator.ValidatorError.fileTooSmall
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testImageValidatorReadErrorDescriptionContainsMessage() {
        let err = ImageValidator.ValidatorError.readError("permission denied")
        XCTAssertTrue(err.errorDescription?.contains("permission denied") == true)
    }

    func testAllValidatorErrorsHaveNonEmptyDescriptions() {
        let errors: [ImageValidator.ValidatorError] = [
            .fileNotFound, .fileTooSmall, .readError("x")
        ]
        for err in errors {
            XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
        }
    }

    // MARK: - ImageValidator.ValidationResult struct

    func testValidationResultFieldAccess() {
        let check = ImageValidator.ValidationResult.Check(
            name: "File size",
            passed: true,
            message: "239 MB ✓"
        )
        let result = ImageValidator.ValidationResult(
            isValid: true,
            checks: [check],
            errors: nil,
            errorCount: 0
        )
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.checks.count, 1)
        XCTAssertEqual(result.checks[0].name, "File size")
        XCTAssertTrue(result.checks[0].passed)
        XCTAssertEqual(result.checks[0].message, "239 MB ✓")
        XCTAssertNil(result.errors)
        XCTAssertEqual(result.errorCount, 0)
    }

    func testValidationResultInvalidWithErrors() {
        let validationError = ImageValidator.ValidationResult.ValidationError(
            code: "E001",
            title: "Bad magic",
            description: "Magic bytes do not match EMX2",
            context: nil,
            repairHint: "Re-format the disk",
            offset: "0x0000"
        )
        let result = ImageValidator.ValidationResult(
            isValid: false,
            checks: [],
            errors: [validationError],
            errorCount: 1
        )
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorCount, 1)
        XCTAssertEqual(result.errors?.first?.code, "E001")
        XCTAssertEqual(result.errors?.first?.title, "Bad magic")
        XCTAssertEqual(result.errors?.first?.repairHint, "Re-format the disk")
    }

    // MARK: - ImageValidator.validate throws fileNotFound for missing file

    func testImageValidatorThrowsFileNotFoundForMissingFile() async {
        let missing = URL(fileURLWithPath: "/nonexistent/image.hda")
        do {
            _ = try await ImageValidator.validate(imageURL: missing)
            XCTFail("Should throw for missing file")
        } catch let err as ImageValidator.ValidatorError {
            if case .fileNotFound = err { /* expected */ } else {
                XCTFail("Expected fileNotFound, got \(err)")
            }
        } catch {
            XCTFail("Expected ValidatorError.fileNotFound, got \(error)")
        }
    }

    // MARK: - SoundFontConverter.SampleRecord field access

    func testSoundFontSampleRecordFieldAccess() {
        let r = SoundFontConverter.SampleRecord(
            name: "Piano C4", start: 0, end: 1000,
            startLoop: 100, endLoop: 900,
            sampleRate: 44100, originalPitch: 60,
            pitchCorrection: -2, sampleLink: 0, sampleType: 1
        )
        XCTAssertEqual(r.name, "Piano C4")
        XCTAssertEqual(r.start, 0)
        XCTAssertEqual(r.end, 1000)
        XCTAssertEqual(r.startLoop, 100)
        XCTAssertEqual(r.endLoop, 900)
        XCTAssertEqual(r.sampleRate, 44100)
        XCTAssertEqual(r.originalPitch, 60)
        XCTAssertEqual(r.pitchCorrection, -2)
        XCTAssertEqual(r.sampleType, 1)
    }

    // MARK: - SoundFontConverter SF2 parsing regression tests
    //
    // These tests verify that shdr is correctly parsed from the pdta LIST
    // sub-chunk (the bug: parseSampleHeaders used to scan from offset 0 and
    // skip the entire RIFF chunk in one step, so samples were never found).

    /// Build a minimal SF2 blob with one preset and one sample.
    private func makeMinimalSF2(putSdtaFirst: Bool = true) -> Data {
        func le16(_ v: UInt16) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
        func le32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
        func ascii(_ s: String, pad: Int) -> Data {
            var d = s.data(using: .ascii)!.prefix(pad)
            if d.count < pad { d.append(Data(count: pad - d.count)) }
            return d
        }
        func chunk(_ id: String, _ body: Data) -> Data {
            var d = id.data(using: .ascii)!
            d += le32(UInt32(body.count))
            d += body
            if body.count % 2 != 0 { d += Data([0]) }
            return d
        }
        func list(_ type: String, _ body: Data) -> Data {
            var b = type.data(using: .ascii)!
            b += body
            var d = "LIST".data(using: .ascii)!
            d += le32(UInt32(b.count))
            d += b
            return d
        }

        // smpl: 4 16-bit samples (8 bytes)
        let pcmFrames: UInt32 = 4
        var smplBody = Data()
        for _ in 0..<pcmFrames { smplBody += le16(0x1234) }
        let sdta = list("sdta", chunk("smpl", smplBody))

        // phdr: 1 preset + 1 EOS (2 × 38 bytes)
        var phdrBody = Data()
        phdrBody += ascii("TestPreset", pad: 20) + le16(0) + le16(0) + le16(0) + le32(0) + le32(0) + le32(0)
        phdrBody += ascii("EOP", pad: 20) + le16(0) + le16(0) + le16(0) + le32(0) + le32(0) + le32(0)  // EOS sentinel

        // shdr: 1 sample + 1 EOS (2 × 46 bytes)
        var shdrBody = Data()
        // Sample 0: frames [0,4)
        shdrBody += ascii("TestSample", pad: 20)
        shdrBody += le32(0)          // start (frames)
        shdrBody += le32(pcmFrames)  // end (frames)
        shdrBody += le32(1)          // startLoop
        shdrBody += le32(3)          // endLoop
        shdrBody += le32(22050)      // sampleRate
        shdrBody += Data([69])       // originalPitch (A4)
        shdrBody += Data([0])        // pitchCorrection
        shdrBody += le16(0)          // sampleLink
        shdrBody += le16(1)          // sampleType (monoSample)
        // EOS sentinel (all zeros)
        shdrBody += Data(count: 46)

        // Minimal pbag/pmod/pgen/inst/ibag/imod/igen (each needs at least EOS)
        let pbag = chunk("pbag", Data(count: 8))   // 2 × 4 bytes
        let pmod = chunk("pmod", Data(count: 20))  // 2 × 10 bytes
        let pgen = chunk("pgen", Data(count: 8))   // 2 × 4 bytes
        let inst = chunk("inst", Data(count: 44))  // 2 × 22 bytes
        let ibag = chunk("ibag", Data(count: 8))   // 2 × 4 bytes
        let imod = chunk("imod", Data(count: 20))  // 2 × 10 bytes
        let igen = chunk("igen", Data(count: 8))   // 2 × 4 bytes

        let pdta = list("pdta",
            chunk("phdr", phdrBody) + pbag + pmod + pgen +
            inst + ibag + imod + igen +
            chunk("shdr", shdrBody)
        )

        let info = list("INFO", chunk("ifil", le16(2) + le16(1)))

        var sfbkBody: Data
        if putSdtaFirst {
            sfbkBody = info + sdta + pdta
        } else {
            sfbkBody = info + pdta + sdta
        }

        var riff = "RIFF".data(using: .ascii)!
        riff += le32(UInt32(sfbkBody.count + 4))  // RIFF size = 4 ("sfbk") + body
        riff += "sfbk".data(using: .ascii)!
        riff += sfbkBody
        return riff
    }

    /// SF2 parsing succeeds (no noSamples error) when sdta precedes pdta.
    func testSF2ParseDoesNotThrowNoSamplesWhenSdtaBeforePdta() {
        let sf2 = makeMinimalSF2(putSdtaFirst: true)
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_\(UUID().uuidString).sf2")
        do {
            try sf2.write(to: tmp)
            defer { try? FileManager.default.removeItem(at: tmp) }
            let banks = try SoundFontConverter.convertToEB2(url: tmp)
            XCTAssertFalse(banks.isEmpty, "Should produce at least one bank")
        } catch SoundFontConverter.SoundFontError.noSamples {
            XCTFail("noSamples — shdr was not found inside pdta LIST (regression)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// SF2 parsing succeeds when pdta precedes sdta (deferred-record path).
    func testSF2ParseDoesNotThrowNoSamplesWhenPdtaBeforeSdta() {
        let sf2 = makeMinimalSF2(putSdtaFirst: false)
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_\(UUID().uuidString).sf2")
        do {
            try sf2.write(to: tmp)
            defer { try? FileManager.default.removeItem(at: tmp) }
            let banks = try SoundFontConverter.convertToEB2(url: tmp)
            XCTAssertFalse(banks.isEmpty, "Should produce at least one bank even when pdta precedes sdta")
        } catch SoundFontConverter.SoundFontError.noSamples {
            XCTFail("noSamples — deferred-record path did not resolve samples (regression)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// The parsed bank name comes from the preset name in phdr.
    func testSF2ParsedBankNameMatchesPresetName() {
        let sf2 = makeMinimalSF2(putSdtaFirst: true)
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_\(UUID().uuidString).sf2")
        do {
            try sf2.write(to: tmp)
            defer { try? FileManager.default.removeItem(at: tmp) }
            let banks = try SoundFontConverter.convertToEB2(url: tmp)
            let names = banks.map { $0.name }
            XCTAssertTrue(names.contains(where: { $0.contains("TestPreset") }),
                          "Bank name should contain preset name 'TestPreset'; got \(names)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// An invalid SF2 (wrong RIFF type) throws invalidFile.
    func testSF2InvalidFileThrowsInvalidFile() {
        // Replace "sfbk" with "XXXX" — parseSoundFont should throw invalidFile
        var sf2 = makeMinimalSF2()
        sf2.replaceSubrange(8..<12, with: "XXXX".data(using: .ascii)!)
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_\(UUID().uuidString).sf2")
        do {
            try sf2.write(to: tmp)
            defer { try? FileManager.default.removeItem(at: tmp) }
            _ = try SoundFontConverter.convertToEB2(url: tmp)
            XCTFail("Should have thrown invalidFile")
        } catch SoundFontConverter.SoundFontError.invalidFile {
            // expected
        } catch {
            XCTFail("Expected invalidFile, got \(error)")
        }
    }
}
