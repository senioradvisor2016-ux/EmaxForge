import Foundation

/// Generate HTML, plain-text, and CSV disk reports — closing the EMXP feature gap.
///
/// standard tools's "Create Bank/Preset Overview Report" functionality matched by this service.
/// All output is built from `DiskInspection` data produced by `DiskInspectorService`,
/// so no additional disk I/O is required after the initial inspection.
///
/// Usage:
/// ```swift
/// let inspection = try DiskInspectorService.inspectDisk(at: imageURL)
/// let html  = DiskReportGenerator.generate(from: inspection, diskName: "HD0.hda", format: .html)
/// let txt   = DiskReportGenerator.generate(from: inspection, diskName: "HD0.hda", format: .text)
/// let csv   = DiskReportGenerator.generate(from: inspection, diskName: "HD0.hda", format: .csv)
/// ```
enum DiskReportGenerator {

    // MARK: - Public types

    enum OutputFormat {
        case html
        case text
        case csv
    }

    struct ReportOptions {
        /// Include per-bank size and cluster information
        var includeBankDetails: Bool = true
        /// Include FAT usage summary
        var includeFATSummary: Bool = true
        /// Include health warnings section
        var includeHealthWarnings: Bool = true
        /// Include OS information section
        var includeOSInfo: Bool = true
        /// Timestamp to embed in report header (default: current date)
        var timestamp: Date = Date()
    }

    // MARK: - Main entry point

    /// Generate a formatted disk report.
    ///
    /// - Parameters:
    ///   - inspection: Pre-computed disk inspection result
    ///   - diskName: Human-readable disk name (e.g. file name)
    ///   - format: Output format (.html / .text / .csv)
    ///   - options: Report customisation options
    /// - Returns: Formatted report string
    static func generate(
        from inspection: DiskInspection,
        diskName: String,
        format: OutputFormat,
        options: ReportOptions = ReportOptions()
    ) -> String {
        switch format {
        case .html:  return generateHTML(inspection, diskName: diskName, options: options)
        case .text:  return generateText(inspection, diskName: diskName, options: options)
        case .csv:   return generateCSV(inspection, diskName: diskName, options: options)
        }
    }

    /// Convenience: generate and write report to a URL.
    static func write(
        from inspection: DiskInspection,
        diskName: String,
        format: OutputFormat,
        to outputURL: URL,
        options: ReportOptions = ReportOptions()
    ) throws {
        let content = generate(from: inspection, diskName: diskName, format: format, options: options)
        try content.write(to: outputURL, atomically: true, encoding: .utf8)
    }

    // MARK: - File-extension helper

    /// Returns the canonical file extension for a given output format.
    static func fileExtension(for format: OutputFormat) -> String {
        switch format {
        case .html: return "html"
        case .text: return "txt"
        case .csv:  return "csv"
        }
    }

    // MARK: - HTML generator

