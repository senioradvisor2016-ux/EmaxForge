import SwiftUI
import UniformTypeIdentifiers

struct BatchBankImportSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var selectedFiles: [URL] = []
    @State private var targetImage: DiskImage?
    @State private var skipDuplicates = true
    @State private var overwriteExisting = false
    @State private var autoRenameConflicts = false
    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var currentImportIndex = 0
    @State private var importResults: [ImportResult] = []
    @State private var errorMessage: String?
    @State private var isDone = false

    struct ImportResult: Identifiable {
        let id = UUID()
        let filename: String
        let success: Bool
        let message: String
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Batch Import Banks",
                subtitle: "Import multiple .EB2 files at once",
                icon: "arrow.down.to.line.compact",
                onClose: { dismiss() }
            )

            Divider()

            if isDone {
                resultsView
            } else {
                configView
            }

            Divider()

            footerButtons
        }
        .frame(width: 680, height: 580)
        .onExitCommand { dismiss() }
    }

    // MARK: - Config View

    private var configView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // File picker
                filePickerSection

                // Target image
                targetSection

                // Options
                optionsSection

                // Progress
                if isImporting { progressSection }
            }
            .padding()
        }
    }

    private var filePickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("SOURCE FILES")

            if selectedFiles.isEmpty {
                Button {
                    pickFiles()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Select .EB2 Files…")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                }
                .buttonStyle(.bordered)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(selectedFiles.enumerated()), id: \.offset) { idx, url in
                        HStack(spacing: 10) {
                            Image(systemName: "waveform")
                                .foregroundStyle(Theme.accent)
                                .frame(width: 20)
                            Text(url.lastPathComponent)
                                .font(Theme.Typography.body)
                                .lineLimit(1)
                            Spacer()
                            let result = importResults.first(where: { $0.filename == url.lastPathComponent })
                            if let r = result {
                                Image(systemName: r.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(r.success ? Theme.success : Theme.danger)
                                    .font(.caption)
                            }
                            Button {
                                selectedFiles.remove(at: idx)
                            } label: {
                                Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(isImporting)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(idx % 2 == 0 ? Theme.bgCard : Theme.bgSurface)
                        if idx < selectedFiles.count - 1 { Divider() }
                    }
                }
                .cornerRadius(8)

                Button("Add More Files…") { pickFiles() }
                    .buttonStyle(.bordered)
                    .disabled(isImporting)
            }
        }
    }

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("TARGET DISK IMAGE")

            if appState.images.isEmpty {
                Text("No disk images available in current volume")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Target Image", selection: $targetImage) {
                    Text("Select…").tag(Optional<DiskImage>(nil))
                    ForEach(appState.images) { img in
                        Text(img.filename).tag(Optional(img))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("OPTIONS")

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Skip duplicate banks", isOn: $skipDuplicates)
                Toggle("Overwrite existing banks", isOn: $overwriteExisting)
                    .disabled(skipDuplicates)
                Toggle("Auto-rename conflicts", isOn: $autoRenameConflicts)
            }
            .font(Theme.Typography.body)
            .padding(12)
            .background(Theme.bgCard)
            .cornerRadius(8)
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Importing \(currentImportIndex) of \(selectedFiles.count)…")
                    .font(Theme.Typography.body)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(importProgress * 100))%")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: importProgress)
                .progressViewStyle(.linear)
                .tint(Theme.accent)
        }
        .padding(12)
        .background(Theme.bgCard)
        .cornerRadius(8)
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                let successes = importResults.filter { $0.success }.count
                let failures = importResults.filter { !$0.success }.count

                HStack(spacing: 20) {
                    resultStat("\(successes)", "Imported", Theme.success)
                    resultStat("\(failures)", "Failed", failures > 0 ? Theme.danger : .secondary)
                    resultStat("\(importResults.count)", "Total", .secondary)
                }
                .padding(12)
                .background(Theme.bgCard)
                .cornerRadius(8)

                ForEach(importResults) { result in
                    HStack(spacing: 10) {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.success ? Theme.success : Theme.danger)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.filename).font(Theme.Typography.body).lineLimit(1)
                            Text(result.message).font(Theme.Typography.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.bgCard)
                    .cornerRadius(6)
                }
            }
            .padding()
        }
    }

    private func resultStat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footerButtons: some View {
        HStack(spacing: 12) {
            Button(isDone ? "Close" : "Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Spacer()
            if !isDone {
                if let err = errorMessage {
                    Text(err).font(Theme.Typography.caption).foregroundStyle(Theme.danger).lineLimit(1)
                }
                Button("Import \(selectedFiles.count) Banks") { startImport() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(selectedFiles.isEmpty || targetImage == nil || isImporting)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(1)
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "eb2"), UTType(filenameExtension: "EB2")].compactMap { $0 }
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            let newFiles = panel.urls.filter { url in
                !selectedFiles.contains(url)
            }
            selectedFiles.append(contentsOf: newFiles)
        }
    }

    private func startImport() {
        guard let target = targetImage else { return }
        isImporting = true
        importProgress = 0
        currentImportIndex = 0
        importResults = []
        errorMessage = nil

        Task {
            for (idx, url) in selectedFiles.enumerated() {
                await MainActor.run {
                    currentImportIndex = idx + 1
                    importProgress = Double(idx) / Double(selectedFiles.count)
                }

                do {
                    try await Task.detached(priority: .userInitiated) {
                        try BankImporter.importBank(
                            eb2URL: url,
                            into: target.url,
                            allowDuplicate: !skipDuplicates
                        )
                    }.value
                    await MainActor.run {
                        importResults.append(ImportResult(
                            filename: url.lastPathComponent,
                            success: true,
                            message: "Imported successfully"
                        ))
                    }
                } catch {
                    await MainActor.run {
                        importResults.append(ImportResult(
                            filename: url.lastPathComponent,
                            success: false,
                            message: error.localizedDescription
                        ))
                    }
                }
            }

            await MainActor.run {
                importProgress = 1.0
                isImporting = false
                isDone = true
                appState.refreshImages()
            }
        }
    }
}
