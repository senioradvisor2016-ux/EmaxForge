import SwiftUI

/// View/edit ZuluSCSI configuration for the current volume
struct ZuluSCSIConfigView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    let configService = ZuluSCSIConfigService()
    
    @State private var configText: String = ""
    @State private var existingConfig: String?
    @State private var saved = false
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "ZuluSCSI Configuration",
                subtitle: existingConfig != nil ? "Editing existing config" : "No config on volume — generating default",
                icon: "doc.text",
                onClose: { dismiss() }
            )
            
            Divider()
            
            // Config editor
            TextEditor(text: $configText)
                .font(.system(size: 13, design: .monospaced))
                .padding(4)
            
            // Tips
            VStack(alignment: .leading, spacing: 4) {
                Label("SelectionDelay = 255 works best for EMAX II", systemImage: "lightbulb")
                Label("Increase StartupDelay if ZuluSCSI isn't detected on boot", systemImage: "lightbulb")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            HStack(spacing: 12) {
                Button("Reset to Default") {
                    configText = configService.generateConfig(for: appState.currentDevice, images: appState.images)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if saved {
                    Label("Saved!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
                
                Button("Save to Volume") { saveConfig() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
            .padding()
        }
        .frame(width: 620, height: 520)
        .onAppear { loadConfig() }
        .onExitCommand { dismiss() }
    }
    
    private func loadConfig() {
        guard let volume = appState.selectedVolume else { return }
        
        if let existing = configService.readConfig(from: volume.url) {
            existingConfig = existing
            configText = existing
        } else {
            configText = configService.generateConfig(for: appState.currentDevice, images: appState.images)
        }
    }
    
    private func saveConfig() {
        guard let volume = appState.selectedVolume else { return }
        
        do {
            try configService.writeConfig(content: configText, to: volume.url)
            withAnimation { saved = true }
            appState.statusMessage = "Saved zuluscsi.ini"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } catch {
            appState.statusMessage = "Error: \(error.localizedDescription)"
        }
    }
}