    private static func generateHTML(
        _ d: DiskInspection,
        diskName: String,
        options: ReportOptions
    ) -> String {
        let dateStr = isoDate(options.timestamp)
        var lines = [String]()

        lines.append("<!DOCTYPE html>")
        lines.append("<html lang=\"en\">")
        lines.append("<head>")
        lines.append("  <meta charset=\"UTF-8\">")
        lines.append("  <title>EMAX II Disk Report — \(htmlEsc(diskName))</title>")
        lines.append("  <style>")
        lines.append("    body { font-family: monospace; margin: 2em; background: #1a1a1a; color: #e0e0e0; }")
        lines.append("    h1   { color: #7ec8e3; border-bottom: 1px solid #444; padding-bottom: .3em; }")
        lines.append("    h2   { color: #aef; margin-top: 2em; }")
        lines.append("    table { border-collapse: collapse; width: 100%; margin-top: .8em; }")
        lines.append("    th   { background: #333; padding: 6px 12px; text-align: left; color: #7ec8e3; }")
        lines.append("    td   { padding: 5px 12px; border-bottom: 1px solid #2d2d2d; }")
        lines.append("    tr:hover td { background: #222; }")
        lines.append("    .ok  { color: #6f6; } .warn { color: #fa0; } .err { color: #f66; }")
        lines.append("    .meta { color: #888; font-size: .9em; }")
        lines.append("  </style>")
        lines.append("</head>")
        lines.append("<body>")

        lines.append("<h1>EMAX II Disk Report</h1>")
        lines.append("<p class=\"meta\">Generated: \(dateStr) &nbsp;|&nbsp; Disk: <strong>\(htmlEsc(diskName))</strong></p>")

        // --- Overview ---
        lines.append("<h2>Disk Overview</h2>")
        lines.append("<table>")
        lines.append("  <tr><th>Field</th><th>Value</th></tr>")
        lines.append("  <tr><td>Image size</td><td>\(bytesFmt(d.header.imageSize))</td></tr>")
        lines.append("  <tr><td>Cluster size</td><td>\(bytesFmt(d.header.clusterSize))</td></tr>")
        lines.append("  <tr><td>Total clusters</td><td>\(d.header.totalClusters)</td></tr>")
        lines.append("  <tr><td>Banks (max)</td><td>\(d.banks.count) / \(d.header.maxBanks)</td></tr>")
        let hasBoot = d.header.bootSignature.0 == 0xA1 && d.header.bootSignature.1 == 0x93
        lines.append("  <tr><td>Boot disk</td><td class=\"\(hasBoot ? "ok" : "meta")\">\(hasBoot ? "✓ Yes" : "No")</td></tr>")
        lines.append("</table>")

        // --- FAT summary ---
        if options.includeFATSummary {
            lines.append("<h2>FAT Summary</h2>")
            lines.append("<table>")
            lines.append("  <tr><th>Metric</th><th>Count</th></tr>")
            lines.append("  <tr><td>Used clusters</td><td>\(d.fat.usedClusters)</td></tr>")
            lines.append("  <tr><td>Free clusters</td><td>\(d.fat.freeClusters)</td></tr>")
            lines.append("  <tr><td>Reserved clusters</td><td>\(d.fat.reservedClusters)</td></tr>")
            let freeBytes = d.fat.freeClusters * d.header.clusterSize
            lines.append("  <tr><td>Free space</td><td>\(bytesFmt(freeBytes))</td></tr>")
            lines.append("</table>")
        }

        // --- OS info ---
        if options.includeOSInfo, let os = d.os {
            lines.append("<h2>OS Information</h2>")
            lines.append("<table>")
            lines.append("  <tr><th>Field</th><th>Value</th></tr>")
            lines.append("  <tr><td>Start cluster</td><td>\(os.startCluster)</td></tr>")
            lines.append("  <tr><td>Cluster chain</td><td>\(os.clusterChain.count) clusters</td></tr>")
            lines.append("  <tr><td>OS size</td><td>\(bytesFmt(os.sizeBytes))</td></tr>")
            if let ver = os.versionString {
                lines.append("  <tr><td>Version</td><td>\(htmlEsc(ver))</td></tr>")
            }
            lines.append("</table>")
        }

        // --- Banks ---
        if options.includeBankDetails {
            lines.append("<h2>Banks (\(d.banks.count))</h2>")
            if d.banks.isEmpty {
                lines.append("<p class=\"meta\">No user banks found.</p>")
            } else {
                lines.append("<table>")
                lines.append("  <tr><th>#</th><th>Name</th><th>Start Cluster</th><th>Clusters</th><th>Size</th><th>FAT Chain</th></tr>")
                for (i, bank) in d.banks.enumerated() {
                    let chainCls = bank.fatChainValid ? "ok" : "err"
                    let chainStr = bank.fatChainValid ? "✓ Valid" : "⚠ Invalid"
                    lines.append("  <tr>")
                    lines.append("    <td>\(i + 1)</td>")
                    lines.append("    <td>\(htmlEsc(bank.name))</td>")
                    lines.append("    <td>\(bank.startCluster)</td>")
                    lines.append("    <td>\(bank.clusterCount)</td>")
                    lines.append("    <td>\(bytesFmt(bank.sizeBytes))</td>")
                    lines.append("    <td class=\"\(chainCls)\">\(chainStr)</td>")
                    lines.append("  </tr>")
                }
                lines.append("</table>")
            }
        }

        // --- Health warnings ---
        if options.includeHealthWarnings && !d.health.isEmpty {
            lines.append("<h2>Health Warnings</h2>")
            lines.append("<ul>")
            for warning in d.health {
                lines.append("  <li class=\"warn\">\(htmlEsc(warningText(warning)))</li>")
            }
            lines.append("</ul>")
        }

        lines.append("</body>")
        lines.append("</html>")
        return lines.joined(separator: "\n")
    }

    // MARK: - Plain text generator

