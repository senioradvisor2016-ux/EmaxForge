import SwiftUI
import UniformTypeIdentifiers

// MARK: - TemplateCreatorSheet
// Creates a new .EB2 bank file from a built-in template via the CLI

struct TemplateCreatorSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    // Template selection
    @State private var availableTemplates: [BankTemplateService.Template] = []
    @State private var selectedTemplateName = "INIT"
    @State private var isLoadingTemplates = true

    // Creation options
    @State private var bankName = ""
    @State private var presetCount = 100
    @State private var outputURL: URL?

    // State
    @State private var isCreating = false
    @State private var createResult: BankTemplateService.CreateResult?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Create Bank Template",
                subtitle: "Generate a new .EB2 bank from a built-in template",
                icon: "square.grid.3x3.square",
                onClose: { dismiss() }
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    templateSection
                    bankNameSection
                    presetCountSection
                    outputSection
                    if let result = createResult { successSection(result) }
                    if let err = errorMessage { errorSection(err) }
                }
                .padding()
            }

            Divider()

            footerButtons
        }
        .frame(width: 560, height: 500)
        .onAppear { loadTemplates() }
        .onExitCommand { dismiss() }
    }

    // MARK: - Sections

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("TEMPLATE TYPE")
            if isLoadingTemplates {
                ProgressView("Loading templates…").padding(.vertical, 8)
            } else if availableTemplates.isEmpty {
                // Fallback to known built-in types
                Picker("Template", selection: $selectedTemplateName) {
                    Text("INIT — Default empty bank").tag("INIT")
                    Text("PERCUSSION — Percussion layout").tag("PERCUSSION")
                    Text("EMPTY — Empty bank (custom preset count)").tag("EMPTY")
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)
            } else {
                Picker("Template", selection: $selectedTemplateName) {
                    ForEach(availableTemplates) { tmpl in
                        Text("\(tmpl.name) — \(tmpl.description)").tag(tmpl.name)
                    }
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)
            }
        }
    }

    private var bankNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("BANK NAME (OPTIONAL)")
            TextField("Leave blank to use template default", text: $bankName)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var presetCountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("PRESET COUNT")
            HStack(spacing: 12) {
                Stepper("\(presetCount) presets", value: $presetCount, in: 1...256, step: 10)
                Slider(value: Binding(
                    get: { Double(presetCount) },
                    set: { presetCount = Int($0) }
                ), in: 1...256, step: 10)
                .tint(Theme.accent)
                .frame(width: 180)
            }
            .font(Theme.Typography.body)
        }
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("OUTPUT FILE")
            if let url = outputURL {
                HStack(spacing: 10) {
                    Image(systemName: "doc").foregroundStyle(.secondary)
                    Text(url.lastPathComponent).font(Theme.Typography.body).lineLimit(1)
                    Spacer()
                    Button("Change…") { pickOutput() }.buttonStyle(.bordered)
                }
                .padding(12)
                .background(Theme.bgCard)
                .cornerRadius(8)
            } else {
                Button { pickOutput() } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Choose Output Location (.EB2)…")
                    }
                    .frame(maxWidth: .infinity).padding(12)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func successSection(_ result: BankTemplateService.CreateResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                Text("Bank created successfully!").font(.system(size: 13, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("File: \(result.file)")
                Text("Presets: \(result.presets)")
                Text("Size: \(ByteCountFormatter.string(fromByteCount: Int64(result.size), countStyle: .file))")
            }
            .font(Theme.Typography.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Theme.success.opacity(0.1))
        .cornerRadius(8)
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
            Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            Spacer()
            if isCreating {
                ProgressView().scaleEffect(0.7)
                Text("Creating…").font(Theme.Typography.body).foregroundStyle(.secondary)
            }
            Button("Create Bank") { createBank() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(outputURL == nil || isCreating)
                .keyboardShortcut(.defaultAction)
        }
        .padding()
    }

    // MARK: - Helpers

    private func sectionLabel(_ t: String) -> some View {
        Text(t).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).tracking(1)
    }

    private func pickOutput() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "eb2")].compactMap { $0 }
        let nameBase = bankName.isEmpty ? selectedTemplateName.lowercased() : bankName
        panel.nameFieldStringValue = "\(nameBase).eb2"
        if panel.runModal() == .OK { outputURL = panel.url }
    }

    // MARK: - Actions

    private func loadTemplates() {
        Task {
            if let loaded = try? await BankTemplateService.listTemplates() {
                await MainActor.run {
                    availableTemplates = loaded
                    selectedTemplateName = loaded.first?.name ?? "INIT"
                    isLoadingTemplates = false
                }
            } else {
                await MainActor.run { isLoadingTemplates = false }
            }
        }
    }

    private func createBank() {
        guard let output = outputURL else { return }
        isCreating = true
        errorMessage = nil
        createResult = nil

        let name = bankName.trimmingCharacters(in: .whitespaces)
        let template = selectedTemplateName

        Task {
            do {
                let result = try await BankTemplateService.createTemplate(
                    template: template,
                    output: output,
                    name: name.isEmpty ? nil : name,
                    presetCount: presetCount
                )
                await MainActor.run {
                    createResult = result
                    isCreating = false
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
