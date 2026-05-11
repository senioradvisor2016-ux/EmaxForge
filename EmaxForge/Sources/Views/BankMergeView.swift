import SwiftUI

/// Sheet for merging presets and samples from one bank into another
struct BankMergeView: View {
    let sourceBank: BankCatalogEntry
    let imageURL: URL
    let allBanks: [BankCatalogEntry]

    @Environment(\.dismiss) private var dismiss
    @State private var targetBank: BankCatalogEntry?
    @State private var skipDuplicatePresets = true
    @State private var skipDuplicateSamples = false
    @State private var isMerging = false
    @State private var result: BankMerger.MergeResult?
    @State private var errorMessage: String?

    private var targetBanks: [BankCatalogEntry] {
        allBanks.filter { $0.id != sourceBank.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Merge Bank",
                subtitle: "Copy presets and samples from \"\(sourceBank.name)\" into another bank",
                icon: "arrow.triangle.merge",
                onClose: { dismiss() }
            )

            Divider()

            if let result = result {
                successView(result)
            } else if isMerging {
                mergingView
            } else {
                mergeForm
            }
        }
        .frame(width: 540, height: 440)
        .onExitCommand { dismiss() }
        .onAppear {
            targetBank = targetBanks.first
        }
    }

    // MARK: - Form

    private var mergeForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Source info
            GroupBox {
                HStack {
                    Label("Source bank", systemImage: "folder")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Spacer()
                    Text(sourceBank.name)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(sourceBank.numPresets) preset(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Target picker
            GroupBox("Merge Into") {
                if targetBanks.isEmpty {
                    Text("No other banks available on this disk.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    Picker("Target bank", selection: $targetBank) {
                        Text("Select a bank…").tag(Optional<BankCatalogEntry>.none)
                        ForEach(targetBanks) { bank in
                            Text("\(bank.name)  (\(bank.numPresets) preset(s))")
                                .tag(Optional(bank))
                        }
                    }
                    .labelsHidden()

                    if let target = targetBank {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Merging \(sourceBank.numPresets) preset(s) from \"\(sourceBank.name)\" into \"\(target.name)\" (\(target.numPresets) preset(s))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
            }

            // Options
            GroupBox("Options") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Skip presets with duplicate names", isOn: $skipDuplicatePresets)
                    Toggle("Skip samples with duplicate names", isOn: $skipDuplicateSamples)
                }
            }

            if let err = errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }

            Spacer()

            // Action buttons
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape)

                Spacer()

                Button("Merge") { startMerge() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
                    .disabled(targetBank == nil || isMerging)
            }
        }
        .padding(20)
    }

    // MARK: - Progress

    private var mergingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
            Text("Merging banks…")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Success

    private func successView(_ r: BankMerger.MergeResult) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            VStack(spacing: 6) {
                Text("Merge Complete")
                    .font(.title2.bold())

                Text("\(r.presetsAdded) preset(s) and \(r.samplesAdded) sample(s) added")
                    .foregroundStyle(.secondary)

                if !r.presetNamesSkipped.isEmpty {
                    Text("\(r.presetNamesSkipped.count) duplicate preset(s) skipped")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !r.sampleNamesSkipped.isEmpty {
                    Text("\(r.sampleNamesSkipped.count) duplicate sample(s) skipped")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Action

    private func startMerge() {
        guard let target = targetBank else { return }
        isMerging = true
        errorMessage = nil

        let options = BankMerger.MergeOptions(
            skipDuplicatePresetNames: skipDuplicatePresets,
            skipDuplicateSampleNames: skipDuplicateSamples
        )
        let src = sourceBank
        let url = imageURL

        Task.detached(priority: .userInitiated) {
            do {
                let r = try BankMerger.merge(source: src, into: target, imageURL: url, options: options)
                await MainActor.run {
                    isMerging = false
                    result = r
                }
            } catch {
                await MainActor.run {
                    isMerging = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
