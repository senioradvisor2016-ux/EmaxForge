import XCTest
import Foundation
@testable import EmaxForge

/// Tests for DiskReportGenerator (EMXP feature parity: HTML/TXT/CSV disk reports).
///
/// All tests work with synthetic DiskInspection values — no disk file I/O required.
final class DiskReportGeneratorTests: XCTestCase {

    // MARK: - Helpers: build synthetic inspection

    private let fixedDate = Date(timeIntervalSince1970: 1_747_000_000)  // deterministic

    /// Minimal valid DiskInspection with two user banks.
    private func makeInspection(
        bankCount: Int = 2,
        freeClusters: Int = 50,
        includeOS: Bool = false,
        withBoot: Bool = false,
        health: [DiskHealthWarning] = []
    ) -> DiskInspection {
        let header = DiskHeaderInfo(
            magic: "EMX2",
            imageSize: 239 * 1024 * 1024,
            diskSizeSectors: 239 * 1024 * 1024 / 512,
            clusterSize: 196352,
            totalClusters: 128,
            maxBanks: 90,
            bntOffset: 0x1200,
            fatOffset: 0x400,
            clusterAreaStartSector: 24,
            bootSignature: withBoot ? (0xA1, 0x93) : (0x00, 0x00)
        )
        let fat = FATSummary(
            totalEntries: 512,
            usedClusters: 128 - freeClusters - 1,
            freeClusters: freeClusters,
            reservedClusters: 1
        )
        var banks = [DiskBankInfo]()
        for i in 0..<bankCount {
            banks.append(DiskBankInfo(
                catalogIndex: i + 1,
                name: "BANK\(i + 1)",
                startCluster: UInt16(5 + i * 2),
                clusterCount: 2,
                sizeBytes: 2 * 196352,
                fatChain: [5 + i * 2, 6 + i * 2],
                fatChainValid: true,
                flags: 0x0081
            ))
        }
        let os: DiskOSInfo? = includeOS ? DiskOSInfo(
            versionString: "v1.30",
            startCluster: 1,
            clusterChain: [1, 2, 3, 4],
            sizeBytes: 4 * 196352
        ) : nil
        return DiskInspection(header: header, fat: fat, banks: banks, os: os, health: health)
    }

    // MARK: - File extension helper

    func testFileExtensionHTML() {
        XCTAssertEqual(DiskReportGenerator.fileExtension(for: .html), "html")
    }

    func testFileExtensionText() {
        XCTAssertEqual(DiskReportGenerator.fileExtension(for: .text), "txt")
    }

    func testFileExtensionCSV() {
        XCTAssertEqual(DiskReportGenerator.fileExtension(for: .csv), "csv")
    }

    // MARK: - HTML output

