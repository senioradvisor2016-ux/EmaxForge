import SwiftUI

/// Bulk export all samples from an image to WAV/AIFF files
struct BulkExportView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    let image: DiskImage
    
    @State private var exportFormat: SampleExporter.ExportFormat = .wav
    @State private var outputDirectory: URL?
    @State private var normalize = false
    @State private var isExporting = false
    @State private var progress: Double = 0
    @State private var progressMessage = ""
    @State private var result: ExportResult?
    @State private var errorMessage: String?
    
    struct ExportResult {
        let totalSamples: Int
        let outputDirectory: URL
        let totalSize: Int64
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Bulk Export Samples",
                subtitle: "Export all samples from \(image.filename)",
                icon: "square.and.arrow.up",
                onClose: { dismiss() }
            )
            
            Divider()
            
            if let result = result {
                successView(result)
            } else if isExporting {
                progressView
            } else {
                exportForm
            }
        }
        .frame(width: 600, height: 500)
        .onExitCommand { dismiss() }
    }
    
    // MARK: - Form
    
    private var exportForm: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Format selection
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Export Format")
                    .font(Theme.Typography.headline)
                
                Picker("Format", selection: $exportFormat) {
                    ForEach(SampleExporter.ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Output directory
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Output Directory")
                    .font(Theme.Typography.headline)
                
                HStack(spacing: Theme.Spacing.md) {
                    if let dir = outputDirectory {
                        Text(dir.lastPathComponent)
                            .font(Theme.Typography.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("Not selected")
                            .font(Theme.Typography.body)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Choose...") {
                        chooseOutputDirectory()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Options
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Options")
                    .font(Theme.Typography.headline)
                
                Toggle("Normalize samples", isOn: $normalize)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: Theme.Spacing.md) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Export All Samples") {
                    startExport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(outputDirectory == nil)
            }
        }
        .padding(Theme.Spacing.lg)
    }
    
    // MARK: - Progress
    
    private var progressView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ProgressView(value: progress)
                .frame(width: 400)
            
            Text(progressMessage)
                .font(Theme.Typography.body)
                .foregroundStyle(.secondary)
            
            Text("\(Int(progress * 100))%")
                .font(Theme.Typography.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Success
    
    private func successView(_ result: ExportResult) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            
            Text("Export Complete")
                .font(Theme.Typography.title)
            
            VStack(spacing: Theme.Spacing.sm) {
                Text("\(result.totalSamples) samples exported")
                    .font(Theme.Typography.body)
                
                Text(ByteCountFormatter.string(fromByteCount: result.totalSize, countStyle: .file))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([result.outputDirectory])
            }
            .buttonStyle(.borderedProminent)
            
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.xl)
    }
    
    // MARK: - Actions
    
    private func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        
        if panel.runModal() == .OK {
            outputDirectory = panel.url
        }
    }
    
    private func startExport() {
        guard let outputDir = outputDirectory else { return }
        
        isExporting = true
        progress = 0
        progressMessage = "Preparing export..."
        errorMessage = nil
        
        Task {
            do {
                let results = try SampleExporter.exportImage(
                    imageURL: image.url,
                    to: outputDir,
                    format: exportFormat,
                    normalize: normalize,
                    progress: { bankName, bankProgress in
                        Task { @MainActor in
                            progress = bankProgress
                            progressMessage = "Exporting \(bankName)..."
                        }
                    }
                )
                
                let totalSize = results.reduce(0) { $0 + $1.fileSize }
                
                await MainActor.run {
                    result = ExportResult(
                        totalSamples: results.count,
                        outputDirectory: outputDir,
                        totalSize: totalSize
                    )
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }
}
