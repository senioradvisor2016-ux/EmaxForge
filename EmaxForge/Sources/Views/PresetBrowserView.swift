import SwiftUI

/// Preset-centric browser showing all presets with details
struct PresetBrowserView: View {
    let image: DiskImage
    
    @Environment(\.dismiss) private var dismiss
    @State private var presets: [PresetInfo] = []
    @State private var isAnalyzing = false
    @State private var searchText = ""
    @State private var selectedPreset: PresetInfo?
    @State private var analysisResult: PresetAnalyzer.AnalysisResult?
    
    private var filteredPresets: [PresetInfo] {
        if searchText.isEmpty {
            return presets
        } else {
            return presets.filter { preset in
                preset.name.localizedCaseInsensitiveContains(searchText) ||
                preset.bankName.localizedCaseInsensitiveContains(searchText) ||
                preset.samples.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    var body: some View {
        HSplitView {
            // Left: Preset list
            VStack(spacing: 0) {
                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search presets", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .padding()
                
                Divider()
                
                // List
                if isAnalyzing {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Analyzing presets...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredPresets.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No presets found")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredPresets, selection: $selectedPreset) { preset in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(preset.name)
                                    .font(.headline)
                                Spacer()
                                Text("#\(preset.presetIndex + 1)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text(preset.bankName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(preset.voiceDescription)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Divider()
                
                // Stats
                if let result = analysisResult {
                    HStack {
                        Label("\(result.totalPresets)", systemImage: "music.note.list")
                        Spacer()
                        Text(String(format: "%.1f avg voices", result.averageVoicesPerPreset))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.05))
                }
            }
            .frame(minWidth: 300, idealWidth: 350)
            
            // Right: Preset details
            if let preset = selectedPreset {
                PresetDetailView(preset: preset)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a preset")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
            }
        }
        .frame(width: 900, height: 600)
        .task {
            await analyzePresets()
        }
    }
    
    // MARK: - Actions
    
    private func analyzePresets() async {
        isAnalyzing = true
        
        do {
            let analyzer = PresetAnalyzer()
            let result = try await analyzer.analyzePresets(in: image.url)
            
            self.presets = result.presets
            self.analysisResult = result
            
        } catch {
            print("Failed to analyze presets: \(error)")
        }
        
        isAnalyzing = false
    }
}

/// Detail view for a selected preset
struct PresetDetailView: View {
    let preset: PresetInfo
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(preset.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack {
                        Label(preset.bankName, systemImage: "square.stack")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("Preset #\(preset.presetIndex + 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Info section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configuration")
                        .font(.headline)
                    
                    PresetInfoRow(label: "Voices", value: "\(preset.voiceCount)")
                    PresetInfoRow(label: "Key Range", value: preset.keyRangeDescription)
                    PresetInfoRow(label: "Velocity Layers", value: "\(preset.velocityLayers)")
                    PresetInfoRow(label: "Samples", value: "\(preset.sampleCount)")
                }
                
                Divider()
                
                // Samples section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Samples")
                        .font(.headline)
                    
                    if preset.samples.isEmpty {
                        Text("No samples")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(preset.samples, id: \.self) { sample in
                            HStack {
                                Image(systemName: "waveform")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text(sample)
                                    .font(.callout)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(6)
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(minWidth: 400)
    }
}

/// Helper view for info rows
struct PresetInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview (commented out)
// #Preview {
//     PresetBrowserView(image: DiskImage(...))
// }
