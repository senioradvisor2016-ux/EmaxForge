import SwiftUI

/// Vintage-style preset parameter editor for EMAX II voice parameters
struct PresetEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var params: VoiceParameters
    
    let presetName: String
    var onApply: ((VoiceParameters) -> Void)?
    
    init(params: VoiceParameters = VoiceParameters(), presetName: String = "Untitled", onApply: ((VoiceParameters) -> Void)? = nil) {
        _params = State(initialValue: params)
        self.presetName = presetName
        self.onApply = onApply
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // VCA Section
                    paramSection(title: "VCA ENVELOPE", icon: "waveform.path.ecg") {
                        paramKnob(
                            label: "Attack",
                            value: Binding(
                                get: { params.vcaAttackNorm },
                                set: { params.vcaAttack = UInt16($0 * 65535) }
                            )
                        )
                        
                        paramKnob(
                            label: "Hold/Decay",
                            value: Binding(
                                get: { params.vcaHoldDecayNorm },
                                set: { params.vcaHoldDecay = UInt16($0 * 65535) }
                            )
                        )
                        
                        paramKnob(
                            label: "Sustain",
                            value: Binding(
                                get: { params.vcaSustainNorm },
                                set: { params.vcaSustain = UInt16($0 * 65535) }
                            )
                        )
                        
                        paramKnob(
                            label: "Release",
                            value: Binding(
                                get: { params.vcaReleaseNorm },
                                set: { params.vcaRelease = UInt16($0 * 65535) }
                            )
                        )
                    }
                    
                    // Filter Section
                    paramSection(title: "FILTER", icon: "slider.horizontal.3") {
                        paramKnob(
                            label: "Cutoff",
                            value: Binding(
                                get: { params.filterCutoffNorm },
                                set: { params.filterCutoff = UInt16($0 * 65535) }
                            ),
                            displayValue: "\(params.filterCutoffHz) Hz"
                        )
                        
                        paramKnob(
                            label: "Resonance",
                            value: Binding(
                                get: { params.filterQNorm },
                                set: { params.filterQ = UInt16($0 * 65535) }
                            )
                        )
                        
                        paramKnob(
                            label: "Env Amount",
                            value: Binding(
                                get: { params.filterEnvAmountNorm },
                                set: { params.filterEnvAmount = UInt16($0 * 65535) }
                            )
                        )
                    }
                    
                    // Filter Envelope
                    paramSection(title: "FILTER ENVELOPE", icon: "waveform") {
                        paramKnob(
                            label: "Attack",
                            value: Binding(
                                get: { params.filterAttackNorm },
                                set: { params.filterAttack = UInt16($0 * 65535) }
                            )
                        )
                        
                        paramKnob(
                            label: "Sustain",
                            value: Binding(
                                get: { params.filterSustainNorm },
                                set: { params.filterSustain = UInt16($0 * 65535) }
                            )
                        )
                        
                        paramKnob(
                            label: "Release",
                            value: Binding(
                                get: { params.filterReleaseNorm },
                                set: { params.filterRelease = UInt16($0 * 65535) }
                            )
                        )
                    }
                    
                    // Tuning & Mix
                    HStack(alignment: .top, spacing: 20) {
                        paramSection(title: "TUNING", icon: "tuningfork") {
                            paramKnob(
                                label: "Tune",
                                value: Binding(
                                    get: { params.tuneNorm },
                                    set: { params.tune = UInt16($0 * 65535) }
                                ),
                                displayValue: tuneDisplay
                            )
                            
                            paramKnob(
                                label: "Delay",
                                value: Binding(
                                    get: { params.delayNorm },
                                    set: { params.delay = UInt16($0 * 65535) }
                                )
                            )
                        }
                        
                        paramSection(title: "MIX", icon: "waveform.and.mic") {
                            paramKnob(
                                label: "Pan",
                                value: Binding(
                                    get: { params.panNorm },
                                    set: { params.pan = UInt16($0 * 65535) }
                                ),
                                displayValue: params.panLabel
                            )
                            
                            paramKnob(
                                label: "Chorus",
                                value: Binding(
                                    get: { params.chorusNorm },
                                    set: { params.chorus = UInt16($0 * 65535) }
                                )
                            )
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            footer
        }
        .frame(width: 900, height: 700)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.accentGradient)
                    .frame(width: 50, height: 50)
                    .shadow(color: .orange.opacity(0.3), radius: 4, y: 2)
                
                Image(systemName: "waveform.path")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Preset Editor")
                    .font(.headline)
                Text(presetName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Reset to Defaults") {
                params = VoiceParameters()
            }
            .buttonStyle(.bordered)
            
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
        .background(.bar)
    }
    
    // MARK: - Parameter Section
    
    private func paramSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .font(.headline.bold())
                    .tracking(1)
            }
            
            HStack(spacing: 24) {
                content()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    // MARK: - Knob
    
    private func paramKnob(
        label: String,
        value: Binding<Double>,
        displayValue: String? = nil
    ) -> some View {
        VStack(spacing: 10) {
            // Knob visualization
            ZStack {
                // Outer ring
                Circle()
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 3)
                    .frame(width: 80, height: 80)
                
                // Value arc
                Circle()
                    .trim(from: 0, to: value.wrappedValue)
                    .rotation(.degrees(-90))
                    .stroke(
                        Theme.accentGradient,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 76, height: 76)
                
                // Inner circle
                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: 64, height: 64)
                
                // Indicator line
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 2, height: 20)
                    .offset(y: -14)
                    .rotationEffect(.degrees(value.wrappedValue * 270 - 135))
                
                // Value display
                Text(displayValue ?? String(format: "%.0f", value.wrappedValue * 100))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let center = CGPoint(x: 40, y: 40)
                        let vector = CGPoint(
                            x: gesture.location.x - center.x,
                            y: gesture.location.y - center.y
                        )
                        let angle = atan2(vector.y, vector.x)
                        let degrees = angle * 180 / .pi + 90
                        let normalized = (degrees + 135) / 270
                        value.wrappedValue = max(0, min(1, normalized))
                    }
            )
            
            // Label
            Text(label.uppercased())
                .font(.caption2.bold())
                .tracking(0.5)
                .foregroundStyle(.secondary)
        }
        .frame(width: 90)
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            Spacer()
            
            Button("Cancel") { dismiss() }
                .buttonStyle(.bordered)
            
            Button("Apply") {
                onApply?(params)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private var tuneDisplay: String {
        let cents = Int((params.tuneNorm - 0.5) * 200) // ±100 cents
        return cents >= 0 ? "+\(cents)¢" : "\(cents)¢"
    }
}
