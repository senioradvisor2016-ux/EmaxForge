import XCTest
import Foundation
@testable import EmaxForge

// MARK: - BankManager.BankError

/// Tests for BankManager error descriptions — pure enum, no disk I/O.
final class BankManagerTests: XCTestCase {

    func testDiskReadFailedDescription() {
        let err = BankManager.BankError.diskReadFailed
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testDiskWriteFailedDescription() {
        let err = BankManager.BankError.diskWriteFailed
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testInvalidDiskStructureDescription() {
        let err = BankManager.BankError.invalidDiskStructure
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testBankNotFoundDescription() {
        let err = BankManager.BankError.bankNotFound
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testDiskFullDescription() {
        let err = BankManager.BankError.diskFull
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testOperationFailedDescriptionContainsMessage() {
        let err = BankManager.BankError.operationFailed("write timeout")
        XCTAssertTrue(err.errorDescription?.contains("write timeout") == true)
    }

    func testAllBankErrorsHaveNonEmptyDescriptions() {
        let errors: [BankManager.BankError] = [
            .diskReadFailed, .diskWriteFailed, .invalidDiskStructure,
            .bankNotFound, .diskFull, .operationFailed("x")
        ]
        for err in errors {
            XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
        }
    }
}

// MARK: - ImageCreator

/// Tests for ImageCreator static dictionaries and error descriptions.
final class ImageCreatorDictionaryTests: XCTestCase {

    // MARK: - CreatorError descriptions

    func testOSFileNotFoundDescription() {
        let err = ImageCreator.CreatorError.osFileNotFound
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testOSFileTooLargeDescription() {
        let err = ImageCreator.CreatorError.osFileTooLarge
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testInvalidSizeDescription() {
        let err = ImageCreator.CreatorError.invalidSize
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testUnsupportedSizeDescriptionContainsSizes() {
        let err = ImageCreator.CreatorError.unsupportedSize
        // Should mention valid sizes: 96, 239, 481, 633, 962
        XCTAssertTrue(err.errorDescription?.contains("96") == true ||
                      err.errorDescription?.contains("239") == true)
    }

    func testWriteErrorDescriptionContainsMessage() {
        let err = ImageCreator.CreatorError.writeError("disk full")
        XCTAssertTrue(err.errorDescription?.contains("disk full") == true)
    }

    func testAllCreatorErrorsHaveNonEmptyDescriptions() {
        let errors: [ImageCreator.CreatorError] = [
            .osFileNotFound, .osFileTooLarge, .invalidSize, .unsupportedSize, .writeError("x")
        ]
        for err in errors {
            XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
        }
    }

    // MARK: - diskSizes dictionary

    func testDiskSizesHasFiveEntries() {
        XCTAssertEqual(ImageCreator.diskSizes.count, 5)
    }

    func testDiskSizes96MB() {
        XCTAssertEqual(ImageCreator.diskSizes[96], 100_578_304)
    }

    func testDiskSizes239MB() {
        XCTAssertEqual(ImageCreator.diskSizes[239], 250_398_720)
    }

    func testDiskSizes481MB() {
        XCTAssertEqual(ImageCreator.diskSizes[481], 503_940_096)
    }

    func testDiskSizes633MB() {
        XCTAssertEqual(ImageCreator.diskSizes[633], 663_189_504)
    }

    func testDiskSizes962MB() {
        XCTAssertEqual(ImageCreator.diskSizes[962], 1_007_880_704)
    }

    func testDiskSizesAllArePositiveAndSectorAligned() {
        for (_, size) in ImageCreator.diskSizes {
            XCTAssertGreaterThan(size, 0)
            XCTAssertEqual(size % 512, 0, "All disk sizes must be sector-aligned")
        }
    }

    // MARK: - templates dictionary

    func testTemplatesHasFiveEntries() {
        XCTAssertEqual(ImageCreator.templates.count, 5)
    }

    func testTemplate96MBBankCount() {
        XCTAssertEqual(ImageCreator.templates[96]?.bankCount, 111)
    }

    func testTemplate239MBBankCount() {
        XCTAssertEqual(ImageCreator.templates[239]?.bankCount, 90)
    }

    func testTemplate96MBClusterAreaStartSector() {
        XCTAssertEqual(ImageCreator.templates[96]?.clusterAreaStartSector, 120)
    }

    func testTemplate96MBBootSignature() {
        XCTAssertEqual(ImageCreator.templates[96]?.bootSig1, 0xA1)
        XCTAssertEqual(ImageCreator.templates[96]?.bootSig2, 0x93)
    }

    func testTemplate239MBClusterAreaStartSector() {
        // header[0x20] = 0x62 = 98 in the main package
        XCTAssertEqual(ImageCreator.templates[239]?.clusterAreaStartSector, 98)
    }

    func testAllTemplatesHavePositiveClusterSize() {
        for (size, tmpl) in ImageCreator.templates {
            XCTAssertGreaterThan(tmpl.clusterSize, 0,
                                 "\(size)MB template must have positive clusterSize")
        }
    }
}

// MARK: - CatalogService structs

/// Tests for CatalogService struct field access — pure struct construction.
final class CatalogServiceTests: XCTestCase {

    func testCatalogEntryFieldAccess() {
        let entry = CatalogService.CatalogEntry(
            id: 0, index: 0, name: "STRINGS",
            cluster: 2, sizeClusters: 1, sizeBytes: 489472,
            sizeMB: 0.47, flags: "0x81", presetCount: 24,
            isActive: true, isOS: false, isEmpty: false
        )
        XCTAssertEqual(entry.name, "STRINGS")
        XCTAssertEqual(entry.cluster, 2)
        XCTAssertEqual(entry.sizeBytes, 489472)
        XCTAssertTrue(entry.isActive)
        XCTAssertFalse(entry.isOS)
        XCTAssertFalse(entry.isEmpty)
        XCTAssertEqual(entry.presetCount, 24)
    }

    func testCatalogSummaryFieldAccess() {
        let entry = CatalogService.CatalogEntry(
            id: 0, index: 0, name: "OS",
            cluster: 1, sizeClusters: 1, sizeBytes: 489472,
            sizeMB: 0.47, flags: "0x88", presetCount: 0,
            isActive: true, isOS: true, isEmpty: false
        )
        let summary = CatalogService.CatalogSummary(
            totalEntries: 90,
            activeEntries: 12,
            bankCount: 11,
            osEntry: entry,
            clusterSize: 489472,
            entries: [entry]
        )
        XCTAssertEqual(summary.totalEntries, 90)
        XCTAssertEqual(summary.activeEntries, 12)
        XCTAssertEqual(summary.bankCount, 11)
        XCTAssertNotNil(summary.osEntry)
        XCTAssertEqual(summary.osEntry?.name, "OS")
        XCTAssertEqual(summary.clusterSize, 489472)
        XCTAssertEqual(summary.entries.count, 1)
    }

    func testCatalogSummaryNoOSEntry() {
        let summary = CatalogService.CatalogSummary(
            totalEntries: 90, activeEntries: 0, bankCount: 0,
            osEntry: nil, clusterSize: 196352, entries: []
        )
        XCTAssertNil(summary.osEntry)
        XCTAssertTrue(summary.entries.isEmpty)
    }
}

// MARK: - ImageService.ImageValidation

/// Tests for ImageValidation struct — pure struct construction.
final class ImageValidationTests: XCTestCase {

    func testImageValidationValidCase() {
        let v = ImageValidation(isValid: true, message: "OK", fileSize: 250_398_720)
        XCTAssertTrue(v.isValid)
        XCTAssertEqual(v.message, "OK")
        XCTAssertEqual(v.fileSize, 250_398_720)
    }

    func testImageValidationInvalidCase() {
        let v = ImageValidation(isValid: false, message: "Bad magic")
        XCTAssertFalse(v.isValid)
        XCTAssertEqual(v.message, "Bad magic")
        XCTAssertEqual(v.fileSize, 0, "Default fileSize should be 0")
    }
}

// MARK: - ManualSearchService.SearchResult

final class ManualSearchServiceTests: XCTestCase {

    func testSearchResultFieldAccess() {
        let r = ManualSearchService.SearchResult(
            source: "Operations Manual",
            section: "Chapter 3: Samples",
            content: "Sample rates supported by EMAX II...",
            score: 0.85
        )
        XCTAssertEqual(r.source, "Operations Manual")
        XCTAssertEqual(r.section, "Chapter 3: Samples")
        XCTAssertTrue(r.content.contains("EMAX II"))
        XCTAssertEqual(r.score, 0.85, accuracy: 0.001)
    }

    func testSearchResultScoreRange() {
        let r = ManualSearchService.SearchResult(
            source: "Diagnostics", section: "Error Codes", content: "E001", score: 1.0
        )
        XCTAssertGreaterThanOrEqual(r.score, 0.0)
        XCTAssertLessThanOrEqual(r.score, 1.0)
    }
}

// MARK: - FavoritesManager

/// Tests for FavoritesManager in-memory logic — add/remove/toggle/isFavorite.
/// Uses a fresh instance so tests don't depend on persistent UserDefaults state.
final class FavoritesManagerTests: XCTestCase {

    // Clear the UserDefaults keys before each test to avoid cross-test pollution
    private let banksKey = "favoriteBanks"
    private let samplesKey = "favoriteSamples"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: banksKey)
        UserDefaults.standard.removeObject(forKey: samplesKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: banksKey)
        UserDefaults.standard.removeObject(forKey: samplesKey)
        super.tearDown()
    }

    func testInitiallyNotFavorite() {
        let mgr = FavoritesManager()
        XCTAssertFalse(mgr.isFavorite(bankName: "STRINGS"))
    }

    func testAddFavoriteMakesBankFavorite() {
        let mgr = FavoritesManager()
        mgr.addFavorite(bankName: "STRINGS")
        XCTAssertTrue(mgr.isFavorite(bankName: "STRINGS"))
    }

    func testRemoveFavoriteRemovesBank() {
        let mgr = FavoritesManager()
        mgr.addFavorite(bankName: "BRASS")
        mgr.removeFavorite(bankName: "BRASS")
        XCTAssertFalse(mgr.isFavorite(bankName: "BRASS"))
    }

    func testToggleFavoriteAddsWhenAbsent() {
        let mgr = FavoritesManager()
        mgr.toggleFavorite(bankName: "PIANO")
        XCTAssertTrue(mgr.isFavorite(bankName: "PIANO"))
    }

    func testToggleFavoriteRemovesWhenPresent() {
        let mgr = FavoritesManager()
        mgr.addFavorite(bankName: "PIANO")
        mgr.toggleFavorite(bankName: "PIANO")
        XCTAssertFalse(mgr.isFavorite(bankName: "PIANO"))
    }

    func testMultipleFavoritesIndependent() {
        let mgr = FavoritesManager()
        mgr.addFavorite(bankName: "A")
        mgr.addFavorite(bankName: "B")
        XCTAssertTrue(mgr.isFavorite(bankName: "A"))
        XCTAssertTrue(mgr.isFavorite(bankName: "B"))
        mgr.removeFavorite(bankName: "A")
        XCTAssertFalse(mgr.isFavorite(bankName: "A"))
        XCTAssertTrue(mgr.isFavorite(bankName: "B"))
    }

    func testSampleFavoritesIndependentFromBankFavorites() {
        let mgr = FavoritesManager()
        mgr.toggleFavorite(sampleName: "KICK_01")
        XCTAssertTrue(mgr.isFavorite(sampleName: "KICK_01"))
        XCTAssertFalse(mgr.isFavorite(bankName: "KICK_01"),
                       "Bank and sample favorites are independent")
    }

    func testAddingDuplicateFavoriteIsIdempotent() {
        let mgr = FavoritesManager()
        mgr.addFavorite(bankName: "PIANO")
        mgr.addFavorite(bankName: "PIANO")
        // Should still count as one entry
        XCTAssertEqual(mgr.favoriteBanks.count, 1)
    }
}