    private static func generateText(
        _ d: DiskInspection,
        diskName: String,
        options: ReportOptions
    ) -> String {
        let dateStr = isoDate(options.timestamp)
        var lines = [String]()

        lines.append("═══════════════════════════════════════════════")
        lines.append(" EMAX II Disk Report")
        lines.append(" Disk:      \(diskName)")
        lines.append(" Generated: \(dateStr)")
        lines.append("═══════════════════════════════════════════════")
        lines.append("")

        // Overview
        lines.append("DISK OVERVIEW")
        lines.append("─────────────")
        lines.append("  Image size   : \(bytesFmt(d.header.imageSize))")
        lines.append("  Cluster size : \(bytesFmt(d.header.clusterSize))")
        lines.append("  Total clusters: \(d.header.totalClusters)")
        lines.append("  Banks        : \(d.banks.count) / \(d.header.maxBanks)")
        let hasBoot = d.header.bootSignature.0 == 0xA1 && d.header.bootSignature.1 == 0x93
        lines.append("  Boot disk    : \(hasBoot ? "Yes" : "No")")
        lines.append("")

        // FAT summary
        if options.includeFATSummary {
            lines.append("FAT SUMMARY")
            lines.append("───────────")
            lines.append("  Used clusters  : \(d.fat.usedClusters)")
            lines.append("  Free clusters  : \(d.fat.freeClusters)")
            lines.append("  Free space     : \(bytesFmt(d.fat.freeClusters * d.header.clusterSize))")
            lines.append("  Reserved       : \(d.fat.reservedClusters)")
            lines.append("")
        }

        // OS info
        if options.includeOSInfo, let os = d.os {
            lines.append("OS INFORMATION")
            lines.append("──────────────")
            lines.append("  Start cluster  : \(os.startCluster)")
            lines.append("  Cluster count  : \(os.clusterChain.count)")
            lines.append("  OS size        : \(bytesFmt(os.sizeBytes))")
            if let ver = os.versionString { lines.append("  Version        : \(ver)") }
            lines.append("")
        }

        // Banks
        if options.includeBankDetails {
            lines.append("BANKS (\(d.banks.count))")
            lines.append("──────────────────────────────────────────────")
            if d.banks.isEmpty {
                lines.append("  (no user banks)")
            } else {
                let n = 16  // name column width
                let hdr = "Name".padding(toLength: n, withPad: " ", startingAt: 0)
                lines.append("  \(hdr)   Clust    ClustCnt          Size  Chain")
                lines.append("  " + String(repeating: "─", count: 60))
                for bank in d.banks {
                    let chain   = bank.fatChainValid ? "ok" : "INVALID"
                    let namePad = bank.name.padding(toLength: n, withPad: " ", startingAt: 0)
                    let clust   = leftPad(String(bank.startCluster), width: 6)
                    let cnt     = leftPad(String(bank.clusterCount), width: 9)
                    let sz      = leftPad(bytesFmt(bank.sizeBytes), width: 12)
                    lines.append("  \(namePad)  \(clust)  \(cnt)  \(sz)  \(chain)")
                }
            }
            lines.append("")
        }

        // Health warnings
        if options.includeHealthWarnings && !d.health.isEmpty {
            lines.append("HEALTH WARNINGS")
            lines.append("───────────────")
            for w in d.health {
                lines.append("  ⚠️  \(warningText(w))")
            }
            lines.append("")
        }

        lines.append("═══════════════════════════════════════════════")
        return lines.joined(separator: "\n")
    }

    // MARK: - CSV generator

    private static func generateCSV(
        _ d: DiskInspection,
        diskName: String,
        options: ReportOptions
    ) -> String {
        var lines = [String]()

        // Metadata header block
        lines.append("# EMAX II Disk Report")
        lines.append("# Disk,\(csvEsc(diskName))")
        lines.append("# Generated,\(isoDate(options.timestamp))")
        lines.append("# Image size bytes,\(d.header.imageSize)")
        lines.append("# Cluster size bytes,\(d.header.clusterSize)")
        lines.append("# Total clusters,\(d.header.totalClusters)")
        lines.append("# Bank count,\(d.banks.count)")
        lines.append("# Max banks,\(d.header.maxBanks)")
        lines.append("# Free clusters,\(d.fat.freeClusters)")
        lines.append("# Free bytes,\(d.fat.freeClusters * d.header.clusterSize)")
        lines.append("")

        // Banks table
        lines.append("Index,Name,StartCluster,ClusterCount,SizeBytes,FATChainValid")
        for (i, bank) in d.banks.enumerated() {
            let cols: [String] = [
                "\(i + 1)",
                csvEsc(bank.name),
                "\(bank.startCluster)",
                "\(bank.clusterCount)",
                "\(bank.sizeBytes)",
                bank.fatChainValid ? "true" : "false"
            ]
            lines.append(cols.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Formatting helpers

    private static func leftPad(_ s: String, width: Int) -> String {
        s.count >= width ? s : String(repeating: " ", count: width - s.count) + s
    }

    private static func bytesFmt(_ bytes: Int) -> String {
        if bytes >= 1_048_576 {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576)
        } else if bytes >= 1024 {
            return String(format: "%.0f KB", Double(bytes) / 1024)
        } else {
            return "\(bytes) B"
        }
    }

    private static func isoDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.string(from: date)
    }

    private static func htmlEsc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func csvEsc(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return s
    }

    private static func warningText(_ warning: DiskHealthWarning) -> String {
        switch warning {
        case .missingBootSignature:
            return "Missing boot signature (0xA193) — disk may not boot on EMAX II hardware"
        case .brokenFATChain(let name, let cluster):
            return "Broken FAT chain for bank '\(name)' starting at cluster \(cluster)"
        case .orphanClusters(let clusters):
            return "Orphan clusters (allocated in FAT but unreferenced by BNT): \(clusters.prefix(5).map(String.init).joined(separator: ", "))\(clusters.count > 5 ? "..." : "")"
        case .duplicateAllocations(let clusters):
            return "Duplicate cluster allocations (same cluster in multiple chains): \(clusters.prefix(5).map(String.init).joined(separator: ", "))"
        }
    }
}
