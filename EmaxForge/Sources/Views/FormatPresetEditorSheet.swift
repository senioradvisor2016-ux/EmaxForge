import SwiftUI
import UniformTypeIdentifiers

/// Editor for managing format presets
struct FormatPresetEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var presetManager = FormatPresetManager.shared
    
    @State private var selectedPreset: FormatPreset?
    @State private var showCreateSheet = false
    @State private var showDeleteConfirm = false
    @State private var showImportPicker = false
    @State private var showExportPicker = false
    @State private var presetToDelete: FormatPreset?
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Format Presets",
                subtitle: "Manage physical format configurations",
                icon: "slider.horizontal.3",
                onClose: { dismiss() }
            )
            
            Divider()
            
            HSplitView {
                // Left: Preset list
                VStack(spacing: 0) {
                    List(selection: $selectedPreset) {
                        Section("Factory Defaults") {
                            ForEach(presetManager.factoryPresets) { preset in
                                PresetRow(preset: preset)
                            }
                        }
                        
                        if !presetManager.userPresets.isEmpty {
                            Section("My Presets") {
                                ForEach(presetManager.userPresets) { preset in
                                    PresetRow(preset: preset)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Toolbar
                    HStack {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("Create new preset")
                        
                        Button {
                            if let preset = selectedPreset {
                                presetToDelete = preset
                                showDeleteConfirm = true
                            }
                        } label: {
                            Image(systemName: "minus")
                        }
                        .disabled(selectedPreset == nil || selectedPreset?.isFactoryDefault == true)
                        .help("Delete preset")
                        
                        Divider()
                        
                        Button {
                            showImportPicker = true
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .help("Import presets")
                        
                        Button {
                            showExportPicker = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(presetManager.presets.isEmpty)
                        .help("Export presets")
                        
                        Spacer()
                        
                        Button {
                            showDeleteConfirm = true
                            presetToDelete = nil // Signal reset
                        } label: {
                            Text("Reset...")
                        }
                        .help("Reset to factory defaults")
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.05))
                }
                .frame(minWidth: 280, idealWidth: 320)
                
                // Right: Preset details
                if let preset = selectedPreset {
                    FormatPresetDetailView(preset: preset)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Select a preset")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: 900, height: 600)
        .sheet(isPresented: $showCreateSheet) {
            CreatePresetSheet()
        }
        .alert("Delete Preset?", isPresented: $showDeleteConfirm) {
            if let preset = presetToDelete {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    presetManager.deletePreset(preset)
                    selectedPreset = nil
                }
            } else {
                // Reset to defaults
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    presetManager.resetToDefaults()
                    selectedPreset = nil
                }
            }
        } message: {
            if let preset = presetToDelete {
                Text("Are you sure you want to delete '\(preset.name)'?")
            } else {
                Text("This will delete all custom presets and restore factory defaults.")
            }
        }
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .fileExporter(
            isPresented: $showExportPicker,
            document: PresetsDocument(presets: presetManager.presets),
            contentType: .json,
            defaultFilename: "EmaxForge_Presets.json"
        ) { result in
            handleExport(result)
        }
    }
    
    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                try presetManager.importAllPresets(from: url)
            } catch {
                // TODO: Show error alert
                print("Import failed: \(error)")
            }
        case .failure(let error):
            print("Import failed: \(error)")
        }
    }
    
    private func handleExport(_ result: Result<URL, Error>) {
        // Export is handled by fileExporter via PresetsDocument
    }
}

// MARK: - Preset Row

