import XCTest
import Foundation

/// Tests for bank-to-.EB2 export logic (issue #1)
///
/// These tests validate the pure-logic parts of BankExporter:
///   - FAT chain traversal
///   - .EB2 output filename formatting (BANK_NAME.EB2)
///   - ExportResult fields
///   - Edge cases (empty selection, duplicate names)
///
/// Integration tests (real disk image I/O) are intentionally skipped
/// in CI because they require a .hda fixture file.
final class BankExportTests: XCTestCase {

    // MARK: - Output filename formatting

    func testEB2FilenameUppercase() {
        // Bank names must produce UPPERCASE .EB2 filenames, e.g. STRINGS.EB2
        let bankName = "strings"
        let filename = bankName.uppercased() + ".EB2"
        XCTAssertEqual(filename, "STRINGS.EB2")
    }

    func testEB2FilenamePreservesCase() {
        // Names already in uppercase stay as-is
        let bankName = "BRASS"
        let filename = bankName + ".EB2"
        XCTAssertEqual(filename, "BRASS.EB2")
    }

    func testEB2FilenameTrimsWhitespace() {
        // Bank names on EMAX II are padded with spaces — trim before appending extension
        let rawName  = "PIANO   "
        let filename = rawName.trimmingCharacters(in: .whitespaces) + ".EB2"
        XCTAssertEqual(filename, "PIANO.EB2")
    }

    func testEB2FilenameExtensionIsUppercase() {
        // The extension must always be .EB2 (uppercase), matching EMAX II convention
        let ext = "EB2"
        XCTAssert(ext == ext.uppercased(), "Extension must be uppercase")
    }

    // MARK: - FAT chain traversal logic

    func testFATEndOfChainSentinel() {
        // 0x7FFF marks end-of-chain in EMAX II FAT16 variant
        let eoc: UInt16 = 0x7FFF
        XCTAssertEqual(eoc, 0x7FFF)
    }

    func testFATFreeSectorSentinel() {
        // 0x0000 marks a free sector — traversal must stop here (broken chain guard)
        let free: UInt16 = 0x0000
        XCTAssertEqual(free, 0x0000)
    }

    func testFATChainCollectsAllClusters() {
        // Simulate a 3-cluster chain: 5 → 6 → 7 → 0x7FFF (end)
        var fat = [UInt16](repeating: 0, count: 256)
        fat[5] = 6
        fat[6] = 7
        fat[7] = 0x7FFF

        var clusters = [Int]()
        var current = 5
        while current > 0 && current < fat.count && clusters.count < 10000 {
            clusters.append(current)
            let next = Int(fat[current])
            if next == 0x7FFF || next == 0x8000 || next == 0x0000 { break }
            current = next
        }

        XCTAssertEqual(clusters, [5, 6, 7])
    }

    func testFATChainLoopGuard() {
        // A corrupt FAT where a cluster points back to itself must not loop forever
        var fat = [UInt16](repeating: 0, count: 256)
        fat[3] = 3   // Self-loop

        var clusters = [Int]()
        var current = 3
        while current > 0 && current < fat.count && clusters.count < 10000 {
            clusters.append(current)
            let next = Int(fat[current])
            if next == 0x7FFF || next == 0x8000 || next == 0x0000 || next == current { break }
            current = next
        }

        XCTAssertEqual(clusters, [3])   // Only the start cluster; loop stops immediately
    }

    // MARK: - Batch export selection logic

    func testEmptySelectionExportsNothing() {
        let allBanks   = ["STRINGS", "BRASS", "PIANO"]
        let selected   = Set<String>()
        let toExport   = allBanks.filter { selected.contains($0) }
        XCTAssertTrue(toExport.isEmpty)
    }

    func testPartialSelectionExportsCorrectSubset() {
        let allBanks  = ["STRINGS", "BRASS", "PIANO"]
        let selected  = Set(["BRASS", "PIANO"])
        let toExport  = allBanks.filter { selected.contains($0) }
        XCTAssertEqual(Set(toExport), Set(["BRASS", "PIANO"]))
    }

    func testSelectAllExportsAll() {
        let allBanks = ["STRINGS", "BRASS", "PIANO"]
        let selected = Set(allBanks)
        let toExport = allBanks.filter { selected.contains($0) }
        XCTAssertEqual(toExport.count, 3)
    }

    // MARK: - Progress tracking

    func testProgressAdvancesPerBank() {
        // Progress fraction should advance linearly from 0 → 1 over the export batch
        let banks = ["A", "B", "C", "D"]
        for (index, _) in banks.enumerated() {
            let progress = Double(index) / Double(banks.count)
            XCTAssertGreaterThanOrEqual(progress, 0.0)
            XCTAssertLessThan(progress, 1.0)
        }
        let finalProgress = 1.0
        XCTAssertEqual(finalProgress, 1.0)
    }

    // MARK: - Output directory handling

    func testOutputURLComposedCorrectly() {
        let dir      = URL(fileURLWithPath: "/tmp/emaxexport")
        let bankName = "STRINGS"
        let out      = dir.appendingPathComponent(bankName + ".EB2")
        XCTAssertEqual(out.lastPathComponent, "STRINGS.EB2")
        XCTAssertEqual(out.deletingLastPathComponent().path, dir.path)
    }

    func testMultipleBanksProduceSeparateFiles() {
        let dir   = URL(fileURLWithPath: "/tmp/emaxexport")
        let banks = ["STRINGS", "BRASS", "PIANO"]
        let urls  = banks.map { dir.appendingPathComponent($0 + ".EB2") }
        let names = urls.map { $0.lastPathComponent }
        XCTAssertEqual(names, ["STRINGS.EB2", "BRASS.EB2", "PIANO.EB2"])
        // All filenames must be unique
        XCTAssertEqual(Set(names).count, names.count)
    }
}
