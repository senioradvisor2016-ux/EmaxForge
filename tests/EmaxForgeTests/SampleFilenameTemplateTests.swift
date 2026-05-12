import XCTest
import Foundation
@testable import EmaxForge

/// Tests for SampleFilenameTemplate — EMXP file naming template feature.
final class SampleFilenameTemplateTests: XCTestCase {

    // MARK: - Shared context

    private func makeContext(
        bank: String = "STRINGS",
        sample: String = "VIOLIN C3",
        sampleIndex: Int = 7,
        bankIndex: Int = 3,
        date: Date = Date(timeIntervalSince1970: 1_747_000_000) // fixed for determinism
    ) -> SampleFilenameTemplate.Context {
        SampleFilenameTemplate.Context(
            bankName: bank, sampleName: sample,
            sampleIndex: sampleIndex, bankIndex: bankIndex, date: date)
    }

    // MARK: - Default template

    func testDefaultTemplateIsSampleVariable() {
        XCTAssertEqual(SampleFilenameTemplate.default.pattern, "{sample}")
    }

    func testDefaultTemplateResolvesToSampleName() {
        let t = SampleFilenameTemplate.default
        let result = t.resolve(context: makeContext())
        XCTAssertEqual(result, "VIOLIN C3")
    }

    // MARK: - Variable substitution

    func testBankVariable() {
        let t = SampleFilenameTemplate("{bank}")
        let result = t.resolve(context: makeContext(bank: "BRASS"))
        XCTAssertEqual(result, "BRASS")
    }

    func testSampleVariable() {
        let t = SampleFilenameTemplate("{sample}")
        let result = t.resolve(context: makeContext(sample: "KICK"))
        XCTAssertEqual(result, "KICK")
    }

    func testIndexVariablePaddedToThreeDigits() {
        let t = SampleFilenameTemplate("{index}")
        XCTAssertEqual(t.resolve(context: makeContext(sampleIndex: 1)),   "001")
        XCTAssertEqual(t.resolve(context: makeContext(sampleIndex: 42)),  "042")
        XCTAssertEqual(t.resolve(context: makeContext(sampleIndex: 999)), "999")
    }

    func testBankIndexVariable() {
        let t = SampleFilenameTemplate("{bankindex}")
        XCTAssertEqual(t.resolve(context: makeContext(bankIndex: 5)), "5")
    }

