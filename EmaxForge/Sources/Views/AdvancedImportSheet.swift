import SwiftUI

struct AdvancedImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFiles: [URL] = []
    @State private var targetRate = 42000
    @State private var convertToMono = true
    @State private var normalize = true
    @State private var isConverting = false
    @State private var progress: Double = 0.0
    @State private var currentFile = ""
    @State private var errorMessage: String?
    
    let audioService = AudioConversionService()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Advanced Audio Import")
                .font(.title2)
                .fontWeight(.semibold)
            
            // File selection
            GroupBox("Files") {
                VStack(alignment: .leading, spacing: 8) {
                    Button("Select Audio Files...") {
                        selectFiles()
                    }
                    .disabled(isConverting)
                    
                    if selectedFiles.isEmpty {
                        Text("No files selected")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        Text("\(selectedFiles.count) file(s) selected")
                            .foregroundColor(.primary)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(selectedFiles, id: \.self) { file in
                                    Text("• \(file.lastPathComponent)")
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .frame(maxHeight: 100)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Conversion options
            GroupBox("Conversion Options") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Sample Rate:")
                        Spacer()
                        Picker("", selection: $targetRate) {
                            Text("8 kHz").tag(8000)
                            Text("11 kHz").tag(11025)
                            Text("22 kHz").tag(22050)
                            Text("42 kHz (EMAX II)").tag(42000)
                            Text("44.1 kHz").tag(44100)
                        }
                        .labelsHidden()
                        .frame(width: 180)
                    }
                    
                    Toggle("Convert to Mono", isOn: $convertToMono)
                    Toggle("Normalize Volume", isOn: $normalize)
                }
            }
            
            // Progress
            if isConverting {
                GroupBox {
                    VStack(spacing: 8) {
                        ProgressView(value: progress, total: 1.0)
                            .progressViewStyle(.linear)
                        
                        Text("Converting: \(currentFile)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Error message
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(isConverting)
                
                Spacer()
                
                Button("Convert & Import") {
                    Task {
                        await performConversion()
                    }
                }
                .disabled(selectedFiles.isEmpty || isConverting)
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 500, height: 500)
    }
    
    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio, .wav, .aiff]
        panel.message = "Select audio files to import"
        
        if panel.runModal() == .OK {
            selectedFiles = panel.urls
        }
    }
    
    private func performConversion() async {
        isConverting = true
        errorMessage = nil
        progress = 0.0
        
        do {
            // Create temp output directory
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("emaxforge_converted")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            let options = AudioConversionService.ConversionOptions(
                targetRate: targetRate,
                convertToMono: convertToMono,
                normalize: normalize
            )
            
            let results = try await audioService.batchConvert(
                files: selectedFiles,
                outputDirectory: tempDir,
                options: options
            ) { current, total in
                DispatchQueue.main.async {
                    progress = Double(current) / Double(total)
                    if current <= selectedFiles.count {
                        currentFile = selectedFiles[current - 1].lastPathComponent
                    }
                }
            }
            
            // Success!
            print("✅ Converted \(results.count) files")
            
            // TODO: Auto-import converted files to current disk
            
            dismiss()
            
        } catch {
            errorMessage = error.localizedDescription
            isConverting = false
        }
    }
}

#Preview {
    AdvancedImportSheet()
}
