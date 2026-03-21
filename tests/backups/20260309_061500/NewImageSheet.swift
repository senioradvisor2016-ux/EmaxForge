import SwiftUI

struct NewImageSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var presetManager = FormatPresetManager.shared
    
    @State private var selectedPreset: FormatPreset?
    @State private var scsiID = 1
    @State private var imageIndex = 0
    @State private var label = ""
    @State private var sizeMB = 239  // ZIP 250 (default)
    @State private var useImageIndex = false
    @State private var includeOS = true
    @State private var errorMessage: String?
    @State private var isCreating = false
    @State private var showPresetEditor = false
    
    let commonSizes = [96, 239, 481, 633, 962]
    private var osAvailable: Bool { true }  // OS bundled as emax2_os.bin
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Create New Image",
                subtitle: "Create a new EMAX II disk image",
                icon: "plus.circle",
                onClose: { dismiss() }
            )
            
            Divider()
            
            Form {
                Section {
                    Picker("Format Preset", selection: $selectedPreset) {
                        Text("Custom (Manual)").tag(nil as FormatPreset?)
                        Divider()
                        ForEach(presetManager.enabledPresets) { preset in
                            HStack {
                                if preset.isDefault {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                        .font(.caption)
                                }
                                Text(preset.name)
                            }
                            .tag(preset as FormatPreset?)
                        }
                    }
                    
                    if let preset = selectedPreset {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !preset.notes.isEmpty {
                                Text(preset.notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .italic()
                            }
                        }
                        .padding(.vertical, 2)
                        
                        Button {
                            showPresetEditor = true
                        } label: {
                            Label("Manage Presets...", systemImage: "slider.horizontal.3")
                        }
                        .buttonStyle(.link)
                    } else {
                        Button {
                            showPresetEditor = true
                        } label: {
                            Label("Manage Presets...", systemImage: "slider.horizontal.3")
                        }
                        .buttonStyle(.link)
                    }
                } header: {
                    HStack {
                        Text("Format Preset")
                        Spacer()
                        if let preset = selectedPreset, preset.isDefault {
                            Text("DEFAULT")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }
                }
                
                Section("SCSI Configuration") {
                    Picker("SCSI ID", selection: $scsiID) {
                        ForEach(0...appState.currentDevice.maxScsiID, id: \.self) { id in
                            Text("ID \(id)").tag(id)
                        }
                    }
                    
                    if scsiID == 1 {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                            Text("SCSI ID 1 = Boot disk (EMAX II loads OS from HD1). Should contain OS only.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.green)
                            Text("SCSI ID \(scsiID) = Data disk. Use for sample banks.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Toggle("Multi-image slot", isOn: $useImageIndex)
                    
                    if useImageIndex {
                        Stepper("Image index: \(imageIndex)", value: $imageIndex, in: 0...99)
                    }
                    
                    TextField("Label (optional)", text: $label)
                }
                
                Section("Image") {
                    Picker("Size", selection: $sizeMB) {
                        ForEach(commonSizes, id: \.self) { size in
                            Text(sizeLabel(for: size)).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Toggle("Include EMAX II OS (bootable)", isOn: $includeOS)
                        .disabled(!osAvailable)
                    
                    if includeOS && osAvailable {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Theme.success)
                            Text("Emax II rev 2.14 · ZuluSCSI compatible")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if !osAvailable {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Theme.accent)
                            Text("OS file not found — image won't be bootable")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Preview") {
                    HStack {
                        Text("Filename")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(previewFilename)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.accent)
                    }
                    
                    HStack {
                        Text("Type")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(includeOS && osAvailable ? "Bootable image with OS" : "Empty image (no OS)")
                    }
                }
            }
            .formStyle(.grouped)
            
            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.danger)
                    .font(.callout)
                    .padding(.horizontal)
            }
            
            Divider()
            
            HStack {
                Spacer()
                
                Button("Create Image") { createImage() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(isCreating)
            }
            .padding()
        }
        .frame(width: 460, height: 520)
        .overlay {
            if isCreating {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Creating image...")
                                .font(.headline)
                        }
                        .padding(32)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
            }
        }
        .onExitCommand { dismiss() }
        .sheet(isPresented: $showPresetEditor) {
            FormatPresetEditorSheet()
        }
        .onAppear {
            // Load default preset on first appearance
            if selectedPreset == nil {
                selectedPreset = presetManager.defaultPreset
                if let preset = selectedPreset {
                    applyPreset(preset)
                }
            }
        }
        .onChange(of: selectedPreset) { oldValue, newValue in
            if let preset = newValue {
                applyPreset(preset)
            }
        }
    }
    
    private func applyPreset(_ preset: FormatPreset) {
        // Convert volume size to MB (closest match)
        let sizeMBValue = Int(preset.volumeSize / 1_000_000)
        
        // Find closest common size
        if let closest = commonSizes.min(by: { abs($0 - sizeMBValue) < abs($1 - sizeMBValue) }) {
            sizeMB = closest
        } else {
            sizeMB = sizeMBValue
        }
        
        // Apply OS setting
        includeOS = preset.includeOS
        
        // Note: cluster size is not directly configurable in NewImageSheet
        // It's determined by the underlying ImageCreator implementation
    }
    
    private var previewFilename: String {
        // ZuluSCSI format: HDxy where x=SCSI ID, y=unit (default 0)
        var name = "\(appState.currentDevice.scsiPrefix)\(scsiID)0"  // e.g. HD00, HD10, HD20
        if useImageIndex { name += "_\(imageIndex)" }
        if !label.isEmpty { name += "_\(label)" }
        name += ".hda"
        return name
    }
    
    private func sizeLabel(for mb: Int) -> String {
        if mb >= 1000 {
            return "\(mb / 1000) GB"
        } else {
            return "\(mb) MB"
        }
    }
    
    private func createImage() {
        guard let volume = appState.selectedVolume else { return }
        isCreating = true
        errorMessage = nil
        
        let destURL = volume.url.appendingPathComponent(previewFilename)
        
        do {
            if includeOS && osAvailable {
                try ImageCreator.createBootableImage(at: destURL, sizeMB: sizeMB)
            } else {
                _ = try appState.fileService.createEmptyImage(
                    at: volume.url,
                    scsiID: scsiID,
                    imageIndex: useImageIndex ? imageIndex : nil,
                    label: label.isEmpty ? nil : label,
                    sizeMB: sizeMB,
                    device: appState.currentDevice
                )
            }
            appState.refreshImages()
            appState.statusMessage = "Created \(previewFilename)" + (includeOS ? " (bootable)" : "")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
        }
    }
}