    func testHTMLContainsDoctype() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(), diskName: "HD0.hda", format: .html)
        XCTAssertTrue(report.contains("<!DOCTYPE html>"), "Missing DOCTYPE")
    }

    func testHTMLContainsDiskName() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(), diskName: "HD0.hda", format: .html)
        XCTAssertTrue(report.contains("HD0.hda"), "Disk name missing from HTML")
    }

    func testHTMLContainsBankNames() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(bankCount: 2), diskName: "TEST.hda", format: .html)
        XCTAssertTrue(report.contains("BANK1"), "BANK1 missing from HTML")
        XCTAssertTrue(report.contains("BANK2"), "BANK2 missing from HTML")
    }

    func testHTMLEscapesDiskName() {
        // Disk name with HTML-special characters must be escaped
        let report = DiskReportGenerator.generate(
            from: makeInspection(), diskName: "<MyDisk> & \"Test\"", format: .html)
        XCTAssertFalse(report.contains("<MyDisk>"), "Unescaped < > in HTML output")
        XCTAssertTrue(report.contains("&lt;MyDisk&gt;"), "HTML escaping not applied")
    }

    func testHTMLShowsBootYesWhenBoot() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(withBoot: true), diskName: "boot.hda", format: .html)
        XCTAssertTrue(report.contains("Yes"), "Boot disk indicator missing")
    }

    func testHTMLShowsBootNoWhenNoBoot() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(withBoot: false), diskName: "data.hda", format: .html)
        XCTAssertTrue(report.contains("No"), "Non-boot indicator missing")
    }

    func testHTMLIncludesFATSummary() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(freeClusters: 42), diskName: "D.hda", format: .html)
        XCTAssertTrue(report.contains("FAT"), "FAT section missing from HTML")
        XCTAssertTrue(report.contains("42"), "Free cluster count missing")
    }

    func testHTMLOmitsFATWhenDisabled() {
        var opts = DiskReportGenerator.ReportOptions()
        opts.includeFATSummary = false
        let report = DiskReportGenerator.generate(
            from: makeInspection(), diskName: "D.hda", format: .html, options: opts)
        // FAT SUMMARY heading should not appear
        XCTAssertFalse(report.contains("FAT Summary"), "FAT section should be omitted")
    }

    func testHTMLIncludesOSInfoWhenPresent() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(includeOS: true), diskName: "boot.hda", format: .html)
        XCTAssertTrue(report.contains("OS"), "OS section missing")
        XCTAssertTrue(report.contains("v1.30"), "OS version missing")
    }

    func testHTMLOmitsOSWhenAbsent() {
        var opts = DiskReportGenerator.ReportOptions()
        opts.includeOSInfo = true  // enabled, but no OS in inspection
        let report = DiskReportGenerator.generate(
            from: makeInspection(includeOS: false), diskName: "D.hda", format: .html, options: opts)
        XCTAssertFalse(report.contains("OS size"), "OS section should not appear when OS is nil")
    }

    func testHTMLShowsHealthWarnings() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(health: [.missingBootSignature]),
            diskName: "D.hda", format: .html)
        XCTAssertTrue(report.contains("boot signature"), "Health warning text missing")
    }

    func testHTMLNoWarningsSectionWhenClean() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(health: []),
            diskName: "D.hda", format: .html)
        // No h2 "Health Warnings" when warnings array is empty
        XCTAssertFalse(report.contains("<h2>Health Warnings</h2>"))
    }

    func testHTMLEmptyBankListMessage() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(bankCount: 0), diskName: "empty.hda", format: .html)
        XCTAssertTrue(report.contains("no user banks") || report.contains("No user banks"),
                      "Empty bank message missing")
    }

    func testHTMLNoBankDetailWhenDisabled() {
        var opts = DiskReportGenerator.ReportOptions()
        opts.includeBankDetails = false
        let report = DiskReportGenerator.generate(
            from: makeInspection(bankCount: 2), diskName: "D.hda", format: .html, options: opts)
        XCTAssertFalse(report.contains("BANK1"), "Banks should be omitted when includeBankDetails=false")
    }

    func testHTMLIsWellFormed() {
        // Basic well-formedness: must start with <!DOCTYPE and end with </html>
        let report = DiskReportGenerator.generate(
            from: makeInspection(bankCount: 3, includeOS: true, withBoot: true),
            diskName: "D.hda", format: .html)
        XCTAssertTrue(report.hasPrefix("<!DOCTYPE html>"), "HTML must start with DOCTYPE")
        XCTAssertTrue(report.contains("</html>"), "HTML must end with closing tag")
    }

    // MARK: - Plain text output

    func testTextContainsDiskName() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(), diskName: "MyDisk.hda", format: .text)
        XCTAssertTrue(report.contains("MyDisk.hda"), "Disk name missing from text report")
    }

    func testTextContainsBankNames() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(bankCount: 2), diskName: "D.hda", format: .text)
        XCTAssertTrue(report.contains("BANK1"))
        XCTAssertTrue(report.contains("BANK2"))
    }

    func testTextContainsFATSummarySection() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(freeClusters: 77), diskName: "D.hda", format: .text)
        XCTAssertTrue(report.contains("FAT"))
        XCTAssertTrue(report.contains("77"), "Free cluster count missing from text")
    }

    func testTextContainsOverviewSection() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(), diskName: "D.hda", format: .text)
        XCTAssertTrue(report.contains("OVERVIEW") || report.contains("Overview"))
    }

    func testTextSeparatorLines() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(), diskName: "D.hda", format: .text)
        // Must have horizontal rules (═══ or ───)
        XCTAssertTrue(report.contains("═══") || report.contains("───"))
    }

    func testTextShowsHealthWarning() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(health: [.brokenFATChain(bankName: "BASS", startCluster: 10)]),
            diskName: "D.hda", format: .text)
        XCTAssertTrue(report.contains("BASS"), "Broken chain bank name missing")
        XCTAssertTrue(report.contains("10"),   "Broken chain cluster missing")
    }

    func testTextOSSection() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(includeOS: true), diskName: "D.hda", format: .text)
        XCTAssertTrue(report.contains("OS") || report.contains("os"))
        XCTAssertTrue(report.contains("v1.30"))
    }

    // MARK: - CSV output

    func testCSVContainsHeader() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(bankCount: 1), diskName: "D.hda", format: .csv)
        XCTAssertTrue(report.contains("Index,Name,StartCluster,ClusterCount,SizeBytes,FATChainValid"),
                      "CSV header row missing")
    }

    func testCSVRowsMatchBankCount() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(bankCount: 3), diskName: "D.hda", format: .csv)
        let dataLines = report.split(separator: "\n")
            .filter { !$0.hasPrefix("#") && !$0.isEmpty && !$0.hasPrefix("Index") }
        XCTAssertEqual(dataLines.count, 3, "CSV should have 3 data rows for 3 banks")
    }

    func testCSVContainsBankName() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(bankCount: 1), diskName: "D.hda", format: .csv)
        XCTAssertTrue(report.contains("BANK1"))
    }

    func testCSVContainsMetadataComments() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(), diskName: "HD0.hda", format: .csv)
        XCTAssertTrue(report.contains("# EMAX II Disk Report"), "Metadata header missing")
        XCTAssertTrue(report.contains("HD0.hda"), "Disk name missing from CSV metadata")
    }

    func testCSVFieldsAreCommaSeparated() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(bankCount: 1), diskName: "D.hda", format: .csv)
        let dataLine = report.split(separator: "\n")
            .first(where: { $0.hasPrefix("1,") })?.description ?? ""
        let fields = dataLine.split(separator: ",", omittingEmptySubsequences: false)
        XCTAssertEqual(fields.count, 6, "Each bank row must have 6 comma-separated fields")
    }

    func testCSVEscapesNamesWithCommas() {
        // Build inspection with a bank name containing a comma
        var insp = makeInspection(bankCount: 0)
        let commaBank = DiskBankInfo(
            catalogIndex: 1, name: "BASS,LOW",
            startCluster: 5, clusterCount: 1, sizeBytes: 196352,
            fatChain: [5], fatChainValid: true, flags: 0x0081)
        let insp2 = DiskInspection(header: insp.header, fat: insp.fat,
                                   banks: [commaBank], os: insp.os, health: insp.health)
        let report = DiskReportGenerator.generate(from: insp2, diskName: "D.hda", format: .csv)
        // CSV-escaped name "BASS,LOW" should be wrapped in quotes
        XCTAssertTrue(report.contains("\"BASS,LOW\""), "Comma in name must be CSV-quoted")
    }

    func testCSVEmptyBankListHasNoDataRows() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(bankCount: 0), diskName: "D.hda", format: .csv)
        let dataLines = report.split(separator: "\n")
            .filter { !$0.hasPrefix("#") && !$0.isEmpty && !$0.hasPrefix("Index") }
        XCTAssertEqual(dataLines.count, 0)
    }

    func testCSVFATChainsReportedAsTrueOrFalse() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(bankCount: 1), diskName: "D.hda", format: .csv)
        XCTAssertTrue(report.contains("true") || report.contains("false"),
                      "FATChainValid column should be 'true' or 'false'")
    }

    // MARK: - Write to file

    func testWriteHTMLToFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReportTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        let outURL = dir.appendingPathComponent("report.html")
        try DiskReportGenerator.write(
            from: makeInspection(), diskName: "test.hda", format: .html, to: outURL)

        let written = try String(contentsOf: outURL, encoding: .utf8)
        XCTAssertTrue(written.contains("<!DOCTYPE html>"))
        XCTAssertTrue(written.contains("test.hda"))
    }

    func testWriteCSVToFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReportTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        let outURL = dir.appendingPathComponent("report.csv")
        try DiskReportGenerator.write(
            from: makeInspection(bankCount: 2), diskName: "test.hda", format: .csv, to: outURL)

        let written = try String(contentsOf: outURL, encoding: .utf8)
        XCTAssertTrue(written.contains("Index,Name"))
        XCTAssertTrue(written.contains("BANK1"))
    }

    // MARK: - Orphan/duplicate cluster warning text

    func testOrphanClusterWarningText() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(health: [.orphanClusters([7, 8, 9])]),
            diskName: "D.hda", format: .text)
        XCTAssertTrue(report.contains("Orphan") || report.contains("orphan"))
    }

    func testDuplicateClusterWarningText() {
        let report = DiskReportGenerator.generate(
            from: makeInspection(health: [.duplicateAllocations(clusters: [5])]),
            diskName: "D.hda", format: .text)
        XCTAssertTrue(report.contains("Duplicate") || report.contains("duplicate"))
    }
}
