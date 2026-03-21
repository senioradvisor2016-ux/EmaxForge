import SwiftUI
import UniformTypeIdentifiers

/// Import .EB2 bank files into an EMAX II HD image
struct ImportBanksView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let image: DiskImage
    
    @State private var selectedFiles: [URL] = []
    @State private var isImporting = false
    @State private var importResults: [BankImporter.ImportResult] = []
    @State private var importErrors: [(URL, Error)] = []
    @State private var allowDuplicates = false
    @State private var freeSpace: String = "…"
    @State private var done = false
    @State private var importProgress: Double = 0.0
    @State private var currentFile: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Import Banks",
                subtitle: "Add .EB2 banks to \(image.filename)",
                icon: "square.and.arrow.down",
                onClose: { dismiss() }
            )
            
            Divider()
            
            if done {
                resultView
            } else {
                importForm
            }
        }
        .frame(width: 560, height: 520)
        .overlay {
            if isImporting {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 16) {
                            ProgressView(value: importProgress) {
                                VStack(spacing: 8) {
                                    Text("Importing banks...")
                                        .font(.headline)
                                    if !currentFile.isEmpty {
                                        Text(currentFile)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .progressViewStyle(.linear)
                            .frame(width: 300)
                            .padding(24)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
            }
        }
        .onAppear { loadFreeSpace() }
        .onExitCommand { dismiss() }
    }
    
    // MARK: - Helpers
    
    private var isBootDisk: Bool {
        // HD1.hda or HD10.hda = boot disk (SCSI ID 1)
        let name = image.filename.lowercased()
        return name.hasPrefix("hd1") && name.hasSuffix(".hda")
    }
    
    // MARK: - Import form
    
    private var importForm: some View {
        VStack(spacing: 0) {
            // Warning if importing to boot disk
            if isBootDisk {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Warning: Boot Disk (HD1)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("HD1 should contain OS only. Sample banks should be imported to HD2, HD3, etc.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(12)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
                .padding(.top, 12)
                
                Divider()
                    .padding(.top, 12)
            }
            
            // Drop zone / file list
            if selectedFiles.isEmpty {
                dropZone
            } else {
                fileList
            }
            
            Divider()
            
            // Footer
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Free space: \(freeSpace)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if !selectedFiles.isEmpty {
                        let totalSize = selectedFiles.compactMap { try? FileManager.default.attributesOfItem(atPath: $0.path)[.size] as? Int64 }.reduce(0, +)
                        Text("Selected: \(selectedFiles.count) bank(s), \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Toggle("Allow duplicates", isOn: $allowDuplicates)
                    .font(.caption)
                
                if selectedFiles.isEmpty {
                    Button("Choose Files…") { pickFiles() }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                } else {
                    Button("Add More…") { pickFiles() }
                        .buttonStyle(.bordered)
                    
                    Button("Import \(selectedFiles.count) Bank(s)") { doImport() }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .disabled(isImporting)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Drop zone
    
    private var dropZone: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "square.and.arrow.down.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange.opacity(0.6))
            
            Text("Drop bank files here")
                .font(.title3.bold())
            
            Text("EB2 · EM2 · EB1 · EM1 · HFE · EZ2 · HDA")
                .foregroundStyle(.secondary)
            
            Text("All E-mu formats auto-converted")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.orange.opacity(0.03))
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }
    
    // MARK: - File list
    
    private var fileList: some View {
        List {
            ForEach(selectedFiles, id: \.absoluteString) { url in
                HStack(spacing: 10) {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(Theme.accent)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(url.deletingPathExtension().lastPathComponent)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        selectedFiles.removeAll { $0 == url }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }
    
    // MARK: - Results
    
    private var resultView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            if importErrors.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.success)
                
                Text("Import Complete!")
                    .font(.title2.bold())
                
                Text("\(importResults.count) bank(s) imported successfully")
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.accent)
                
                Text("Import Finished")
                    .font(.title2.bold())
                
                if !importResults.isEmpty {
                    Text("✅ \(importResults.count) imported")
                        .foregroundStyle(Theme.success)
                }
                
                Text("⚠️ \(importErrors.count) failed")
                    .foregroundStyle(Theme.danger)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(importErrors.indices, id: \.self) { i in
                            HStack {
                                Text(importErrors[i].0.lastPathComponent)
                                    .fontWeight(.medium)
                                Text("— \(importErrors[i].1.localizedDescription)")
                                    .foregroundStyle(Theme.danger)
                            }
                            .font(.caption)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 120)
                .background(.red.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }
            
            // Imported banks list
            if !importResults.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(importResults.indices, id: \.self) { i in
                            let r = importResults[i]
                            HStack {
                                Image(systemName: "music.note")
                                    .foregroundStyle(Theme.accent)
                                Text(r.bankName)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(r.clustersUsed) cl")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.callout)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 150)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
            }
            
            Spacer()
            
            Divider()
            
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
            .padding()
        }
    }
    
    // MARK: - Actions
    
    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = FormatConverter.emuExtensions.compactMap { UTType(filenameExtension: $0) }
        panel.message = "Select E-mu bank/image files to import"
        
        if panel.runModal() == .OK {
            let newFiles = panel.urls.filter { url in
                !selectedFiles.contains(url)
            }
            selectedFiles.append(contentsOf: newFiles)
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                
                let ext = url.pathExtension.lowercased()
                if FormatConverter.emuExtensions.contains(ext) {
                    DispatchQueue.main.async {
                        if !selectedFiles.contains(url) {
                            selectedFiles.append(url)
                        }
                    }
                }
            }
        }
        return true
    }
    
    private func doImport() {
        isImporting = true
        importProgress = 0.0
        
        DispatchQueue.global(qos: .userInitiated).async {
            var allResults: [BankImporter.ImportResult] = []
            var allErrors: [(URL, Error)] = []
            
            let totalFiles = selectedFiles.count
            
            for (index, url) in selectedFiles.enumerated() {
                let ext = url.pathExtension.lowercased()
                
                DispatchQueue.main.async {
                    currentFile = url.lastPathComponent
                    importProgress = Double(index) / Double(totalFiles)
                }
                
                if ext == "eb2" {
                    // Direct import
                    do {
                        let result = try BankImporter.importBank(eb2URL: url, into: image.url, allowDuplicate: allowDuplicates)
                        allResults.append(result)
                    } catch {
                        allErrors.append((url, error))
                    }
                } else if FormatConverter.emuExtensions.contains(ext) {
                    // Convert first, then import
                    let (imported, errors) = FormatConverter.convertAndImport(urls: [url], into: image.url)
                    for name in imported {
                        allResults.append(BankImporter.ImportResult(bankName: name, clustersUsed: 0, sizeBytes: 0, catalogIndex: 0))
                    }
                    for (name, error) in errors {
                        allErrors.append((url, error))
                    }
                }
            }
            
            DispatchQueue.main.async {
                importResults = allResults
                importErrors = allErrors
                isImporting = false
                importProgress = 1.0
                done = true
                appState.refreshImages()
                appState.statusMessage = "Imported \(allResults.count) bank(s)"
            }
        }
    }
    
    private func loadFreeSpace() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let info = BankImporter.freeSpaceInfo(imageURL: image.url) {
                let formatted = ByteCountFormatter.string(fromByteCount: Int64(info.freeBytes), countStyle: .file)
                DispatchQueue.main.async {
                    freeSpace = "\(formatted) (\(info.freeClusters) clusters)"
                }
            }
        }
    }
}
