import SwiftUI

/// Export banks from EMAX II disk to .EB2 files
struct BankExportView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    let image: DiskImage
    
    @State private var banks: [(name: String, cluster: Int, presets: Int)] = []
    @State private var selectedBanks: Set<String> = []
    @State private var outputDirectory: URL?
    @State private var isLoading = true
    @State private var isExporting = false
    @State private var progress: Double = 0
    @State private var progressMessage = ""
    @State private var result: ExportResult?
    @State private var errorMessage: String?
    
    struct ExportResult {
        let banksExported: Int
        let totalSize: Int64
        let outputDirectory: URL
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Export Banks",
                subtitle: "Export banks from \(image.filename) to .EB2 files",
                icon: "square.and.arrow.up",
                onClose: { dismiss() }
            )
            
            Divider()
            
            if let result = result {
                successView(result)
            } else if isExporting {
                progressView
            } else if isLoading {
                loadingView
            } else {
                exportForm
            }
        }
        .frame(width: 700, height: 600)
        .onAppear { loadBanks() }
        .onExitCommand { dismiss() }
    }
    
    // MARK: - Loading
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading banks...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Form
    
    private var exportForm: some View {
        VStack(spacing: 0) {
            // Bank list
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Available Banks (\(banks.count))")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("Select All") {
                        selectedBanks = Set(banks.map { $0.name })
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.mint)
                    
                    Button("Deselect All") {
                        selectedBanks.removeAll()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                if banks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No banks found on this disk")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(banks, id: \.name) { bank in
                                bankRow(bank)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                    }
                }
            }
            
            Divider()
            
            // Output directory
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Output Directory")
                            .font(.headline)
                        if let dir = outputDirectory {
                            Text(dir.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("Not selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Choose...") {
                        chooseOutputDirectory()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape)
                    
                    Spacer()
                    
                    Button("Export \(selectedBanks.count) Banks") {
                        startExport()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedBanks.isEmpty || outputDirectory == nil)
                    .keyboardShortcut(.return)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }
    
    private func bankRow(_ bank: (name: String, cluster: Int, presets: Int)) -> some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { selectedBanks.contains(bank.name) },
                set: { isSelected in
                    if isSelected {
                        selectedBanks.insert(bank.name)
                    } else {
                        selectedBanks.remove(bank.name)
                    }
                }
            )) {}
                .labelsHidden()
                .toggleStyle(.checkbox)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(bank.name)
                    .font(.system(.body, design: .monospaced))
                
                Text("\(bank.presets) preset(s), cluster \(bank.cluster)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(selectedBanks.contains(bank.name) ? Color.mint.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedBanks.contains(bank.name) {
                selectedBanks.remove(bank.name)
            } else {
                selectedBanks.insert(bank.name)
            }
        }
    }
    
    // MARK: - Progress
    
    private var progressView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(.linear)
                .frame(width: 300)
            
            Text(progressMessage)
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("\(Int(progress * 100))%")
                .font(.system(.title, design: .rounded))
                .foregroundStyle(.mint)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Success
    
    private func successView(_ result: ExportResult) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            
            VStack(spacing: 8) {
                Text("Export Complete!")
                    .font(.title2.bold())
                
                Text("Exported \(result.banksExported) banks")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text("Total size: \(ByteCountFormatter.string(fromByteCount: result.totalSize, countStyle: .file))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: result.outputDirectory.path)
                }
                .buttonStyle(.bordered)
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func loadBanks() {
        Task {
            defer { isLoading = false }
            
            do {
                let entries = try BankExtractor.extractAllBanks(from: image.url)
                let loadedBanks = entries.map { (name: $0.name, cluster: 0, presets: 0) }
                await MainActor.run {
                    self.banks = loadedBanks
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load banks: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Select output directory for exported banks"
        
        if panel.runModal() == .OK {
            outputDirectory = panel.url
        }
    }
    
    private func startExport() {
        guard let outputDir = outputDirectory else { return }
        
        isExporting = true
        progress = 0
        progressMessage = "Starting export..."
        
        Task {
            var exportedCount = 0
            var totalSize: Int64 = 0
            let banksToExport = Array(selectedBanks)
            
            for (index, bankName) in banksToExport.enumerated() {
                await MainActor.run {
                    progress = Double(index) / Double(banksToExport.count)
                    progressMessage = "Exporting \(bankName)..."
                }
                
                do {
                    let outputURL = outputDir.appendingPathComponent("\(bankName).EB2")
                    let result = try BankExporter.exportBank(
                        bankName: bankName,
                        from: image.url,
                        to: outputURL
                    )
                    exportedCount += 1
                    totalSize += Int64(result.sizeBytes)
                } catch {
                    print("Failed to export \(bankName): \(error)")
                }
            }
            
            await MainActor.run {
                progress = 1.0
                isExporting = false
                result = ExportResult(
                    banksExported: exportedCount,
                    totalSize: totalSize,
                    outputDirectory: outputDir
                )
            }
        }
    }
}

/// Preview
#if DEBUG
struct BankExportView_Previews: PreviewProvider {
    static var previews: some View {
        BankExportView(image: DiskImage.example)
            .environmentObject(AppState())
    }
}
#endif
