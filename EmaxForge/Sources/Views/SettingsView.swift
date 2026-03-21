import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
            
            DeviceSettingsView()
                .tabItem { Label("Devices", systemImage: "cpu") }
            
            FormatSettingsView()
                .tabItem { Label("Formats", systemImage: "doc.badge.gearshape") }
        }
        .frame(width: 500, height: 350)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("autoRenameOnDrop") var autoRename = true
    @AppStorage("confirmDelete") var confirmDelete = true
    @AppStorage("showHiddenFiles") var showHidden = false
    
    var body: some View {
        Form {
            Toggle("Auto-rename dropped files to ZuluSCSI format", isOn: $autoRename)
            Toggle("Confirm before deleting images", isOn: $confirmDelete)
            Toggle("Show hidden files", isOn: $showHidden)
        }
        .padding()
    }
}

struct FormatSettingsView: View {
    @AppStorage("sf2ImportMode") private var sf2ImportMode = "firstPreset"
    @AppStorage("audioNormalize") private var audioNormalize = true
    @AppStorage("audioSampleRate") private var audioSampleRate = 28000.0
    @AppStorage("stereoMode") private var stereoMode = "mono"
    
    var body: some View {
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
        }
        .padding()
    }
}

struct DeviceSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Supported Devices")
                .font(.headline)
            
            ForEach(DeviceType.allCases) { device in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(device.displayName)
                        .fontWeight(.medium)
                    Spacer()
                    Text("Extensions: \(device.imageExtensions.sorted().joined(separator: ", "))")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            
            Spacer()
            
            Text("More E-mu devices coming soon...")
                .foregroundStyle(.tertiary)
                .font(.caption)
        }
        .padding()
    }
}