struct PresetRow: View {
    let preset: FormatPreset
    @StateObject private var presetManager = FormatPresetManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            // Default star
            if preset.isDefault {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
            } else {
                Image(systemName: "star")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .opacity(0.3)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name)
                    .fontWeight(preset.isDefault ? .semibold : .regular)
                Text(preset.formattedVolumeSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Enabled toggle
            Toggle("", isOn: Binding(
                get: { preset.isEnabled },
                set: { _ in presetManager.toggleEnabled(preset) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .opacity(preset.isEnabled ? 1.0 : 0.5)
        .contextMenu {
            if !preset.isDefault {
                Button {
                    presetManager.setAsDefault(preset)
                } label: {
                    Label("Set as Default", systemImage: "star.fill")
                }
            }
            
            Button {
                presetManager.toggleEnabled(preset)
            } label: {
                Label(preset.isEnabled ? "Disable" : "Enable", systemImage: preset.isEnabled ? "eye.slash" : "eye")
            }
            
            if !preset.isFactoryDefault {
                Divider()
                Button(role: .destructive) {
                    presetManager.deletePreset(preset)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Format Preset Detail View

struct FormatPresetDetailView: View {
    let preset: FormatPreset
    @StateObject private var presetManager = FormatPresetManager.shared
    @State private var showEditSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(preset.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        if preset.isFactoryDefault {
                            Label("Factory Default", systemImage: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    if !preset.notes.isEmpty {
                        Text(preset.notes)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                
                // Configuration
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configuration")
                        .font(.headline)
                    
                    FormatInfoRow(label: "Volume Size", value: preset.formattedVolumeSize)
                    FormatInfoRow(label: "Cluster Size", value: preset.formattedClusterSize)
                    FormatInfoRow(label: "Include OS", value: preset.includeOS ? "Yes (bootable)" : "No")
                    FormatInfoRow(label: "Status", value: preset.isEnabled ? "Enabled" : "Disabled")
                    FormatInfoRow(label: "Default", value: preset.isDefault ? "Yes" : "No")
                }
                
                Divider()
                
                // Metadata
                VStack(alignment: .leading, spacing: 12) {
                    Text("Metadata")
                        .font(.headline)
                    
                    FormatInfoRow(label: "Created", value: preset.createdDate.formatted(date: .abbreviated, time: .omitted))
                    FormatInfoRow(label: "Type", value: preset.isFactoryDefault ? "Factory Default" : "User Preset")
                }
                
                Divider()
                
                // Actions
                HStack(spacing: 12) {
                    if !preset.isFactoryDefault {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if !preset.isDefault {
                        Button {
                            presetManager.setAsDefault(preset)
                        } label: {
                            Label("Set as Default", systemImage: "star")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Button {
                        presetManager.toggleEnabled(preset)
                    } label: {
                        Label(preset.isEnabled ? "Disable" : "Enable", systemImage: preset.isEnabled ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
        }
        .frame(minWidth: 400)
        .sheet(isPresented: $showEditSheet) {
            EditPresetSheet(preset: preset)
        }
    }
}

// MARK: - Create Preset Sheet

struct CreatePresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var presetManager = FormatPresetManager.shared
    
    @State private var name = ""
    @State private var volumeSizeMB = 524
    @State private var clusterSize = 6144
    @State private var includeOS = false
    @State private var notes = ""
    @State private var validationErrors: [String] = []
    
    let clusterSizes = [512, 1024, 2048, 4096, 6144]
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Create Preset",
                subtitle: "Define a new format configuration",
                icon: "plus.circle",
                onClose: { dismiss() }
            )
            
            Divider()
            
            Form {
                Section("Name") {
                    TextField("Preset name", text: $name)
                }
                
                Section("Configuration") {
                    Stepper("Volume Size: \(volumeSizeMB) MB", value: $volumeSizeMB, in: 1...4096, step: 1)
                    
                    Picker("Cluster Size", selection: $clusterSize) {
                        ForEach(clusterSizes, id: \.self) { size in
                            Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)).tag(size)
                        }
                    }
                    
                    Toggle("Include EMAX II OS (bootable)", isOn: $includeOS)
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 60)
                }
                
                if !validationErrors.isEmpty {
                    Section {
                        ForEach(validationErrors, id: \.self) { error in
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Create") { createPreset() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 480)
    }
    
    private func createPreset() {
        let preset = FormatPreset(
            name: name,
            clusterSize: clusterSize,
            volumeSize: Int64(volumeSizeMB) * 1_000_000,
            includeOS: includeOS,
            notes: notes
        )
        
        let validation = preset.validate()
        if validation.isValid {
            presetManager.addPreset(preset)
            dismiss()
        } else {
            validationErrors = validation.errors
        }
    }
}

// MARK: - Edit Preset Sheet

struct EditPresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var presetManager = FormatPresetManager.shared
    
    let preset: FormatPreset
    
    @State private var name = ""
    @State private var volumeSizeMB = 524
    @State private var clusterSize = 6144
    @State private var includeOS = false
    @State private var notes = ""
    @State private var validationErrors: [String] = []
    
    let clusterSizes = [512, 1024, 2048, 4096, 6144]
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Edit Preset",
                subtitle: "Modify format configuration",
                icon: "pencil",
                onClose: { dismiss() }
            )
            
            Divider()
            
            Form {
                Section("Name") {
                    TextField("Preset name", text: $name)
                }
                
                Section("Configuration") {
                    Stepper("Volume Size: \(volumeSizeMB) MB", value: $volumeSizeMB, in: 1...4096, step: 1)
                    
                    Picker("Cluster Size", selection: $clusterSize) {
                        ForEach(clusterSizes, id: \.self) { size in
                            Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)).tag(size)
                        }
                    }
                    
                    Toggle("Include EMAX II OS (bootable)", isOn: $includeOS)
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 60)
                }
                
                if !validationErrors.isEmpty {
                    Section {
                        ForEach(validationErrors, id: \.self) { error in
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") { savePreset() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 480)
        .onAppear {
            name = preset.name
            volumeSizeMB = Int(preset.volumeSize / 1_000_000)
            clusterSize = preset.clusterSize
            includeOS = preset.includeOS
            notes = preset.notes
        }
    }
    
    private func savePreset() {
        var updated = preset
        updated.name = name
        updated.clusterSize = clusterSize
        updated.volumeSize = Int64(volumeSizeMB) * 1_000_000
        updated.includeOS = includeOS
        updated.notes = notes
        
        let validation = updated.validate()
        if validation.isValid {
            presetManager.updatePreset(updated)
            dismiss()
        } else {
            validationErrors = validation.errors
        }
    }
}

// MARK: - Presets Document (for export)

struct PresetsDocument: FileDocument {
    static var readableContentTypes = [UTType.json]
    
    let presets: [FormatPreset]
    
    init(presets: [FormatPreset]) {
        self.presets = presets
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.presets = try JSONDecoder().decode([FormatPreset].self, from: data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(presets)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Helper Views

struct FormatInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}
