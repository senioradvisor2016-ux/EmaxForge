import SwiftUI

/// Batch-process multiple samples in a bank: normalize, trim, fade, reverse, pitch-shift, set rate.
struct BatchSampleProcessingView: View {
    let bankEntry: BankCatalogEntry
    let imageURL: URL
    let samples: [BankSampleData.SampleEntry]

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedIndices: Set<Int> = []
    @State private var operation: BatchOperation = .normalize
    @State private var isProcessing = false
    @State private var progress: Double = 0
    @State private var results: [BatchResult] = []
    @State private var errorMessage: String? = nil

    // Operation-specific params
    @State private var fadeDuration: Double = 0.05       // seconds
    @State private var gainDB: Double = 0.0
    @State private var pitchSemitones: Double = 0.0
    @State private var targetRate: UInt16 = 22050
    @State private var trimThreshold: Float = 0.01

    // MARK: - Types

    enum BatchOperation: String, CaseIterable, Identifiable {
        case normalize   = "Normalize"
        case trimSilence = "Trim Silence"
        case fadeIn      = "Fade In"
        case fadeOut     = "Fade Out"
        case reverse     = "Reverse"
        case applyGain   = "Apply Gain"
        case shiftPitch  = "Shift Pitch"
        case setRate     = "Set Sample Rate"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .normalize:   return "waveform.path.ecg"
            case .trimSilence: return "scissors"
            case .fadeIn:      return "arrow.up.right"
            case .fadeOut:     return "arrow.down.right"
            case .reverse:     return "arrow.left.arrow.right"
            case .applyGain:   return "slider.horizontal.3"
            case .shiftPitch:  return "music.note"
            case .setRate:     return "metronome"
            }
        }

        var writesToDisk: Bool {
            switch self {
            case .shiftPitch, .setRate: return true
            default: return false  // these edit in-memory PCM then write back via PCMReallocator
            }
        }
    }

    struct BatchResult: Identifiable {
        let id = UUID()
        let sampleName: String
        let sampleIndex: Int
        let success: Bool
        let message: String
    }

    // MARK: - Computed

    private var selectedCount: Int { selectedIndices.count }

    private var allSelected: Bool {
        !samples.isEmpty && selectedIndices.count == samples.count
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Batch Sample Processing",
                subtitle: "\(samples.count) sample(s) in \(bankEntry.name)",
                icon: "waveform.badge.magnifyingglass",
                onClose: { dismiss() }
            )

            Divider()

            HSplitView {
                // Left: sample list
                sampleListPanel
                    .frame(minWidth: 260, idealWidth: 280)

                // Right: operation controls + results
                VStack(spacing: 0) {
                    operationPanel
                    Divider()
                    resultsPanel
                }
            }

            Divider()

            // Footer
            HStack {
                if isProcessing {
                    ProgressView(value: progress)
                        .frame(maxWidth: 200)
                    Text("Processing \(Int(progress * Double(selectedCount)))/\(selectedCount)…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let err = errorMessage {
                    Label(err, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Process \(selectedCount) Sample\(selectedCount == 1 ? "" : "s")") {
                    Task { await processSelected() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCount == 0 || isProcessing)
                .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(minWidth: 760, idealWidth: 860, minHeight: 540, idealHeight: 600)
        .disabled(isProcessing)
    }

    // MARK: - Sample List Panel

    private var sampleListPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Samples")
                    .font(.headline)
                Spacer()
                Button(allSelected ? "Deselect All" : "Select All") {
                    if allSelected {
                        selectedIndices.removeAll()
                    } else {
                        selectedIndices = Set(samples.map(\.index))
                    }
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            List(samples, id: \.index, selection: $selectedIndices) { sample in
                HStack(spacing: 8) {
                    Toggle("", isOn: Binding(
                        get: { selectedIndices.contains(sample.index) },
                        set: { on in
                            if on { selectedIndices.insert(sample.index) }
                            else  { selectedIndices.remove(sample.index) }
                        }
                    ))
                    .labelsHidden()

                    VStack(alignment: .leading, spacing: 2) {
                        Text(sample.name.isEmpty ? "Sample \(sample.index)" : sample.name)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                        Text("\(sample.sampleRate) Hz · \(String(format: "%.2f s", sample.duration))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Operation Panel

    private var operationPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Operation")
                .font(.headline)

            // Operation picker
            Picker("", selection: $operation) {
                ForEach(BatchOperation.allCases) { op in
                    Label(op.rawValue, systemImage: op.icon).tag(op)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 260)

            // Operation-specific controls
            operationControls
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var operationControls: some View {
        switch operation {
        case .normalize:
            Text("Scales PCM so the peak sample equals full scale (0 dBFS).")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .trimSilence:
            VStack(alignment: .leading, spacing: 8) {
                Text("Remove leading and trailing silence below threshold.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Threshold")
                    Slider(value: $trimThreshold, in: 0.001...0.1, step: 0.001)
                    Text(String(format: "%.3f", trimThreshold))
                        .font(.caption.monospacedDigit())
                        .frame(width: 44)
                }
            }

        case .fadeIn, .fadeOut:
            HStack {
                Text("Duration")
                Slider(value: $fadeDuration, in: 0.001...1.0, step: 0.001)
                Text(String(format: "%.3f s", fadeDuration))
                    .font(.caption.monospacedDigit())
                    .frame(width: 60)
            }

        case .applyGain:
            HStack {
                Text("Gain (dB)")
                Slider(value: $gainDB, in: -24...24, step: 0.5)
                Text(String(format: "%+.1f dB", gainDB))
                    .font(.caption.monospacedDigit())
                    .frame(width: 64)
            }

        case .shiftPitch:
            VStack(alignment: .leading, spacing: 8) {
                Text("Changes the stored sample rate. EMAX II controls pitch via playback rate.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Semitones")
                    Slider(value: $pitchSemitones, in: -24...24, step: 0.5)
                    Text(String(format: "%+.1f", pitchSemitones))
                        .font(.caption.monospacedDigit())
                        .frame(width: 44)
                }
            }

        case .setRate:
            VStack(alignment: .leading, spacing: 8) {
                Text("Set an explicit EMAX II–supported sample rate for all selected samples.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Rate", selection: $targetRate) {
                    ForEach(PitchShifter.supportedRates, id: \.self) { rate in
                        Text("\(rate) Hz").tag(rate)
                    }
                }
                .frame(maxWidth: 200)
            }

        case .reverse:
            Text("Reverses the PCM buffer of each selected sample.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Results Panel

    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !results.isEmpty {
                HStack {
                    Text("Results")
                        .font(.headline)
                    Spacer()
                    let ok  = results.filter(\.success).count
                    let bad = results.filter { !$0.success }.count
                    if ok  > 0 { Label("\(ok) ok",   systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.caption) }
                    if bad > 0 { Label("\(bad) failed", systemImage: "xmark.circle.fill").foregroundStyle(.red).font(.caption) }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(results) { result in
                            HStack(spacing: 8) {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result.success ? .green : .red)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(result.sampleName)
                                        .font(.system(.caption, design: .monospaced))
                                    Text(result.message)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                VStack {
                    Spacer()
                    Text(isProcessing ? "Processing…" : "Results will appear here after processing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Processing

    @MainActor
    private func processSelected() async {
        guard !selectedIndices.isEmpty else { return }
        results.removeAll()
        errorMessage = nil
        isProcessing = true
        progress = 0

        let ordered = samples.filter { selectedIndices.contains($0.index) }
        let total = Double(ordered.count)

        for (i, sample) in ordered.enumerated() {
            let name = sample.name.isEmpty ? "Sample \(sample.index)" : sample.name
            do {
                try await processSample(sample)
                results.append(BatchResult(
                    sampleName: name,
                    sampleIndex: sample.index,
                    success: true,
                    message: operationSuccessMessage(for: sample)
                ))
            } catch {
                results.append(BatchResult(
                    sampleName: name,
                    sampleIndex: sample.index,
                    success: false,
                    message: error.localizedDescription
                ))
            }
            progress = Double(i + 1) / total
        }

        isProcessing = false
    }

    private func processSample(_ sample: BankSampleData.SampleEntry) async throws {
        switch operation {
        case .shiftPitch:
            try PitchShifter.shiftBySemitones(
                pitchSemitones,
                sampleIndex: sample.index,
                in: bankEntry,
                imageURL: imageURL
            )

        case .setRate:
            try PitchShifter.setSampleRate(
                targetRate,
                sampleIndex: sample.index,
                in: bankEntry,
                imageURL: imageURL
            )

        case .normalize, .trimSilence, .fadeIn, .fadeOut, .reverse, .applyGain:
            // These operations modify PCM — read, process, write back via PCMReallocator
            let edited = try editPCM(sample.pcmData, operation: operation,
                                     sampleRate: sample.sampleRate)
            try PCMReallocator.replaceSamplePCM(
                bankEntry: bankEntry,
                sampleIndex: sample.index,
                newPCM: edited,
                imageURL: imageURL
            )
        }
    }

    private func editPCM(_ pcm: Data, operation: BatchOperation, sampleRate: Int) throws -> Data {
        switch operation {
        case .normalize:
            return SampleEditor.normalize(pcmData: pcm)
        case .trimSilence:
            return SampleEditor.trimSilence(pcmData: pcm, threshold: trimThreshold)
        case .fadeIn:
            return SampleEditor.fadeIn(pcmData: pcm,
                                       durationMs: fadeDuration * 1000,
                                       sampleRate: Double(sampleRate))
        case .fadeOut:
            return SampleEditor.fadeOut(pcmData: pcm,
                                        durationMs: fadeDuration * 1000,
                                        sampleRate: Double(sampleRate))
        case .reverse:
            return SampleEditor.reverse(pcmData: pcm)
        case .applyGain:
            return SampleEditor.changeGain(pcmData: pcm, gainDb: Float(gainDB))
        default:
            return pcm
        }
    }

    private func operationSuccessMessage(for sample: BankSampleData.SampleEntry) -> String {
        switch operation {
        case .normalize:   return "Normalized"
        case .trimSilence: return "Silence trimmed"
        case .fadeIn:      return String(format: "Fade in %.3f s applied", fadeDuration)
        case .fadeOut:     return String(format: "Fade out %.3f s applied", fadeDuration)
        case .reverse:     return "Reversed"
        case .applyGain:   return String(format: "%+.1f dB applied", gainDB)
        case .shiftPitch:  return String(format: "%+.1f semitones applied", pitchSemitones)
        case .setRate:     return "\(targetRate) Hz set"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct BatchSampleProcessingView_Previews: PreviewProvider {
    static var previews: some View {
        Text("BatchSampleProcessingView requires live data")
    }
}
#endif
