import SwiftUI
import UniformTypeIdentifiers

// MARK: - Models

enum ClusterState {
    case free, used, reserved, error

    var color: Color {
        switch self {
        case .free:     return Color.gray.opacity(0.25)
        case .used:     return Theme.accent.opacity(0.8)
        case .reserved: return Theme.amber.opacity(0.8)
        case .error:    return Theme.danger
        }
    }
}

struct FATAnalysis {
    let entry0Hex: String
    let entry0Valid: Bool
    let entry1Hex: String
    let freeClusters: Int
    let usedClusters: Int
    let totalClusters: Int
    let fragmentationPercent: Double
    let errors: [String]
    let warnings: [String]
    let clusterStates: [ClusterState]
}

// MARK: - FAT Analyzer Service

private enum FATAnalyzer {
    static func analyze(image: URL) async throws -> FATAnalysis {
        let data = try Data(contentsOf: image)
        guard data.count >= 0x2000 else {
            throw NSError(domain: "FATAnalyzer", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "File too small to be a valid disk image"])
        }

        // FAT ALWAYS at 0x400 (sector 2) for EMAX II — verified against all EMXP templates
        let fatOffset = 0x400
        let fatEntryCount = 512
        var fat = [UInt16]()
        fat.reserveCapacity(fatEntryCount)

        for i in 0..<fatEntryCount {
            let off = fatOffset + i * 2
            guard off + 2 <= data.count else { break }
            let val = data.withUnsafeBytes { ptr -> UInt16 in
                ptr.loadUnaligned(fromByteOffset: off, as: UInt16.self)
            }
            fat.append(val)
        }

        let entry0 = fat.count > 0 ? fat[0] : 0
        let entry1 = fat.count > 1 ? fat[1] : 0
        let entry0Valid = (entry0 == 0x8000 || entry0 == 0x000F)

        var freeClusters = 0
        var usedClusters = 0
        var clusterStates = [ClusterState]()
        var errors = [String]()
        var warnings = [String]()

        // Detect broken chains
        var visited = Set<Int>()
        func followChain(_ start: Int) -> Bool {
            var cur = start
            var steps = 0
            while cur < fat.count && steps < fat.count {
                if visited.contains(cur) { return false } // loop
                visited.insert(cur)
                let next = Int(fat[cur])
                if next == 0x0000 { return true } // end (free?)
                if next == 0xFFFF || next == 0x0001 { return true } // end-of-chain
                if next >= fat.count { return false } // out of range
                cur = next
                steps += 1
            }
            return false
        }

        for i in 2..<fat.count {
            let val = fat[i]
            if val == 0x0000 {
                freeClusters += 1
                clusterStates.append(.free)
            } else if val == 0xFFFF || val == 0x0001 {
                usedClusters += 1
                clusterStates.append(.used)
            } else if val >= UInt16(fat.count) {
                errors.append("Cluster \(i): invalid FAT entry 0x\(String(val, radix: 16, uppercase: true))")
                clusterStates.append(.error)
            } else {
                usedClusters += 1
                clusterStates.append(.used)
            }
        }

        // Check for chain loops
        var chainStarts = Set<Int>()
        for i in 2..<fat.count {
            let val = Int(fat[i])
            if val > 1 && val < fat.count {
                chainStarts.insert(i)
            }
        }
        for start in chainStarts.prefix(20) {
            if !followChain(start) {
                errors.append("Chain starting at cluster \(start) has a loop or broken link")
            }
        }

        if !entry0Valid {
            warnings.append("FAT entry 0 is 0x\(String(entry0, radix: 16, uppercase: true)) (expected 0x8000)")
        }
        if entry1 == 0 {
            warnings.append("FAT entry 1 is zero — disk may not be formatted")
        }

        let totalClusters = freeClusters + usedClusters
        let fragPct = totalClusters > 0 ? Double(errors.count) / Double(totalClusters) * 100 : 0

        return FATAnalysis(
            entry0Hex: "0x" + String(entry0, radix: 16, uppercase: true).paddingLeft(4, "0"),
            entry0Valid: entry0Valid,
            entry1Hex: "0x" + String(entry1, radix: 16, uppercase: true).paddingLeft(4, "0"),
            freeClusters: freeClusters,
            usedClusters: usedClusters,
            totalClusters: totalClusters,
            fragmentationPercent: fragPct,
            errors: errors,
            warnings: warnings,
            clusterStates: clusterStates
        )
    }
}

// MARK: - Main View

struct FATAnalyzerView: View {
    @Environment(\.dismiss) var dismiss

