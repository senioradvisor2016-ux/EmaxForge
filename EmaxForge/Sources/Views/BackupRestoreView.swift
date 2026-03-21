import SwiftUI

/// Full SD card backup and restore manager
struct BackupRestoreView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    let volumeURL: URL
    let volumeName: String
    let images: [DiskImage]
    
    @State private var selectedTab: Tab = .backup
    @State private var isProcessing = false
    @State private var progress: Double = 0
    @State private var statusMessage = ""
    @State private var lastBackup: BackupManager.BackupResult?
    @State private var lastRestore: BackupManager.RestoreResult?
    @State private var errorMessage: String?
    @State private var selectedArchive: URL?
    @State private var archiveInfo: BackupManager.BackupInfo?
    @State private var overwriteExisting = false
    
    enum Tab {
        case backup, restore
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            
            // Tab picker
            Picker("Mode", selection: $selectedTab) {
                Label("Backup", systemImage: "arrow.up.doc").tag(Tab.backup)
                Label("Restore", systemImage: "arrow.down.doc").tag(Tab.restore)
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            // Content
            if isProcessing {
                processingView
            } else {
                switch selectedTab {
                case .backup: backupTab
                case .restore: restoreTab
                }
            }
            
            Divider()
            footer
        }
        .frame(minWidth: 850, idealWidth: 900, minHeight: 650, idealHeight: 700)
        .onExitCommand { dismiss() }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.timemachine")
                .font(.title2)
                .foregroundStyle(Theme.accent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Backup & Restore")
                    .font(.headline)
                Text(volumeName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Done") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
        .background(.bar)
    }
    
    // MARK: - Backup Tab
    
    private var backupTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Info
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Theme.accent)
                        Text("Backup Information")
                            .font(.headline)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        LabelValueRow(label: "Volume", value: volumeName)
                        LabelValueRow(label: "Images", value: "\(images.count)")
                        LabelValueRow(label: "Total Size", value: formattedTotalSize)
                        LabelValueRow(label: "Device", value: appState.currentDevice.displayName)
                    }
                }
                .padding(16)
                .background(Theme.bgCard.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                
                // What will be backed up
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "checklist")
                            .foregroundStyle(Theme.accent)
                        Text("Files to Backup")
                            .font(.headline)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(images.prefix(10)) { image in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(Theme.success)
                                Text(image.filename)
                                    .font(.caption)
                                Spacer()
                                Text(image.formattedSize)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if images.count > 10 {
                            Text("+ \(images.count - 10) more file(s)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()
                        
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("zuluscsi.ini (if present)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(Theme.bgCard.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                
                // Result (if backup was created)
                if let result = lastBackup {
                    resultCard(result: result)
                }
                
                // Error
                if let error = errorMessage {
                    errorCard(message: error)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Restore Tab
    
    private var restoreTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Select archive
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.questionmark")
                            .foregroundStyle(Theme.cyan)
                        Text("Select Backup Archive")
                            .font(.headline)
                    }
                    
                    if let archiveURL = selectedArchive {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.zipper")
                                .font(.title3)
                                .foregroundStyle(Theme.cyan)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(archiveURL.lastPathComponent)
                                    .fontWeight(.medium)
                                Text(archiveURL.deletingLastPathComponent().path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Change") { selectArchive() }
                                .buttonStyle(.bordered)
                        }
                        .padding(12)
                        .background(Theme.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    } else {
                        Button {
                            selectArchive()
                        } label: {
                            Label("Choose Backup File…", systemImage: "doc.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.cyan)
                    }
                }
                .padding(16)
                .background(Theme.bgCard.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                
                // Archive info
                if let info = archiveInfo {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(Theme.accent)
                            Text("Backup Details")
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            LabelValueRow(label: "Created", value: info.formattedDate)
                            LabelValueRow(label: "Volume Name", value: info.volumeName)
                            LabelValueRow(label: "Device Type", value: info.deviceType)
                            LabelValueRow(label: "Images", value: "\(info.imageCount)")
                            LabelValueRow(label: "Total Size", value: ByteCountFormatter.string(fromByteCount: info.totalSize, countStyle: .file))
                        }
                        
                        Divider()
                        
                        Text("Files (\(info.fileList.count)):")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        
                        ForEach(info.fileList.prefix(8), id: \.self) { filename in
                            HStack(spacing: 6) {
                                Image(systemName: "doc")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(filename)
                                    .font(.caption)
                            }
                        }
                        
                        if info.fileList.count > 8 {
                            Text("+ \(info.fileList.count - 8) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .background(Theme.bgCard.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                }
                
                // Options
                if selectedArchive != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "gearshape")
                                .foregroundStyle(Theme.accent)
                            Text("Restore Options")
                                .font(.headline)
                        }
                        
                        Toggle("Overwrite existing files", isOn: $overwriteExisting)
                        
                        Text("If disabled, existing files on the destination will be skipped.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Theme.bgCard.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                }
                
                // Restore result
                if let result = lastRestore {
                    restoreResultCard(result: result)
                }
                
                // Error
                if let error = errorMessage {
                    errorCard(message: error)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Processing View
    
    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 400)
            
            Text(statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
            
            Text(String(format: "%.0f%%", progress * 100))
                .font(.system(.title2, design: .monospaced))
                .foregroundStyle(Theme.accent)
            
            Spacer()
        }
    }
    
    // MARK: - Result Cards
    
    private func resultCard(result: BackupManager.BackupResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.success)
                    .font(.title3)
                Text("Backup Created")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                LabelValueRow(label: "Archive", value: result.archiveURL.lastPathComponent)
                LabelValueRow(label: "Location", value: result.archiveURL.deletingLastPathComponent().lastPathComponent)
                LabelValueRow(label: "Size", value: ByteCountFormatter.string(fromByteCount: result.compressedSize, countStyle: .file))
                LabelValueRow(label: "Compression", value: String(format: "%.1f%%", (1 - result.compressionRatio) * 100))
                LabelValueRow(label: "Images", value: "\(result.backupInfo.imageCount)")
            }
            
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([result.archiveURL])
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(Theme.success.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
    
    private func restoreResultCard(result: BackupManager.RestoreResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.success)
                    .font(.title3)
                Text("Restore Complete")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                LabelValueRow(label: "Files Restored", value: "\(result.restoredFiles.count)")
                LabelValueRow(label: "Total Size", value: ByteCountFormatter.string(fromByteCount: result.totalSize, countStyle: .file))
            }
        }
        .padding(16)
        .background(Theme.success.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
    
    private func errorCard(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.danger)
            Text(message)
                .font(.callout)
        }
        .padding(12)
        .background(Theme.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            if selectedTab == .backup {
                Text("\(images.count) image(s) • \(formattedTotalSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let info = archiveInfo {
                Text("\(info.imageCount) image(s) in archive")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if selectedTab == .backup {
                Button("Create Backup…") { createBackup() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(images.isEmpty || isProcessing)
            } else {
                Button("Restore") { performRestore() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.cyan)
                    .disabled(selectedArchive == nil || isProcessing)
            }
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private var formattedTotalSize: String {
        let totalSize = images.reduce(0) { $0 + $1.fileSize }
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    // MARK: - Actions
    
    private func createBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = "\(volumeName)-backup-\(formattedTimestamp()).zip"
        panel.message = "Choose backup location"
        
        guard panel.runModal() == .OK, let destURL = panel.url else { return }
        
        isProcessing = true
        errorMessage = nil
        lastBackup = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try BackupManager.createBackup(
                    volumeURL: volumeURL,
                    volumeName: volumeName,
                    deviceType: appState.currentDevice,
                    images: images,
                    destinationURL: destURL
                ) { prog, msg in
                    DispatchQueue.main.async {
                        progress = prog
                        statusMessage = msg
                    }
                }
                
                DispatchQueue.main.async {
                    isProcessing = false
                    lastBackup = result
                    appState.addActivity("Created backup: \(destURL.lastPathComponent)", type: .success)
                }
            } catch {
                DispatchQueue.main.async {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func selectArchive() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.zip]
        panel.message = "Select backup archive to restore"
        
        guard panel.runModal() == .OK, let url = panel.url else { return }
        
        selectedArchive = url
        
        // Try to read backup info
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let info = try BackupManager.readBackupInfo(from: url)
                DispatchQueue.main.async {
                    archiveInfo = info
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Could not read backup info: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func performRestore() {
        guard let archiveURL = selectedArchive else { return }
        
        isProcessing = true
        errorMessage = nil
        lastRestore = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try BackupManager.restoreBackup(
                    archiveURL: archiveURL,
                    destinationURL: volumeURL,
                    overwriteExisting: overwriteExisting
                ) { prog, msg in
                    DispatchQueue.main.async {
                        progress = prog
                        statusMessage = msg
                    }
                }
                
                DispatchQueue.main.async {
                    isProcessing = false
                    lastRestore = result
                    appState.refreshImages()
                    appState.addActivity("Restored \(result.restoredFiles.count) file(s)", type: .success)
                }
            } catch {
                DispatchQueue.main.async {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func formattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: Date())
    }
}

struct LabelValueRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }
}
