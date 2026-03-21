import SwiftUI

/// Sheet for formatting a physical SD/USB volume
struct FormatVolumeSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    let volume: MountedVolume
    
    @State private var fileSystem: DiskFormatter.VolumeFileSystem = .fat32
    @State private var volumeName: String = "ZULUSCI"
    @State private var isFormatting = false
    @State private var errorMessage: String?
    @State private var showConfirm = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with BIG warning
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Format Physical Volume")
                        .font(.title2.bold())
                    Text(volume.name)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(volume.url.path)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // DANGER WARNING
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                    Text("DESTRUCTIVE OPERATION")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                
                Text("This will ERASE EVERYTHING on the volume:")
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• All files and folders will be permanently deleted")
                    Text("• All disk images and banks will be lost")
                    Text("• This cannot be undone")
                }
                .font(.callout)
                
                Text("Only proceed if you are absolutely sure this is the correct volume!")
                    .fontWeight(.bold)
            }
            .padding(16)
            .background(.red.gradient, in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(.white)
            
            // Format options
            VStack(alignment: .leading, spacing: 16) {
                Text("Format Settings")
                    .font(.headline)
                
                Picker("File System", selection: $fileSystem) {
                    Text("FAT32 (standard)").tag(DiskFormatter.VolumeFileSystem.fat32)
                    Text("ExFAT (large cards only)").tag(DiskFormatter.VolumeFileSystem.exfat)
                }
                .pickerStyle(.segmented)
                
                HStack(spacing: 8) {
                    Text("Volume Name:")
                        .foregroundStyle(.secondary)
                    TextField("ZULUSCI", text: $volumeName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fileSystem == .fat32 
                             ? "FAT32 is the required format for ZuluSCSI SD/USB. Max 32 GB per partition."
                             : "ExFAT only for cards >32 GB. May have compatibility issues with ZuluSCSI.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if fileSystem == .fat32 {
                            Text("✓ Recommended for SD cards and USB sticks")
                                .font(.caption.bold())
                                .foregroundStyle(Theme.success)
                        }
                    }
                }
                .padding(.top, 4)
            }
            
            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
                .padding()
                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
            
            // Admin warning
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.orange)
                Text("This operation requires administrator privileges")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Actions
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                if isFormatting {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Formatting volume...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Format Volume") { showConfirm = true }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(volumeName.isEmpty)
                }
            }
        }
        .padding(24)
        .frame(width: 560, height: 640)
        .alert("⚠️ FINAL WARNING ⚠️", isPresented: $showConfirm) {
            Button("I UNDERSTAND - FORMAT NOW", role: .destructive) { performFormat() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Format \(volume.name) (\(volume.url.path))?\n\nALL DATA WILL BE PERMANENTLY ERASED.\n\nType the volume name to confirm.")
        }
    }
    
    private func performFormat() {
        isFormatting = true
        errorMessage = nil
        
        Task.detached {
            let volumeURL = volume.url
            let fs = await fileSystem
            let name = await volumeName
            
            do {
                try DiskFormatter.formatVolume(
                    at: volumeURL,
                    fileSystem: fs,
                    volumeName: name
                )
                
                await MainActor.run {
                    appState.addActivity("Formatted \(volume.name) as \(volumeName)", type: .success)
                    // Volume will be remounted with new name
                    appState.selectedVolume = nil
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isFormatting = false
                }
            }
        }
    }
}
