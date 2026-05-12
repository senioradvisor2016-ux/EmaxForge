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
}
