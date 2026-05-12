import XCTest
import Foundation
@testable import EmaxForge

/// Tests for PitchShifter — supportedRates, ShiftError descriptions, ShiftResult
/// struct, and error guards that fire before any disk I/O.
final class PitchShifterTests: XCTestCase {

    // MARK: - Helpers

    private func fakeBankEntry() -> BankCatalogEntry {
        BankCatalogEntry(
            catalogIndex: 0,
            name: "FAKE",
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

    // MARK: - supportedRates

    func testSupportedRatesContains22050() {
        XCTAssertTrue(PitchShifter.supportedRates.contains(22050))
    }

    func testSupportedRatesContains44100() {
        XCTAssertTrue(PitchShifter.supportedRates.contains(44100))
    }

    func testSupportedRatesContains39063() {
        XCTAssertTrue(PitchShifter.supportedRates.contains(39063))
    }

    func testSupportedRatesContains10000() {
        XCTAssertTrue(PitchShifter.supportedRates.contains(10000))
    }

    func testSupportedRatesHasNineEntries() {
        XCTAssertEqual(PitchShifter.supportedRates.count, 9)
    }

    func testSupportedRatesAreSortedAscending() {
        let rates = PitchShifter.supportedRates
        for i in 0..<(rates.count - 1) {
            XCTAssertLessThan(rates[i], rates[i + 1],
                              "supportedRates must be in ascending order")
        }
    }

    func testSupportedRatesLowestIs10000() {
        XCTAssertEqual(PitchShifter.supportedRates.first, 10000)
    }

    func testSupportedRatesHighestIs44100() {
        XCTAssertEqual(PitchShifter.supportedRates.last, 44100)
    }

    func testSupportedRatesDoNotContain48000() {
        XCTAssertFalse(PitchShifter.supportedRates.contains(48000),
                       "48000 Hz is not an EMAX II hardware rate")
    }

    func testSupportedRatesDoNotContain8000() {
        XCTAssertFalse(PitchShifter.supportedRates.contains(8000))
    }

    // MARK: - ShiftError descriptions

    func testSemitonesOutOfRangeDescriptionContainsValue() {
        let err = PitchShifter.ShiftError.semitonesOutOfRange(30.0)
        XCTAssertTrue(err.errorDescription?.contains("30.0") == true)
    }

    func testSemitonesOutOfRangeDescriptionMentionsLimit() {
        let err = PitchShifter.ShiftError.semitonesOutOfRange(25.0)
        XCTAssertTrue(err.errorDescription?.contains("24") == true,
                      "Description should mention the ±24 semitone limit")
    }

    func testUnsupportedRateDescriptionContainsRate() {
        let err = PitchShifter.ShiftError.unsupportedRate(48000)
        XCTAssertTrue(err.errorDescription?.contains("48000") == true)
    }

    func testBankFormatNotSupportedDescription() {
        let err = PitchShifter.ShiftError.bankFormatNotSupported
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testSampleIndexOutOfRangeDescriptionContainsIndex() {
        let err = PitchShifter.ShiftError.sampleIndexOutOfRange(99)
        XCTAssertTrue(err.errorDescription?.contains("99") == true)
    }

    func testUnderlyingErrorDescriptionForwardsMessage() {
        struct MockError: LocalizedError {
            var errorDescription: String? { "mock underlying failure" }
        }
        let err = PitchShifter.ShiftError.underlyingError(MockError())
        XCTAssertTrue(err.errorDescription?.contains("mock underlying failure") == true)
    }

    // MARK: - ShiftResult struct

    func testShiftResultFieldAccess() {
        let r = PitchShifter.ShiftResult(
            sampleIndex: 3,
            originalRate: 22050,
            newRate: 27778,
            actualSemitones: 3.99
        )
        XCTAssertEqual(r.sampleIndex, 3)
        XCTAssertEqual(r.originalRate, 22050)
        XCTAssertEqual(r.newRate, 27778)
        XCTAssertEqual(r.actualSemitones, 3.99, accuracy: 0.001)
    }

    func testShiftResultUnchangedRateZeroSemitones() {
        let r = PitchShifter.ShiftResult(
            sampleIndex: 0,
            originalRate: 22050,
            newRate: 22050,
            actualSemitones: 0.0
        )
        XCTAssertEqual(r.originalRate, r.newRate)
        XCTAssertEqual(r.actualSemitones, 0.0, accuracy: 0.0001)
    }

    // MARK: - shiftBySemitones: error guards (fire before disk I/O)

    func testShiftThrowsForSemitonesGreaterThan24() {
        XCTAssertThrowsError(
            try PitchShifter.shiftBySemitones(25.0, sampleIndex: 0,
                                               in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if case .semitonesOutOfRange(let s) = err as! PitchShifter.ShiftError {
                XCTAssertEqual(s, 25.0, accuracy: 0.001)
            } else {
                XCTFail("Expected semitonesOutOfRange(25.0)")
            }
        }
    }

    func testShiftThrowsForSemitonesLessThanMinus24() {
        XCTAssertThrowsError(
            try PitchShifter.shiftBySemitones(-25.0, sampleIndex: 0,
                                               in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if case .semitonesOutOfRange(_) = err as! PitchShifter.ShiftError { } else {
                XCTFail("Expected semitonesOutOfRange for -25.0")
            }
        }
    }

    func testShiftThrowsForNegativeSampleIndex() {
        XCTAssertThrowsError(
            try PitchShifter.shiftBySemitones(1.0, sampleIndex: -1,
                                               in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if case .sampleIndexOutOfRange(let i) = err as! PitchShifter.ShiftError {
                XCTAssertEqual(i, -1)
            } else {
                XCTFail("Expected sampleIndexOutOfRange(-1)")
            }
        }
    }

    func testShiftExactly24SemitonesPassesGuard() {
        // 24.0 passes the abs <= 24 guard → then fails on disk I/O (not semitonesOutOfRange)
        XCTAssertThrowsError(
            try PitchShifter.shiftBySemitones(24.0, sampleIndex: 0,
                                               in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if let shiftErr = err as? PitchShifter.ShiftError,
               case .semitonesOutOfRange(_) = shiftErr {
                XCTFail("24.0 semitones should pass the guard")
            }
            // Any other error type means the guard passed — that's the expected path
        }
    }

    func testShiftZeroSemitonesPassesGuard() {
        // 0.0 passes the guard → fails on disk I/O with a non-ShiftError
        XCTAssertThrowsError(
            try PitchShifter.shiftBySemitones(0.0, sampleIndex: 0,
                                               in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if let shiftErr = err as? PitchShifter.ShiftError,
               case .semitonesOutOfRange(_) = shiftErr {
                XCTFail("0.0 semitones should pass the range guard")
            }
            // Any other error type means the guard passed — that's the expected path
        }
    }

    // MARK: - setSampleRate: error guards (fire before disk I/O)

    func testSetSampleRateThrowsForUnsupportedRate() {
        XCTAssertThrowsError(
            try PitchShifter.setSampleRate(48000, sampleIndex: 0,
                                            in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if case .unsupportedRate(let r) = err as! PitchShifter.ShiftError {
                XCTAssertEqual(r, 48000)
            } else {
                XCTFail("Expected unsupportedRate(48000)")
            }
        }
    }

    func testSetSampleRateThrowsForNegativeSampleIndex() {
        XCTAssertThrowsError(
            try PitchShifter.setSampleRate(22050, sampleIndex: -1,
                                            in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if case .sampleIndexOutOfRange(_) = err as! PitchShifter.ShiftError { } else {
                XCTFail("Expected sampleIndexOutOfRange for index -1")
            }
        }
    }

    func testSetSampleRateFor22050PassesGuard() {
        // 22050 is in supportedRates → guard passes → fails on disk I/O (not unsupportedRate)
        XCTAssertThrowsError(
            try PitchShifter.setSampleRate(22050, sampleIndex: 0,
                                            in: fakeBankEntry(), imageURL: fakeURL)
        ) { err in
            if let shiftErr = err as? PitchShifter.ShiftError,
               case .unsupportedRate(_) = shiftErr {
                XCTFail("22050 is a supported rate")
            }
            // Any other error type means the guard passed — that's the expected path
        }
    }

    func testSetSampleRateAllSupportedRatesPassGuard() {
        for rate in PitchShifter.supportedRates {
            XCTAssertThrowsError(
                try PitchShifter.setSampleRate(rate, sampleIndex: 0,
                                                in: fakeBankEntry(), imageURL: fakeURL)
            ) { err in
                if let shiftErr = err as? PitchShifter.ShiftError,
                   case .unsupportedRate(_) = shiftErr {
                    XCTFail("Rate \(rate) is in supportedRates and should pass the guard")
                }
                // Any other error type means the guard passed — that's the expected path
            }
        }
    }
}
