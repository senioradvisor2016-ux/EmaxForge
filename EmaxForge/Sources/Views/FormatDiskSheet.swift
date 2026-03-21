import SwiftUI

/// Sheet for formatting an EMAX II HD image
struct FormatDiskSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    let image: DiskImage
    
    @State private var keepOS = true
    @State private var quickFormat = true
    @State private var isFormatting = false
    @State private var errorMessage: String?
    @State private var showConfirm = false
    
    private var isBootDisk: Bool {
        let name = image.filename.lowercased()
        return name.hasPrefix("hd1") && name.hasSuffix(".hda")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Format Disk")
                        .font(.title2.bold())
                    Text(image.filename)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Warning
            VStack(alignment: .leading, spacing: 12) {
                Label("All user banks will be permanently deleted", systemImage: "trash.fill")
                    .foregroundStyle(.red)
                    .fontWeight(.medium)
                
                Text("This action cannot be undone. Make sure you have backups of important banks.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            
            // Extra warning for boot disk
            if isBootDisk {
                VStack(alignment: .leading, spacing: 12) {
                    Label("⚠️ This is your BOOT DISK (HD1)!", systemImage: "exclamationmark.octagon.fill")
                        .foregroundStyle(.orange)
                        .fontWeight(.bold)
                    
                    Text("Formatting HD1 will erase the operating system and make your EMAX II unable to boot unless you reinstall the OS afterward!")
                        .font(.callout)
                        .foregroundStyle(.primary)
                    
                    Text("Consider formatting HD2, HD3, etc. instead for data storage.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            }
            
            // Options
            VStack(alignment: .leading, spacing: 16) {
                Text("Format Options")
                    .font(.headline)
                
                Toggle("Keep Operating System", isOn: $keepOS)
                    .help("Preserve the EMAX II OS on cluster 1")
                
                Toggle("Quick Format", isOn: $quickFormat)
                    .help("Only clear metadata (faster). Disable for full zero-wipe.")
                
                if !keepOS {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Without OS, the EMAX II cannot boot from this disk")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
            
            Spacer()
            
            // Actions
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                if isFormatting {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Formatting...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Format Disk") { showConfirm = true }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 500)
        .alert("Confirm Format", isPresented: $showConfirm) {
            Button("Format", role: .destructive) { performFormat() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Format \(image.filename)? All banks will be deleted.")
        }
    }
    
    private func performFormat() {
        isFormatting = true
        errorMessage = nil
        
        Task.detached {
            let keepOS = await keepOS
            let quickFormat = await quickFormat
            let imageURL = await image.url
            
            do {
                let options = DiskFormatter.FormatOptions(
                    keepOS: keepOS,
                    quickFormat: quickFormat
                )
                
                try DiskFormatter.formatImage(at: imageURL, options: options)
                
                await MainActor.run {
                    appState.addActivity("Formatted \(image.filename)", type: .success)
                    appState.refreshImages()
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
