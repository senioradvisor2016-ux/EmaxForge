import SwiftUI
import UniformTypeIdentifiers

/// Sheet for creating blank EMAX floppy disk images
struct CreateFloppySheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var destinationURL: URL?
    @State private var filename: String = "EMAX_Floppy"
    @State private var density: DiskFormatter.FloppyDensity = .doubleDensity
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.accent.gradient)
                        .frame(width: 60, height: 60)
                    Image(systemName: "opticaldiscdrive")
                        .font(.title)
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create Floppy Disk Image")
                        .font(.title2.bold())
                    Text("Blank EMAX I/II floppy (.HFE)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Settings
            VStack(alignment: .leading, spacing: 16) {
                // Filename
                VStack(alignment: .leading, spacing: 8) {
                    Text("Filename")
                        .font(.subheadline.bold())
                    
                    TextField("EMAX_Floppy", text: $filename)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Extension .HFE will be added automatically")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Density
                VStack(alignment: .leading, spacing: 8) {
                    Text("Disk Density")
                        .font(.subheadline.bold())
                    
                    Picker("Density", selection: $density) {
                        Text("Double Density (800 KB) — Standard").tag(DiskFormatter.FloppyDensity.doubleDensity)
                        Text("Single Density (180 KB)").tag(DiskFormatter.FloppyDensity.singleDensity)
                        Text("High Density (1.44 MB)").tag(DiskFormatter.FloppyDensity.highDensity)
                    }
                    .pickerStyle(.radioGroup)
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: density == .doubleDensity ? "checkmark.circle.fill" : "info.circle")
                            .foregroundStyle(density == .doubleDensity ? Theme.success : .secondary)
                        Text(densityDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                
                // Destination
                VStack(alignment: .leading, spacing: 8) {
                    Text("Save Location")
                        .font(.subheadline.bold())
                    
                    HStack {
                        Button("Choose Folder…") {
                            selectDestination()
                        }
                        .buttonStyle(.bordered)
                        
                        if let url = destinationURL {
                            Label(url.lastPathComponent, systemImage: "folder.fill")
                                .font(.callout)
                                .foregroundStyle(Theme.accent)
                        } else {
                            Text("No destination selected")
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            
            // Info box
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("HFE Format")
                        .font(.caption.bold())
                    Text("HFE (HxC Floppy Emulator) is a universal floppy image format compatible with hardware emulators like Gotek and HxC. Perfect for EMAX I/II with floppy drive replacement.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            
            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
                .padding()
                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
            
            Spacer()
            
            // Actions
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                if isCreating {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Creating...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Create Floppy") { createFloppy() }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(destinationURL == nil || filename.isEmpty)
                }
            }
        }
        .padding(24)
        .frame(width: 540, height: 620)
        .onAppear {
            // Auto-select current volume if available
            if let vol = appState.selectedVolume {
                destinationURL = vol.url
            }
        }
    }
    
    private var densityDescription: String {
        switch density {
        case .singleDensity:
            return "180 KB • EMAX I format • Rarely used today"
        case .doubleDensity:
            return "✓ 800 KB • EMAX II standard format (DD) • Recommended"
        case .highDensity:
            return "1.44 MB • PC format (HD) • Not compatible with EMAX"
        }
    }
    
    private func selectDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select destination folder for floppy image"
        
        if panel.runModal() == .OK {
            destinationURL = panel.url
        }
    }
    
    private func createFloppy() {
        guard let destDir = destinationURL else { return }
        
        isCreating = true
        errorMessage = nil
        
        let finalFilename = filename.hasSuffix(".HFE") ? filename : "\(filename).HFE"
        let destURL = destDir.appendingPathComponent(finalFilename)
        
        Task.detached {
            let density = await density
            
            do {
                try DiskFormatter.createBlankFloppy(at: destURL, density: density)
                
                await MainActor.run {
                    appState.addActivity("Created floppy image: \(finalFilename)", type: .success)
                    dismiss()
                    
                    // Reveal in Finder
                    NSWorkspace.shared.activateFileViewerSelecting([destURL])
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}
