import SwiftUI

/// Create bank from template
struct BankTemplatesSheet: View {
    @Environment(\.dismiss) var dismiss
    
    let image: DiskImage
    
    @State private var templates: [BankTemplateService.Template] = []
    @State private var selectedTemplate: BankTemplateService.Template?
    @State private var customName = ""
    @State private var presetCount = 100
    @State private var isLoading = true
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Create Bank from Template",
                subtitle: "Pre-fabricated banks for common use cases",
                icon: "square.grid.3x3.square",
                onClose: { dismiss() }
            )
            
            Divider()
            
            if isLoading {
                loadingView
            } else {
                contentView
            }
        }
        .frame(width: 700, height: 600)
        .onAppear { loadTemplates() }
    }
    
    // MARK: - Loading
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading templates...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Content
    
    private var contentView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(templates) { template in
                        templateCard(template)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Options section
            if let selected = selectedTemplate {
                optionsSection(selected)
            }
            
            Divider()
            
            // Action buttons
            HStack(spacing: 12) {
                if let success = successMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(success)
                            .font(.subheadline)
                    }
                }
                
                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.subheadline)
                    }
                }
                
                Spacer()
                
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Button("Create & Import") {
                    createAndImport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedTemplate == nil || isCreating)
                .keyboardShortcut(.return)
            }
            .padding()
        }
    }
    
    private func templateCard(_ template: BankTemplateService.Template) -> some View {
        let isSelected = selectedTemplate?.id == template.id
        
        return HStack(spacing: 16) {
            // Icon
            Image(systemName: iconForTemplate(template.name))
                .font(.system(size: 32))
                .foregroundStyle(isSelected ? .white : .blue)
                .frame(width: 48)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Text(template.description)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                
                Label("\(template.presets) presets", systemImage: "music.note.list")
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTemplate = template
            if customName.isEmpty {
                customName = template.name
            }
        }
    }
    
    private func optionsSection(_ template: BankTemplateService.Template) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.headline)
            
            // Custom name
            HStack {
                Text("Bank Name:")
                    .frame(width: 100, alignment: .trailing)
                
                TextField("Bank name", text: $customName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                
                Spacer()
            }
            
            // Preset count (only for EMPTY template)
            if template.name == "EMPTY" {
                HStack {
                    Text("Preset Count:")
                        .frame(width: 100, alignment: .trailing)
                    
                    Stepper(value: $presetCount, in: 1...100) {
                        Text("\(presetCount)")
                            .monospacedDigit()
                    }
                    .frame(width: 120)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Actions
    
    private func createAndImport() {
        guard let template = selectedTemplate else { return }
        
        isCreating = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                // Create temp file
                let tempDir = FileManager.default.temporaryDirectory
                let tempFile = tempDir.appendingPathComponent("\(customName).EB2")
                
                // Create from template
                _ = try await BankTemplateService.createTemplate(
                    template: template.name,
                    output: tempFile,
                    name: customName,
                    presetCount: template.name == "EMPTY" ? presetCount : nil
                )
                
                // Import to disk
                let result = try BankImporter.importBank(
                    eb2URL: tempFile,
                    into: image.url
                )
                
                await MainActor.run {
                    successMessage = "Created '\(result.bankName)' and imported to disk!"
                    isCreating = false
                }
                
                // Auto-close after success
                try? await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5s
                await MainActor.run {
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
    
    // MARK: - Load Data
    
    private func loadTemplates() {
        Task {
            do {
                let templateList = try await BankTemplateService.listTemplates()
                await MainActor.run {
                    self.templates = templateList
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func iconForTemplate(_ name: String) -> String {
        switch name {
        case "INIT BANK": return "1.circle"
        case "PERCUSSION": return "music.note.list"
        case "BASS": return "waveform.path"
        case "PADS": return "cloud"
        case "LEADS": return "bolt"
        case "FX": return "sparkles"
        case "EMPTY": return "square.dashed"
        default: return "music.note"
        }
    }
}
