import SwiftUI

/// Visual key-map editor for EMAX II preset voice zones.
///
/// Displays the 88-key map (MIDI 21–108) as coloured cells, lets the user
/// select a sample and assign it to a contiguous key range, and writes the
/// change back to disk via `VoiceZoneEditor.assignSampleToKeyRange`.
struct VoiceZoneEditorView: View {

    let bankEntry: BankCatalogEntry
    let imageURL: URL
    let initialPresetIndex: Int
    let presetNames: [String]           // all preset names in the bank (0-based)
    let samples: [BankSampleData.SampleEntry]

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var activePresetIndex: Int
    @State private var keyMap: [UInt8] = Array(repeating: 0xFF, count: 88) // 0xFF = unassigned
    @State private var selectedSampleIndex: Int = 0
    @State private var lowKey: Int = 48   // C3
    @State private var highKey: Int = 72  // C5

    init(bankEntry: BankCatalogEntry, imageURL: URL, initialPresetIndex: Int,
         presetNames: [String], samples: [BankSampleData.SampleEntry]) {
        self.bankEntry = bankEntry
        self.imageURL = imageURL
        self.initialPresetIndex = initialPresetIndex
        self.presetNames = presetNames
        self.samples = samples
        _activePresetIndex = State(initialValue: initialPresetIndex)
    }
    @State private var isSaving = false
    @State private var statusMessage: String? = nil
    @State private var errorMessage: String? = nil

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Voice Zone Editor",
                subtitle: bankEntry.name,
                icon: "pianokeys",
                onClose: { dismiss() }
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Preset selector ───────────────────────────────────
                    HStack {
                        Text("Preset")
                        Picker("", selection: $activePresetIndex) {
                            ForEach(presetNames.indices, id: \.self) { i in
                                Text("\(i + 1): \(presetNames[i].isEmpty ? "(unnamed)" : presetNames[i])")
                                    .tag(i)
                            }
                        }
                        .frame(maxWidth: 300)
                        .onChange(of: activePresetIndex) { _, _ in
                            Task { await loadKeyMap() }
                        }
                    }

                    // ── Key map visualisation ──────────────────────────────
                    GroupBox("Key Map  (A0 – C8)") {
                        keyMapGrid
                            .padding(.vertical, 6)
                    }

