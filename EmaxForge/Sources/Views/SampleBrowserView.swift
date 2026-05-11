import SwiftUI
import AppKit

/// Sample-centric browser showing all samples on disk
struct SampleBrowserView: View {
    let image: DiskImage

    @Environment(\.dismiss) private var dismiss
    @StateObject private var samplePlayer = SamplePlayer()

    @State private var samples: [SampleInfo] = []
    @State private var isAnalyzing = false
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .name
    @State private var showOrphansOnly = false
    @State private var selectedSample: Set<SampleInfo.ID> = []
    @State private var analysisResult: SampleAnalyzer.AnalysisResult?
    @State private var exportError: String? = nil

    enum SortOrder {
        case name, size, duration, bank, rate
    }
    
    private var filteredSamples: [SampleInfo] {
        samples
            .filter { sample in
                (searchText.isEmpty || sample.name.localizedCaseInsensitiveContains(searchText) ||
                 sample.bankName.localizedCaseInsensitiveContains(searchText)) &&
                (!showOrphansOnly || sample.isOrphan)
            }
            .sorted { lhs, rhs in
                switch sortOrder {
                case .name: return lhs.name < rhs.name
                case .size: return lhs.size > rhs.size
                case .duration: return lhs.duration > rhs.duration
                case .bank: return lhs.bankName < rhs.bankName
                case .rate: return lhs.sampleRate > rhs.sampleRate
                }
            }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search samples", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .frame(width: 250)
                
                Spacer()
                
                // Orphans filter
                Toggle("Orphans only", isOn: $showOrphansOnly)
                    .toggleStyle(.switch)
                
                Divider()
                    .frame(height: 20)
                
                // Sort picker
                Picker("Sort", selection: $sortOrder) {
                    Label("Name", systemImage: "textformat").tag(SortOrder.name)
                    Label("Size", systemImage: "arrow.up.arrow.down").tag(SortOrder.size)
                    Label("Duration", systemImage: "clock").tag(SortOrder.duration)
                    Label("Bank", systemImage: "square.stack").tag(SortOrder.bank)
                    Label("Rate", systemImage: "waveform").tag(SortOrder.rate)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                
                // Stop playback button (visible when previewing)
                if samplePlayer.isPlaying {
                    Button {
                        samplePlayer.stop()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            
            Divider()
            
            // Content
            if isAnalyzing {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Analyzing samples...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if samples.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "waveform.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No samples found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Sample table
                Table(filteredSamples, selection: $selectedSample) {
                    TableColumn("Name") { sample in
                        HStack(spacing: 8) {
                            Image(systemName: "waveform")
                                .foregroundColor(sample.isOrphan ? .orange : .blue)
                            Text(sample.name)
                        }
                    }
                    .width(min: 150, ideal: 200)
                    
                    TableColumn("Bank") { sample in
                        Text(sample.bankName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .width(min: 100, ideal: 150)
                    
                    TableColumn("Size") { sample in
                        Text(sample.formattedSize)
                            .font(.caption.monospacedDigit())
                    }
                    .width(min: 70, ideal: 90)
                    
                    TableColumn("Format") { sample in
                        Text(sample.formatDescription)
                            .font(.caption)
                    }
                    .width(min: 60, ideal: 70)
                    
                    TableColumn("Rate") { sample in
                        Text(sample.formattedRate)
                            .font(.caption.monospacedDigit())
                    }
                    .width(min: 80, ideal: 100)
                    
                    TableColumn("Duration") { sample in
                        Text(sample.formattedDuration)
                            .font(.caption.monospacedDigit())
                    }
                    .width(min: 80, ideal: 100)
                    
                    TableColumn("Loop") { sample in
                        if sample.hasLoop {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "minus")
                                .foregroundColor(.secondary)
                        }
                    }
                    .width(ideal: 50)
                    
                    TableColumn("Status") { sample in
                        if sample.isOrphan {
                            Label("Orphan", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Label("Used", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .width(min: 80, ideal: 100)
                }
                .contextMenu(forSelectionType: SampleInfo.ID.self) { selection in
                    if !selection.isEmpty {
                        Button(samplePlayer.isPlaying ? "Stop Preview" : "Preview") {
                            let found = samples.filter { selection.contains($0.id) }
                            guard let first = found.first else { return }
                            samplePlayer.togglePlayback(
                                pcmData: first.pcmData,
                                sampleRate: Double(first.sampleRate)
                            )
                        }
                        Button("Extract as WAV...") {
                            Task { await extractAsWAV(ids: selection) }
                        }
                        Divider()
                        Button("Copy Name") { copyNames(selection) }
                    }
                }
            }
            
            Divider()
            
            // Status bar
            HStack(spacing: 16) {
                if let result = analysisResult {
                    Label("\(samples.count) samples", systemImage: "waveform")
                    Text("•")
                        .foregroundColor(.secondary)
                    Label(result.formattedTotalSize, systemImage: "internaldrive")
                    
                    if result.orphanCount > 0 {
                        Text("•")
                            .foregroundColor(.secondary)
                        Label("\(result.orphanCount) orphaned", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(String(format: "Avg: %.1fs", result.averageDuration))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !filteredSamples.isEmpty {
                    Text("\(filteredSamples.count) visible")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.05))
        }
        .frame(width: 900, height: 600)
        .task { await analyzeSamples() }
        .alert("Export Failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }
    
    // MARK: - Actions
    
    private func analyzeSamples() async {
        isAnalyzing = true
        
        do {
            let analyzer = SampleAnalyzer()
            let result = try await analyzer.analyzeSamples(in: image.url)
            
            self.samples = result.samples
            self.analysisResult = result
            
        } catch {
            print("Failed to analyze samples: \(error)")
        }
        
        isAnalyzing = false
    }
    
    private func copyNames(_ selection: Set<SampleInfo.ID>) {
        let names = samples
            .filter { selection.contains($0.id) }
            .map(\.name)
            .joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(names, forType: .string)
    }

    @MainActor
    private func extractAsWAV(ids: Set<SampleInfo.ID>) async {
        let toExport = samples.filter { ids.contains($0.id) }
        guard !toExport.isEmpty else { return }

        if toExport.count == 1, let sample = toExport.first {
            // Single sample → NSSavePanel
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.wav]
            panel.nameFieldStringValue = SampleExporter.sanitizeFilename(
                sample.name.isEmpty ? "sample_\(sample.sampleIndex)" : sample.name
            ) + ".wav"
            panel.title = "Export \"\(sample.name)\" as WAV"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            do {
                try SampleExporter.exportPCMData(
                    sample.pcmData,
                    name: sample.name,
                    sampleRate: Double(sample.sampleRate),
                    to: url
                )
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                exportError = error.localizedDescription
            }
        } else {
            // Multiple samples → choose output folder
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.prompt = "Export Here"
            panel.message = "Export \(toExport.count) samples as WAV files"
            guard panel.runModal() == .OK, let dir = panel.url else { return }
            var failed = 0
            for sample in toExport {
                let safeName = SampleExporter.sanitizeFilename(
                    sample.name.isEmpty ? "sample_\(sample.sampleIndex)" : sample.name
                )
                let url = dir.appendingPathComponent(safeName + ".wav")
                do {
                    try SampleExporter.exportPCMData(
                        sample.pcmData,
                        name: sample.name,
                        sampleRate: Double(sample.sampleRate),
                        to: url
                    )
                } catch { failed += 1 }
            }
            if failed == 0 {
                NSWorkspace.shared.open(dir)
            } else {
                exportError = "\(failed) of \(toExport.count) sample(s) failed to export"
            }
        }
    }
}

// MARK: - Preview (commented out)
// #Preview {
//     SampleBrowserView(image: DiskImage(...))
// }
