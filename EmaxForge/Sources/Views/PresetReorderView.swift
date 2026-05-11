import SwiftUI

/// Sheet for reordering presets within an EMAX II bank via drag-to-reorder or up/down buttons
struct PresetReorderView: View {
    let bankEntry: BankCatalogEntry
    let imageURL: URL

    @Environment(\.dismiss) private var dismiss

    @State private var presetNames: [String] = []
    @State private var isLoading = true
    @State private var isApplying = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    // Track how many moves are pending (original index → current position mapping
    // is implicit in the array order)
    @State private var originalOrder: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Reorder Presets",
                subtitle: "\"\(bankEntry.name)\" — drag or use arrows to reorder",
                icon: "arrow.up.arrow.down",
                onClose: { dismiss() }
            )

            Divider()

            if isLoading {
                loadingView
            } else if let err = errorMessage {
                errorView(err)
            } else {
                contentView
            }
        }
        .frame(width: 480, height: 560)
        .onExitCommand { dismiss() }
        .onAppear { loadPresetNames() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading presets…")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding()
            Button("Close") { dismiss() }
                .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(spacing: 0) {
            if presetNames.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No presets found in this bank.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(presetNames.enumerated()), id: \.offset) { index, name in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .frame(width: 28, alignment: .trailing)

                            Text(name)
                                .font(.system(.body, design: .monospaced))

                            Spacer()

                            // Up/down buttons
                            HStack(spacing: 4) {
                                Button {
                                    moveUp(index)
                                } label: {
                                    Image(systemName: "chevron.up")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .disabled(index == 0 || isApplying)

                                Button {
                                    moveDown(index)
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .disabled(index == presetNames.count - 1 || isApplying)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove { source, destination in
                        presetNames.move(fromOffsets: source, toOffset: destination)
                    }
                }
                .listStyle(.inset)
            }

            if let msg = successMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Divider()

            HStack {
                Button("Reset") {
                    presetNames = originalOrder
                    successMessage = nil
                }
                .buttonStyle(.bordered)
                .disabled(isApplying || presetNames == originalOrder)

                Spacer()

                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape)

                if isApplying {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.leading, 8)
                } else {
                    Button("Apply") { applyReorder() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return)
                        .disabled(presetNames == originalOrder)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Move helpers

    private func moveUp(_ index: Int) {
        guard index > 0 else { return }
        presetNames.swapAt(index, index - 1)
    }

    private func moveDown(_ index: Int) {
        guard index < presetNames.count - 1 else { return }
        presetNames.swapAt(index, index + 1)
    }

    // MARK: - Load preset names from raw bank data

    private func loadPresetNames() {
        isLoading = true
        let entry = bankEntry
        let url = imageURL

        Task.detached(priority: .userInitiated) {
            var names: [String] = []
            do {
                let geo = try BankDataWriter.loadGeometry(from: url)
                let rawData = try BankDataWriter.readBankData(entry: entry, from: url, geometry: geo)
                names = Self.extractPresetNames(from: rawData)
            } catch {
                await MainActor.run {
                    errorMessage = "Could not read bank: \(error.localizedDescription)"
                    isLoading = false
                }
                return
            }
            await MainActor.run {
                presetNames = names
                originalOrder = names
                isLoading = false
            }
        }
    }

    /// Extract non-empty preset names from raw EMX bank data.
    /// Preset area starts at 0x200, 256-byte blocks, name at +0x00 (12 bytes, NUL-terminated).
    private static func extractPresetNames(from data: Data) -> [String] {
        var names: [String] = []
        let presetAreaOffset = 0x200
        let presetSize = 0x100
        let nameLength = 12
        let maxPresets = 256

        for i in 0..<maxPresets {
            let base = presetAreaOffset + i * presetSize
            guard base + nameLength <= data.count else { break }
            var chars: [Character] = []
            for b in data[base ..< base + nameLength] {
                if b == 0 { break }
                if b >= 32 && b < 127 { chars.append(Character(UnicodeScalar(b))) }
            }
            let name = String(chars).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                names.append(name)
            }
        }
        return names
    }

    // MARK: - Apply reorder

    private func applyReorder() {
        guard presetNames != originalOrder else { return }
        isApplying = true
        errorMessage = nil
        successMessage = nil

        // Build list of moves: simulate the moves needed to go from originalOrder → presetNames.
        // Strategy: for each position in the desired order, if the name isn't already there,
        // find it in the current (simulated) order and move it.
        let desired = presetNames
        let entry = bankEntry
        let url = imageURL

        Task.detached(priority: .userInitiated) {
            var current = originalOrder  // tracks current state of preset slots
            var moves: [(from: Int, to: Int)] = []

            for targetIdx in 0..<desired.count {
                let desiredName = desired[targetIdx]
                guard let currentIdx = current.firstIndex(of: desiredName) else { continue }
                if currentIdx != targetIdx {
                    // Move from currentIdx to targetIdx
                    moves.append((from: currentIdx, to: targetIdx))
                    // Simulate the rotation in 'current'
                    let item = current.remove(at: currentIdx)
                    current.insert(item, at: targetIdx)
                }
            }

            var applyError: String? = nil
            for move in moves {
                do {
                    _ = try PresetReorderer.movePreset(
                        from: move.from,
                        to: move.to,
                        in: entry,
                        imageURL: url
                    )
                } catch {
                    applyError = error.localizedDescription
                    break
                }
            }

            await MainActor.run {
                isApplying = false
                if let err = applyError {
                    errorMessage = err
                } else {
                    originalOrder = desired
                    successMessage = "Reorder applied (\(moves.count) move(s))"
                }
            }
        }
    }
}
