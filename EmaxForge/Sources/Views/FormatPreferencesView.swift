import SwiftUI

/// Format-specific preferences and settings
struct FormatPreferencesView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("sf2ImportMode") private var sf2ImportMode = "firstPreset"
    @AppStorage("audioNormalize") private var audioNormalize = true
    @AppStorage("audioSampleRate") private var audioSampleRate = 28000.0
    @AppStorage("stereoMode") private var stereoMode = "mono"
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Format Preferences",
                subtitle: "Configure format-specific conversion settings",
                icon: "gearshape",
                onClose: { dismiss() }
            )
            
            Divider()
            
            Form {
                Section("SoundFont (SF2)") {
                    Picker("Import Mode", selection: $sf2ImportMode) {
                        Text("First Preset Only").tag("firstPreset")
                        Text("All Presets").tag("allPresets")
                        Text("Selected Presets").tag("selectedPresets")
                    }
                    
                    Text("Controls how SF2 files are converted to EB2 banks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Audio Conversion") {
                    Toggle("Normalize samples", isOn: $audioNormalize)
                    
                    Picker("Default Sample Rate", selection: $audioSampleRate) {
                        Text("20 kHz").tag(20000.0)
                        Text("22.05 kHz").tag(22050.0)
                        Text("27.778 kHz").tag(27778.0)
                        Text("31.25 kHz").tag(31250.0)
                        Text("39.063 kHz").tag(39063.0)
                        Text("44.1 kHz").tag(44100.0)
                    }
                    
                    Picker("Stereo Handling", selection: $stereoMode) {
                        Text("Convert to Mono (Left)").tag("mono")
                        Text("Convert to Mono (Right)").tag("monoRight")
                        Text("Convert to Mono (Average)").tag("monoAverage")
                        Text("Keep Stereo (Split)").tag("stereo")
                    }
                }
                
                Section("EMAX II") {
                    Toggle("Preserve loop points", isOn: .constant(true))
                    Toggle("Preserve key mapping", isOn: .constant(true))
                }
            }
            .formStyle(.grouped)
            .padding()
            
            Divider()
            
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 500)
        .onExitCommand { dismiss() }
    }
}