    @State private var selectedImage: URL?
    @State private var analysisResult: FATAnalysis?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "FAT Structure Analysis",
                subtitle: "Diagnose File Allocation Table issues",
                icon: "tablecells",
                onClose: { dismiss() }
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    filePickerSection
                    if isAnalyzing { analyzingSection }
                    if let result = analysisResult { FATResultsView(result: result) }
                    if let err = errorMessage { errorSection(err) }
                }
                .padding()
            }

            Divider()

            footerButtons
        }
        .frame(width: 640, height: 560)
        .onExitCommand { dismiss() }
    }

    // MARK: - Sections

    private var filePickerSection: some View {
        Group {
            if let url = selectedImage {
                HStack(spacing: 10) {
                    Image(systemName: "internaldrive")
                        .foregroundStyle(Theme.accent)
                    Text(url.lastPathComponent)
                        .font(Theme.Typography.body)
                    Spacer()
                    Button("Change…") { pickImage() }
                        .buttonStyle(.bordered)
                }
                .padding(12)
                .background(Theme.bgCard)
                .cornerRadius(8)
            } else {
                Button {
                    pickImage()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Select Disk Image (.hda)…")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var analyzingSection: some View {
        HStack(spacing: 12) {
            ProgressView().scaleEffect(0.8)
            Text("Analyzing FAT structure…")
                .font(Theme.Typography.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func errorSection(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.danger)
            Text(msg).font(Theme.Typography.body).foregroundStyle(Theme.danger)
        }
        .padding(12)
        .background(Theme.danger.opacity(0.1))
        .cornerRadius(8)
    }

    private var footerButtons: some View {
        HStack(spacing: 12) {
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Spacer()
            if analysisResult != nil {
                Button("Export Report…") { exportReport() }
                    .buttonStyle(.bordered)
            }
            Button("Analyze") { performAnalysis() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(selectedImage == nil || isAnalyzing)
                .keyboardShortcut(.defaultAction)
        }
        .padding()
    }

    // MARK: - Actions

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "hda")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK { selectedImage = panel.url }
    }

    private func performAnalysis() {
        guard let url = selectedImage else { return }
        isAnalyzing = true
        errorMessage = nil
        analysisResult = nil
        Task {
            do {
                let result = try await FATAnalyzer.analyze(image: url)
                await MainActor.run {
                    analysisResult = result
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isAnalyzing = false
                }
            }
        }
    }

    private func exportReport() {
        guard let result = analysisResult, let url = selectedImage else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = url.deletingPathExtension().lastPathComponent + "_fat_report.json"
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        let report: [String: Any] = [
            "image": url.lastPathComponent,
            "entry0": result.entry0Hex,
            "entry0Valid": result.entry0Valid,
            "entry1": result.entry1Hex,
            "freeClusters": result.freeClusters,
            "usedClusters": result.usedClusters,
            "fragmentationPercent": result.fragmentationPercent,
            "errors": result.errors,
            "warnings": result.warnings
        ]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: .prettyPrinted) {
            try? data.write(to: dest)
        }
    }
}

// MARK: - Results View

struct FATResultsView: View {
    let result: FATAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Summary grid
            summarySection

            // Warnings
            if !result.warnings.isEmpty {
                issueSection(title: "Warnings", items: result.warnings,
                             icon: "exclamationmark.triangle.fill", color: Theme.amber)
            }

            // Errors
            if !result.errors.isEmpty {
                issueSection(title: "Errors", items: result.errors,
                             icon: "xmark.circle.fill", color: Theme.danger)
            }

            // FAT map
            fatMapSection
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUMMARY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1)

            VStack(spacing: 0) {
                summaryRow("FAT Entry 0", value: result.entry0Hex,
                           valueColor: result.entry0Valid ? Theme.success : Theme.danger,
                           badge: result.entry0Valid ? "Valid" : "Invalid",
                           badgeColor: result.entry0Valid ? Theme.success : Theme.danger)
                Divider()
                summaryRow("FAT Entry 1", value: result.entry1Hex, valueColor: .primary)
                Divider()
                summaryRow("Free Clusters", value: "\(result.freeClusters)", valueColor: .primary)
                Divider()
                summaryRow("Used Clusters", value: "\(result.usedClusters)", valueColor: .primary)
                Divider()
                summaryRow("Fragmentation", value: String(format: "%.1f%%", result.fragmentationPercent),
                           valueColor: result.fragmentationPercent > 30 ? Theme.warning : Theme.success)
            }
            .background(Theme.bgCard)
            .cornerRadius(8)
        }
    }

    private func summaryRow(_ label: String, value: String, valueColor: Color,
                             badge: String? = nil, badgeColor: Color = .clear) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(Theme.Typography.body)
                .foregroundStyle(.secondary)
                .frame(width: 160, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(valueColor)
            if let badge = badge {
                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeColor)
                    .cornerRadius(4)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func issueSection(title: String, items: [String], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items.prefix(10), id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: icon).foregroundStyle(color).font(.caption)
                        Text(item).font(Theme.Typography.caption).foregroundStyle(.primary)
                    }
                }
                if items.count > 10 {
                    Text("… and \(items.count - 10) more")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(color.opacity(0.08))
            .cornerRadius(8)
        }
    }

    private var fatMapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FAT MAP")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()
                HStack(spacing: 12) {
                    legendDot(.free, "Free")
                    legendDot(.used, "Used")
                    legendDot(.reserved, "Reserved")
                    legendDot(.error, "Error")
                }
            }
            FATMapView(clusters: result.clusterStates)
        }
    }

    private func legendDot(_ state: ClusterState, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(state.color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
}

// MARK: - FAT Map Grid

struct FATMapView: View {
    let clusters: [ClusterState]

    private let cols = 32

    var body: some View {
        let rows = max(1, (clusters.count + cols - 1) / cols)
        VStack(spacing: 2) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<cols, id: \.self) { col in
                        let idx = row * cols + col
                        if idx < clusters.count {
                            Rectangle()
                                .fill(clusters[idx].color)
                                .frame(width: 14, height: 14)
                                .cornerRadius(2)
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 14, height: 14)
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(Theme.bgCard)
        .cornerRadius(8)
    }
}

// MARK: - String helper

private extension String {
    func paddingLeft(_ length: Int, _ pad: Character) -> String {
        let deficit = length - count
        guard deficit > 0 else { return self }
        return String(repeating: pad, count: deficit) + self
    }
}
