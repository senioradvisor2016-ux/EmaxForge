import SwiftUI

/// Visual waveform editor for trimming, fading, and normalizing samples
struct WaveformEditorView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var samplePlayer = SamplePlayer()
    
    let originalPCM: Data
    let sampleRate: Double
    let sampleName: String
    var onApply: ((Data) -> Void)?
    
    @State private var editedPCM: Data
    @State private var waveformSamples: [Float] = []
    
    // Selection
    @State private var startFrame: Int = 0
    @State private var endFrame: Int
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    
    // Edit parameters
    @State private var fadeInMs: Double = 0
    @State private var fadeOutMs: Double = 0
    @State private var normalizeEnabled = false
    @State private var trimSilenceEnabled = false
    @State private var silenceThreshold: Float = 0.01
    
    // Stats
    @State private var currentPeak: Float = 0
    @State private var originalPeak: Float = 0
    
    init(pcmData: Data, sampleRate: Double, sampleName: String, onApply: ((Data) -> Void)? = nil) {
        self.originalPCM = pcmData
        self.sampleRate = sampleRate
        self.sampleName = sampleName
        self.onApply = onApply
        
        let frames = pcmData.count / 2
        _editedPCM = State(initialValue: pcmData)
        _endFrame = State(initialValue: frames)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Waveform display with selection
                    waveformSection
                    
                    // Edit controls
                    editControls
                    
                    // Stats
                    statsSection
                }
                .padding()
            }
            
            Divider()
            footer
        }
        .frame(width: 800, height: 600)
        .onAppear {
            updateWaveform()
            originalPeak = SampleEditor.getPeak(pcmData: originalPCM)
            currentPeak = originalPeak
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path")
                .font(.title2)
                .foregroundStyle(Theme.accent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Sample Editor")
                    .font(.headline)
                Text(sampleName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Preview toggle
            Button {
                if samplePlayer.isPlaying {
                    samplePlayer.stop()
                } else {
                    samplePlayer.play(pcmData: editedPCM, sampleRate: sampleRate)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: samplePlayer.isPlaying ? "stop.fill" : "play.fill")
                    Text(samplePlayer.isPlaying ? "Stop" : "Preview")
                }
            }
            .buttonStyle(.bordered)
            .tint(samplePlayer.isPlaying ? Theme.danger : Theme.accent)
            
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
        .background(.bar)
    }
    
    // MARK: - Waveform
    
    private var waveformSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Waveform")
                    .font(.headline)
                
                Spacer()
                
                Text(selectedDurationText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            
            ZStack(alignment: .leading) {
                // Full waveform (dimmed)
                WaveformView(samples: waveformSamples, accentColor: .gray)
                    .opacity(0.3)
                    .frame(height: 120)
                
                // Selected region overlay
                GeometryReader { geo in
                    let width = geo.size.width
                    let totalFrames = originalPCM.count / 2
                    
                    let startX = width * CGFloat(startFrame) / CGFloat(totalFrames)
                    let endX = width * CGFloat(endFrame) / CGFloat(totalFrames)
                    let selectionWidth = endX - startX
                    
                    // Selected region highlight
                    Rectangle()
                        .fill(Theme.accent.opacity(0.15))
                        .frame(width: selectionWidth, height: geo.size.height)
                        .offset(x: startX)
                    
                    // Start marker
                    markerView(color: .green, isStart: true)
                        .offset(x: startX - 1)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingStart = true
                                    let newFrame = Int((value.location.x / width) * CGFloat(totalFrames))
                                    startFrame = max(0, min(newFrame, endFrame - 1))
                                    applyEdits()
                                }
                                .onEnded { _ in
                                    isDraggingStart = false
                                }
                        )
                    
                    // End marker
                    markerView(color: .red, isStart: false)
                        .offset(x: endX - 1)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingEnd = true
                                    let newFrame = Int((value.location.x / width) * CGFloat(totalFrames))
                                    endFrame = max(startFrame + 1, min(newFrame, totalFrames))
                                    applyEdits()
                                }
                                .onEnded { _ in
                                    isDraggingEnd = false
                                }
                        )
                }
                .frame(height: 120)
            }
            .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            
            // Selection info
            HStack(spacing: 16) {
                Label("Start: \(startFrame)", systemImage: "arrow.right.to.line")
                    .font(.caption)
                    .foregroundStyle(.green)
                
                Label("End: \(endFrame)", systemImage: "arrow.left.to.line")
                    .font(.caption)
                    .foregroundStyle(.red)
                
                Spacer()
                
                Button("Reset Selection") {
                    startFrame = 0
                    endFrame = originalPCM.count / 2
                    applyEdits()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(Theme.bgCard.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }
    
    private func markerView(color: Color, isStart: Bool) -> some View {
        VStack(spacing: 0) {
            Image(systemName: isStart ? "arrowtriangle.down.fill" : "arrowtriangle.down.fill")
                .font(.caption2)
                .foregroundStyle(color)
                .rotationEffect(.degrees(isStart ? 0 : 180))
            
            Rectangle()
                .fill(color)
                .frame(width: 2)
        }
        .frame(height: 120)
    }
    
    // MARK: - Edit Controls
    
    private var editControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Processing")
                .font(.headline)
            
            // Trim Silence
            Toggle("Trim Silence", isOn: $trimSilenceEnabled)
                .onChange(of: trimSilenceEnabled) { _, _ in applyEdits() }
            
            if trimSilenceEnabled {
                HStack {
                    Text("Threshold:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $silenceThreshold, in: 0.001...0.1)
                        .onChange(of: silenceThreshold) { _, _ in applyEdits() }
                    Text(String(format: "%.3f", silenceThreshold))
                        .font(.caption.monospaced())
                        .frame(width: 50)
                }
            }
            
            Divider()
            
            // Fade In
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Fade In")
                        .font(.subheadline.bold())
                    Spacer()
                    Text("\(Int(fadeInMs)) ms")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                
                Slider(value: $fadeInMs, in: 0...500)
                    .onChange(of: fadeInMs) { _, _ in applyEdits() }
            }
            
            // Fade Out
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Fade Out")
                        .font(.subheadline.bold())
                    Spacer()
                    Text("\(Int(fadeOutMs)) ms")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                
                Slider(value: $fadeOutMs, in: 0...500)
                    .onChange(of: fadeOutMs) { _, _ in applyEdits() }
            }
            
            Divider()
            
            // Normalize
            Toggle("Normalize (100% peak)", isOn: $normalizeEnabled)
                .onChange(of: normalizeEnabled) { _, _ in applyEdits() }
        }
        .padding(16)
        .background(Theme.bgCard.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Stats
    
    private var statsSection: some View {
        HStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Original")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 16) {
                    statRow(label: "Peak", value: String(format: "%.1f%%", originalPeak * 100))
                    statRow(label: "Frames", value: "\(originalPCM.count / 2)")
                    statRow(label: "Duration", value: SamplePlayer.formatDuration(Double(originalPCM.count / 2) / sampleRate))
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Edited")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.accent)
                
                HStack(spacing: 16) {
                    statRow(label: "Peak", value: String(format: "%.1f%%", currentPeak * 100))
                    statRow(label: "Frames", value: "\(editedPCM.count / 2)")
                    statRow(label: "Duration", value: SamplePlayer.formatDuration(Double(editedPCM.count / 2) / sampleRate))
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Theme.bgCard.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }
    
    private func statRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption.monospaced())
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack(spacing: 12) {
            // Reset button
            Button("Reset All") {
                startFrame = 0
                endFrame = originalPCM.count / 2
                fadeInMs = 0
                fadeOutMs = 0
                normalizeEnabled = false
                trimSilenceEnabled = false
                applyEdits()
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button("Cancel") { dismiss() }
                .buttonStyle(.bordered)
            
            Button("Apply") {
                onApply?(editedPCM)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(editedPCM == originalPCM)
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private var selectedDurationText: String {
        let selectedFrames = endFrame - startFrame
        let duration = Double(selectedFrames) / sampleRate
        return SamplePlayer.formatDuration(duration)
    }
    
    private func updateWaveform() {
        waveformSamples = SamplePlayer.waveformSamples(from: editedPCM, targetPoints: 400)
    }
    
    private func applyEdits() {
        var result = originalPCM
        
        // 1. Crop/trim selection
        if startFrame > 0 || endFrame < (originalPCM.count / 2) {
            result = SampleEditor.crop(pcmData: result, startFrame: startFrame, endFrame: endFrame)
        }
        
        // 2. Trim silence
        if trimSilenceEnabled {
            result = SampleEditor.trimSilence(pcmData: result, threshold: silenceThreshold)
        }
        
        // 3. Fades
        if fadeInMs > 0 || fadeOutMs > 0 {
            result = SampleEditor.fade(pcmData: result, fadeInMs: fadeInMs, fadeOutMs: fadeOutMs, sampleRate: sampleRate)
        }
        
        // 4. Normalize
        if normalizeEnabled {
            result = SampleEditor.normalize(pcmData: result, targetPeak: 1.0)
        }
        
        editedPCM = result
        currentPeak = SampleEditor.getPeak(pcmData: result)
        updateWaveform()
    }
}