                    // ── Sample + range controls ───────────────────────────
                    GroupBox("Assignment") {
                        VStack(alignment: .leading, spacing: 14) {

                            // Sample picker
                            HStack {
                                Text("Sample")
                                    .frame(width: 70, alignment: .trailing)
                                if samples.isEmpty {
                                    Text("No samples in bank")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                } else {
                                    Picker("", selection: $selectedSampleIndex) {
                                        ForEach(samples) { s in
                                            Text(s.name.isEmpty ? "Sample \(s.index)" : s.name)
                                                .tag(s.index)
                                        }
                                    }
                                    .frame(maxWidth: 260)
                                }
                            }

                            // Low key
                            HStack {
                                Text("Low Key")
                                    .frame(width: 70, alignment: .trailing)
                                Slider(value: Binding(
                                    get: { Double(lowKey) },
                                    set: { lowKey = min(Int($0), highKey) }
                                ), in: 21...108, step: 1)
                                Text(midiNoteName(lowKey))
                                    .font(.caption.monospacedDigit())
                                    .frame(width: 36)
                            }

                            // High key
                            HStack {
                                Text("High Key")
                                    .frame(width: 70, alignment: .trailing)
                                Slider(value: Binding(
                                    get: { Double(highKey) },
                                    set: { highKey = max(Int($0), lowKey) }
                                ), in: 21...108, step: 1)
                                Text(midiNoteName(highKey))
                                    .font(.caption.monospacedDigit())
                                    .frame(width: 36)
                            }

                            // Range summary
                            HStack {
                                Spacer()
                                Text("\(midiNoteName(lowKey)) – \(midiNoteName(highKey))  (\(highKey - lowKey + 1) key\(highKey == lowKey ? "" : "s"))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // ── Clear controls ─────────────────────────────────────
                    GroupBox("Clear") {
                        HStack(spacing: 12) {
                            Button("Clear Selected Sample from All Keys") {
                                clearSelectedSample()
                            }
                            .buttonStyle(.bordered)
                            .disabled(samples.isEmpty || isSaving)

                            Button("Clear Entire Key Map") {
                                clearAllKeys()
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .disabled(isSaving)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
            }

            // ── Status bar ─────────────────────────────────────────────────
            if let msg = statusMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(msg).font(.caption)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(.bar)
            }

            if let err = errorMessage {
                HStack {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    Text(err).font(.caption)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(.bar)
            }

            Divider()

            // ── Footer ─────────────────────────────────────────────────────
            HStack {
                if isSaving {
                    ProgressView().scaleEffect(0.7)
                    Text("Saving…").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Assign \(midiNoteName(lowKey))–\(midiNoteName(highKey)) → \(selectedSampleName)") {
                    assignRange()
                }
                .buttonStyle(.borderedProminent)
                .disabled(samples.isEmpty || isSaving)
                .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(minWidth: 640, idealWidth: 700, minHeight: 500, idealHeight: 560)
        .task(id: activePresetIndex) { await loadKeyMap() }
    }

    // MARK: - Key Map Grid

    private var keyMapGrid: some View {
        // 88 keys in rows of 22 for readability
        let rows = stride(from: 0, to: 88, by: 22).map { Array($0..<min($0+22, 88)) }

        return VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 1) {
                    ForEach(row, id: \.self) { idx in
                        let midi = idx + 21
                        let assigned = keyMap[idx]
                        let inRange = midi >= lowKey && midi <= highKey

                        Rectangle()
                            .fill(cellColor(for: assigned, inRange: inRange))
                            .frame(width: 20, height: 24)
                            .cornerRadius(2)
                            .overlay(
                                // C-note labels
                                Group {
                                    if midi % 12 == 0 {
                                        Text("C\(midi / 12 - 1)")
                                            .font(.system(size: 6))
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                }
                            )
                            .help(keyHelp(idx: idx, midi: midi, assigned: assigned))
                            .onTapGesture {
                                // Single-click: set both endpoints to this key
                                lowKey = midi
                                highKey = midi
                            }
                    }
                }
            }

            // Legend
            HStack(spacing: 12) {
                legendItem(color: .gray.opacity(0.3), label: "Unassigned")
                legendItem(color: .blue.opacity(0.5), label: "In range")
                ForEach(0..<min(samples.count, 5), id: \.self) { i in
                    legendItem(color: sampleColor(UInt8(samples[i].index)), label: samples[i].name.isEmpty ? "#\(i)" : samples[i].name)
                }
            }
            .font(.caption2)
            .padding(.top, 4)
        }
    }

    private func cellColor(for assigned: UInt8, inRange: Bool) -> Color {
        if inRange { return .blue.opacity(0.35) }
        if assigned == 0xFF { return .gray.opacity(0.2) }
        return sampleColor(assigned)
    }

    private func sampleColor(_ idx: UInt8) -> Color {
        let palette: [Color] = [.green, .orange, .purple, .red, .yellow, .teal, .pink, .indigo]
        return palette[Int(idx) % palette.count].opacity(0.65)
    }

    private func keyHelp(idx: Int, midi: Int, assigned: UInt8) -> String {
        let note = midiNoteName(midi)
        if assigned == 0xFF { return "\(note): unassigned" }
        let sName = samples.first(where: { $0.index == Int(assigned) })?.name ?? "Sample \(assigned)"
        return "\(note): \(sName)"
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 10)
            Text(label).foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var selectedSampleName: String {
        samples.first(where: { $0.index == selectedSampleIndex })?.name.nonEmpty ?? "Sample \(selectedSampleIndex)"
    }

    private func midiNoteName(_ midi: Int) -> String {
        let names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        let note = names[midi % 12]
        let octave = midi / 12 - 1
        return "\(note)\(octave)"
    }

    // MARK: - Load key map

    @MainActor
    private func loadKeyMap() async {
        do {
            let geo      = try BankDataWriter.loadGeometry(from: imageURL)
            let bankData = try BankDataWriter.readBankData(entry: bankEntry, from: imageURL, geometry: geo)
            let blockBase  = 0x200 + activePresetIndex * 0x100
            let keyMapBase = blockBase + 0x24
            guard keyMapBase + 88 <= bankData.count else { return }
            for i in 0..<88 {
                keyMap[i] = bankData[keyMapBase + i]
            }
        } catch {
            errorMessage = "Could not load key map: \(error.localizedDescription)"
        }
    }

    // MARK: - Actions

    private func assignRange() {
        isSaving = true
        statusMessage = nil
        errorMessage = nil

        Task {
            do {
                let result = try VoiceZoneEditor.assignSampleToKeyRange(
                    presetIndex: activePresetIndex,
                    midiKeyLow: lowKey,
                    midiKeyHigh: highKey,
                    sampleIndex: UInt8(selectedSampleIndex),
                    in: bankEntry,
                    imageURL: imageURL
                )
                await MainActor.run {
                    // Update local key map display
                    for midi in lowKey...highKey {
                        keyMap[midi - 21] = UInt8(selectedSampleIndex)
                    }
                    isSaving = false
                    statusMessage = "\(midiNoteName(lowKey))–\(midiNoteName(highKey)) → \(selectedSampleName) (\(result.keyMapBytesWritten) keys, \(result.zoneCount) zone\(result.zoneCount == 1 ? "" : "s"))"
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func clearSelectedSample() {
        isSaving = true
        statusMessage = nil
        errorMessage = nil

        Task {
            do {
                let result = try VoiceZoneEditor.clearSampleAssignments(
                    sampleIndex: UInt8(selectedSampleIndex),
                    presetIndex: activePresetIndex,
                    in: bankEntry,
                    imageURL: imageURL
                )
                await MainActor.run {
                    // Update local display
                    for i in 0..<88 where keyMap[i] == UInt8(selectedSampleIndex) {
                        keyMap[i] = 0xFF
                    }
                    isSaving = false
                    statusMessage = "Cleared \(selectedSampleName) from \(result.keyMapBytesWritten) key\(result.keyMapBytesWritten == 1 ? "" : "s")"
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func clearAllKeys() {
        // Clear entire key map by assigning 0xFF to all 88 keys in one range
        // We'll do this by looping through each unique assigned sample
        isSaving = true
        statusMessage = nil
        errorMessage = nil

        let uniqueAssigned = Set(keyMap.filter { $0 != 0xFF })
        if uniqueAssigned.isEmpty {
            isSaving = false
            statusMessage = "Key map already empty"
            return
        }

        Task {
            do {
                for sIdx in uniqueAssigned {
                    _ = try VoiceZoneEditor.clearSampleAssignments(
                        sampleIndex: sIdx,
                        presetIndex: activePresetIndex,
                        in: bankEntry,
                        imageURL: imageURL
                    )
                }
                await MainActor.run {
                    keyMap = Array(repeating: 0xFF, count: 88)
                    isSaving = false
                    statusMessage = "Key map cleared ✓"
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - String helper

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Preview

#if DEBUG
struct VoiceZoneEditorView_Previews: PreviewProvider {
    static var previews: some View {
        Text("VoiceZoneEditorView requires live bank data")
    }
}
#endif