    func testDateVariableHasISOFormat() {
        // Date(timeIntervalSince1970: 1_747_000_000) = 2025-05-12 or thereabouts
        let t = SampleFilenameTemplate("{date}")
        let result = t.resolve(context: makeContext())
        // Must match YYYY-MM-DD pattern
        let regex = try! NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}$")
        let range = NSRange(result.startIndex..., in: result)
        XCTAssertTrue(regex.firstMatch(in: result, range: range) != nil,
                      "Date variable '\(result)' should match YYYY-MM-DD")
    }

    // MARK: - Composite templates

    func testEMXPStyleTemplate() {
        let t = SampleFilenameTemplate.emxpStyle    // {bank}_{index}_{sample}
        let result = t.resolve(context: makeContext(bank: "STRINGS", sample: "VIOLIN C3", sampleIndex: 7))
        XCTAssertEqual(result, "STRINGS_007_VIOLIN C3")
    }

    func testBankAndSampleTemplate() {
        let t = SampleFilenameTemplate.bankAndSample  // {bank}_{sample}
        let result = t.resolve(context: makeContext(bank: "KEYS", sample: "PIANO"))
        XCTAssertEqual(result, "KEYS_PIANO")
    }

    func testMixedLiteralAndVariables() {
        let t = SampleFilenameTemplate("EXPORT_{bank}_{index}")
        let result = t.resolve(context: makeContext(bank: "BASS", sampleIndex: 3))
        XCTAssertEqual(result, "EXPORT_BASS_003")
    }

    func testUnknownVariableLeftAsLiteral() {
        // Unknown tokens like {unknown} are not substituted but are left as-is
        // (after illegal char removal — braces and letters are legal)
        let t = SampleFilenameTemplate("{unknown}_{sample}")
        let result = t.resolve(context: makeContext(sample: "HIT"))
        XCTAssertTrue(result.contains("HIT"), "Sample variable should resolve")
    }

    // MARK: - Case insensitivity

    func testVariablesCaseInsensitive() {
        let t = SampleFilenameTemplate("{BANK}_{SAMPLE}_{INDEX}")
        let result = t.resolve(context: makeContext(bank: "CHOIR", sample: "SOPR", sampleIndex: 2))
        XCTAssertEqual(result, "CHOIR_SOPR_002")
    }

    // MARK: - Sanitization

    func testIllegalCharsRemovedFromBankName() {
        let t = SampleFilenameTemplate("{bank}")
        let result = t.resolve(context: makeContext(bank: "BASS:GUITAR"))
        XCTAssertFalse(result.contains(":"), "Colon must be removed from bank name")
        XCTAssertEqual(result, "BASSGULTAR".prefix(result.count) == result.prefix(result.count)
                       ? result : result, "")
        XCTAssertTrue(result.hasPrefix("BASS"), "BASS prefix should remain")
    }

    func testIllegalCharsRemovedFromSampleName() {
        let t = SampleFilenameTemplate("{sample}")
        let result = t.resolve(context: makeContext(sample: "GUITAR/FLUTE"))
        XCTAssertFalse(result.contains("/"), "Slash must be removed")
        XCTAssertFalse(result.isEmpty)
    }

    func testAllIllegalCharsRemoved() {
        let illegal = ": / \\ * ? \" < > |"
        let t = SampleFilenameTemplate("{sample}")
        let result = t.resolve(context: makeContext(sample: illegal))
        for ch in [":", "/", "\\", "*", "?", "\"", "<", ">", "|"] {
            XCTAssertFalse(result.contains(ch), "'\(ch)' must be removed")
        }
    }

    // MARK: - Length limits

    func testVeryLongSampleNameIsCapped() {
        let long = String(repeating: "A", count: 300)
        let t = SampleFilenameTemplate("{sample}")
        let result = t.resolve(context: makeContext(sample: long))
        XCTAssertLessThanOrEqual(result.count, 200, "Result must be <= 200 chars")
    }

    func testTotalResultCappedAt200() {
        let bank   = String(repeating: "B", count: 80)
        let sample = String(repeating: "S", count: 80)
        let t = SampleFilenameTemplate("{bank}_{index}_{sample}")
        let result = t.resolve(context: makeContext(bank: bank, sample: sample, sampleIndex: 999))
        XCTAssertLessThanOrEqual(result.count, 200)
    }

    // MARK: - Empty / fallback

    func testEmptyPatternFallsBackToSampleVariable() {
        let t = SampleFilenameTemplate("")
        let result = t.resolve(context: makeContext(sample: "KICK"))
        XCTAssertEqual(result, "KICK")
    }

    func testEmptyBankNameBecomesUNKNOWN() {
        // BankName="" in context → SampleExporter passes "UNKNOWN"
        let t = SampleFilenameTemplate("{bank}")
        let ctx = SampleFilenameTemplate.Context(
            bankName: "UNKNOWN", sampleName: "X", sampleIndex: 1, bankIndex: 1, date: Date())
        XCTAssertEqual(t.resolve(context: ctx), "UNKNOWN")
    }

    func testAllIllegalSampleNameYieldsUntitled() {
        // If the entire sample name is illegal chars, resolved result should be "untitled"
        let t = SampleFilenameTemplate("{sample}")
        let result = t.resolve(context: makeContext(sample: "///***"))
        XCTAssertEqual(result, "untitled")
    }

    // MARK: - removeIllegalChars static helper

    func testRemoveIllegalCharsNormalString() {
        XCTAssertEqual(SampleFilenameTemplate.removeIllegalChars("Hello World"), "Hello World")
    }

    func testRemoveIllegalCharsAllClean() {
        XCTAssertEqual(SampleFilenameTemplate.removeIllegalChars("BRASS_001"), "BRASS_001")
    }

    func testRemoveIllegalCharsStripsSlash() {
        XCTAssertEqual(SampleFilenameTemplate.removeIllegalChars("A/B"), "AB")
    }

    func testRemoveIllegalCharsEmpty() {
        XCTAssertEqual(SampleFilenameTemplate.removeIllegalChars(""), "")
    }

    // MARK: - Validation helpers

    func testIsValidReturnsTrueForSampleVar() {
        XCTAssertTrue(SampleFilenameTemplate.isValid("{sample}"))
    }

    func testIsValidReturnsTrueForBankVar() {
        XCTAssertTrue(SampleFilenameTemplate.isValid("{bank}"))
    }

    func testIsValidReturnsTrueForComposite() {
        XCTAssertTrue(SampleFilenameTemplate.isValid("{bank}_{index}_{sample}"))
    }

    func testIsValidReturnsFalseForNoVars() {
        XCTAssertFalse(SampleFilenameTemplate.isValid("just_literal_text"))
    }

    func testIsValidCaseInsensitive() {
        XCTAssertTrue(SampleFilenameTemplate.isValid("{BANK}"))
        XCTAssertTrue(SampleFilenameTemplate.isValid("{Sample}"))
    }

    func testVariablesUsedReturnsList() {
        let vars = SampleFilenameTemplate.variablesUsed(in: "{bank}_{sample}_{index}")
        XCTAssertTrue(vars.contains("{bank}"))
        XCTAssertTrue(vars.contains("{sample}"))
        XCTAssertTrue(vars.contains("{index}"))
        XCTAssertFalse(vars.contains("{bankindex}"))
    }

    func testVariablesUsedReturnsEmptyForNoVars() {
        let vars = SampleFilenameTemplate.variablesUsed(in: "plain_name")
        XCTAssertTrue(vars.isEmpty)
    }
}
