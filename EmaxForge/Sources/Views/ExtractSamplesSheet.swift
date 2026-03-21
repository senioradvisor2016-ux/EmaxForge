import SwiftUI

/// Sheet for extracting samples from a bank to WAV files
struct ExtractSamplesSheet: View {
    let image: DiskImage
    let bankName: String
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var destinationURL: URL?
    @State private var isExtracting = false
    @State private var currentSample = ""
    @State private var progress: Double = 0
    @State private var result: SampleExtractor.ExtractionResult?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "waveform.badge.plus")
                        .font(.title)
                        .foregroundColor(Theme.cyan)
                    Text("Extract Samples")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Text(bankName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(image.filename)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Divider()
            
            // Content
            if let result = result {
                // Results view
                resultView(result)
            } else if isExtracting {
                // Extraction in progress
                extractingView
            } else {
                // Setup view
                setupView
            }
            
            Divider()
            
            // Footer
            HStack {
                if let result = result, !result.errors.isEmpty {
                    Button("Show Errors") {
                        errorMessage = result.errors.joined(separator: "\n")
                        showError = true
                    }
                    .foregroundColor(.orange)
                }
                
                Spacer()
                
                if result != nil {
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                } else if isExtracting {
                    // No buttons while extracting
                } else {
                    Button("Cancel") {
                        dismiss()
                    }
                    
                    Button("Extract") {
                        Task {
                            await performExtraction()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(destinationURL == nil)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .alert("Extraction Errors", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Setup View
    
    private var setupView: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            // Instructions
            VStack(spacing: 8) {
                Text("Choose where to save extracted samples")
                    .font(.headline)
                Text("Samples will be exported as individual WAV files")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Folder picker
            if let url = destinationURL {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    
                    Text(url.path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Button("Change Folder") {
                    chooseDestinationFolder()
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            } else {
                Button {
                    chooseDestinationFolder()
                } label: {
                    Label("Choose Destination Folder", systemImage: "folder")
                        .font(.headline)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Extracting View
    
    private var extractingView: some View {
        VStack(spacing: 24) {
            // Progress
            VStack(spacing: 16) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 300)
                
                Text(currentSample)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Extracting samples...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Result View
    
    private func resultView(_ result: SampleExtractor.ExtractionResult) -> some View {
        VStack(spacing: 24) {
            // Success icon
            Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundColor(result.success ? .green : .orange)
            
            // Stats
            VStack(spacing: 12) {
                Text(result.success ? "Extraction Complete!" : "Extraction Completed with Errors")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Samples extracted:")
                        Spacer()
                        Text("\(result.samplesExtracted)")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Total size:")
                        Spacer()
                        Text(result.formattedSize)
                            .fontWeight(.semibold)
                    }
                    
                    if !result.errors.isEmpty {
                        HStack {
                            Text("Errors:")
                            Spacer()
                            Text("\(result.errors.count)")
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Location:")
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                        Text(result.destinationURL.lastPathComponent)
                            .font(.caption)
                        Spacer()
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([result.destinationURL])
                        } label: {
                            Image(systemName: "arrow.right.circle")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Actions
    
    private func chooseDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Destination"
        panel.message = "Select where to save extracted WAV files"
        
        if panel.runModal() == .OK {
            destinationURL = panel.url
        }
    }
    
    private func performExtraction() async {
        guard let destinationURL = destinationURL else { return }
        
        isExtracting = true
        currentSample = "Starting extraction..."
        progress = 0
        
        do {
            let extractor = SampleExtractor()
            
            let result = try await extractor.extractSamplesFromImage(
                imageURL: image.url,
                bankName: bankName,
                to: destinationURL
            ) { sample, prog in
                Task { @MainActor in
                    currentSample = sample
                    progress = prog
                }
            }
            
            self.result = result
            isExtracting = false
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isExtracting = false
        }
    }
}

// MARK: - Preview (commented out)
// #Preview {
//     ExtractSamplesSheet(
//         image: DiskImage(url: URL(fileURLWithPath: "/path/to/test.hda"), device: .emaxII),
//         bankName: "Test Bank"
//     )
// }
