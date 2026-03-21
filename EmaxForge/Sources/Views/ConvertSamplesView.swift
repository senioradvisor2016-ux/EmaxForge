import SwiftUI
import UniformTypeIdentifiers

/// Convert audio files to EMAX II banks and optionally import into an image
struct ConvertSamplesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    /// If set, import directly into this image after conversion
    var targetImage: DiskImage?
    
    @State private var audioFiles: [URL] = []
    @State private var bankName = ""
    @State private var mappingMode: MappingMode = .autoSpread
    @State private var isConverting = false
    @State private var result: ConvertResult?
    @State private var errorMessage: String?
    @State private var dragOver = false
    @StateObject private var samplePlayer = SamplePlayer()
    @State private var playingIndex: Int?
    
    enum MappingMode: String, CaseIterable {
        case autoSpread = "Auto-spread across keyboard"
        case singleZone = "Single zone (full keyboard)"
        case chromaticC1 = "Chromatic from C1"
        case chromaticC3 = "Chromatic from C3"
    }
    
    enum ConvertResult {
        case savedEB2(URL)
        case importedToImage(BankImporter.ImportResult)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Convert to EMAX II",
                subtitle: targetImage != nil ? "Convert & import into \(targetImage!.filename)" : "Convert audio files to .EB2 bank",
                icon: "waveform.badge.plus",
                onClose: { dismiss() }
            )
            
            Divider()
            
            if let result {
                resultView(result)
            } else {
                convertForm
            }
        }
        .frame(width: 580, height: 560)
        .onExitCommand { dismiss() }
    }
    
    // MARK: - Helpers
    
    private var isBootDisk: Bool {
        guard let target = targetImage else { return false }
        let name = target.filename.lowercased()
        return name.hasPrefix("hd1") && name.hasSuffix(".hda")
    }
    
    // MARK: - Form
    
    private var convertForm: some View {
        VStack(spacing: 0) {
            // Warning if converting to boot disk
            if isBootDisk, let target = targetImage {
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
            
            // File list or drop zone
            if audioFiles.isEmpty {
                dropZone
            } else {
                fileList
            }
            
            Divider()
            
            // Settings
            Form {
                Section("Bank Settings") {
                    TextField("Bank Name (max 12 chars)", text: $bankName)
                        .onChange(of: bankName) { _, new in
                            if new.count > 12 { bankName = String(new.prefix(12)) }
                        }
                    
                    Picker("Key Mapping", selection: $mappingMode) {
                        ForEach(MappingMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(height: 140)
            
            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.danger)
                    .font(.callout)
                    .padding(.horizontal)
            }
            
            Divider()
            
            // Footer
            HStack(spacing: 12) {
                Text("\(audioFiles.count) file(s)")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                
                if !audioFiles.isEmpty {
                    let totalSize = audioFiles.compactMap { try? FileManager.default.attributesOfItem(atPath: $0.path)[.size] as? Int64 }.reduce(0, +)
                    Text("· \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                
                Spacer()
                
                if audioFiles.isEmpty {
                    Button("Choose Files…") { pickFiles() }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                } else {
                    Button("Add More…") { pickFiles() }
                        .buttonStyle(.bordered)
                    
                    if let _ = targetImage {
                        Button("Convert & Import") { convert(importToImage: true) }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                            .disabled(isConverting || bankName.isEmpty)
                    } else {
                        Button("Save as .EB2…") { convert(importToImage: false) }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                            .disabled(isConverting || bankName.isEmpty)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Drop zone
    
    private var dropZone: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accent.opacity(0.6))
            
            Text("Drop audio files here")
                .font(.title3.bold())
                .foregroundStyle(Theme.textPrimary)
            
            Text("WAV · AIFF · MP3 · FLAC · M4A")
                .foregroundStyle(Theme.textSecondary)
            
            Text("Up to 16 samples per bank")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.accent.opacity(dragOver ? 0.08 : 0.02))
        .overlay {
            if dragOver {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Theme.accent, lineWidth: 2)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            handleDrop(providers)
        }
    }
    
    // MARK: - File list
    
    private var fileList: some View {
        VStack(spacing: 0) {
            // Reorder hint
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundStyle(Theme.accent)
                    .font(.caption)
                Text("Drag to reorder • Key zones update automatically")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.accent.opacity(0.05))
            
            List {
                ForEach(audioFiles.indices, id: \.self) { i in
                let url = audioFiles[i]
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.accent.opacity(0.15))
                            .frame(width: 28, height: 28)
                        Text("\(i + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.accent)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(url.deletingPathExtension().lastPathComponent)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            Text(url.pathExtension.uppercased())
                                .font(.caption2.bold())
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Theme.bgCard, in: Capsule())
                            
                            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                            
                            // Key range info
                            if audioFiles.count > 1 {
                                let keysPerZone = 128 / audioFiles.count
                                let lo = i * keysPerZone
                                let hi = min((i + 1) * keysPerZone - 1, 127)
                                Text("Keys \(lo)-\(hi)")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Play button for audition
                    Button {
                        if playingIndex == i {
                            samplePlayer.stop()
                            playingIndex = nil
                        } else {
                            playSample(at: i)
                        }
                    } label: {
                        Image(systemName: playingIndex == i ? "stop.circle.fill" : "play.circle.fill")
                            .foregroundStyle(playingIndex == i ? Theme.accent : Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Audition sample")
                    
                    Button {
                        audioFiles.remove(at: i)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }
                .onMove { from, to in
                    audioFiles.move(fromOffsets: from, toOffset: to)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
                handleDrop(providers)
            }
        }
    }
    
    // MARK: - Result
    
    private func resultView(_ result: ConvertResult) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.success)
            
            Text("Conversion Complete!")
                .font(.title2.bold())
            
            switch result {
            case .savedEB2(let url):
                VStack(spacing: 4) {
                    Text("Saved as \(url.lastPathComponent)")
                        .foregroundStyle(Theme.textSecondary)
                    Text(url.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .buttonStyle(.bordered)
                
            case .importedToImage(let importResult):
                VStack(spacing: 4) {
                    Text("Bank \"\(importResult.bankName)\" imported")
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(importResult.clustersUsed) cluster(s) · \(ByteCountFormatter.string(fromByteCount: Int64(importResult.sizeBytes), countStyle: .file))")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            
            Spacer()
            
            Divider()
            
            HStack {
                Button("Convert More") {
                    self.result = nil
                    audioFiles = []
                    bankName = ""
                    errorMessage = nil
                }
                .buttonStyle(.bordered)
                
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
    
    private func playSample(at index: Int) {
        guard index < audioFiles.count else { return }
        let url = audioFiles[index]
        
        Task {
            do {
                let loadedSample = try SampleConverter.loadAudioFile(at: url)
                await MainActor.run {
                    samplePlayer.play(pcmData: loadedSample.pcmData, sampleRate: loadedSample.originalSampleRate)
                    playingIndex = index
                }
                
                // Stop when done
                try? await Task.sleep(nanoseconds: UInt64((Double(loadedSample.pcmData.count / 2) / loadedSample.originalSampleRate) * 1_000_000_000))
                await MainActor.run {
                    if playingIndex == index {
                        playingIndex = nil
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Could not play sample: \(error.localizedDescription)"
                    playingIndex = nil
                }
            }
        }
    }
    
    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = SampleConverter.supportedExtensions.compactMap {
            UTType(filenameExtension: $0)
        }
        panel.message = "Select audio files to convert"
        
        if panel.runModal() == .OK {
            let newFiles = panel.urls.filter { !audioFiles.contains($0) }
            audioFiles.append(contentsOf: newFiles)
            
            // Auto-set bank name from first file if empty
            if bankName.isEmpty, let first = audioFiles.first {
                bankName = String(first.deletingPathExtension().lastPathComponent.prefix(12))
            }
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let validExts = Set(SampleConverter.supportedExtensions)
        
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                
                if validExts.contains(url.pathExtension.lowercased()) {
                    DispatchQueue.main.async {
                        if !audioFiles.contains(url) && audioFiles.count < 16 {
                            audioFiles.append(url)
                            if bankName.isEmpty {
                                bankName = String(url.deletingPathExtension().lastPathComponent.prefix(12))
                            }
                        }
                    }
                }
            }
        }
        return true
    }
    
    private func convert(importToImage: Bool) {
        isConverting = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if importToImage, let image = targetImage {
                    let importResult = try SampleConverter.convertAndImport(
                        audioURLs: audioFiles,
                        bankName: bankName,
                        imageURL: image.url
                    )
                    DispatchQueue.main.async {
                        result = .importedToImage(importResult)
                        isConverting = false
                        appState.addActivity("Converted & imported \"\(bankName)\"", type: .success)
                    }
                } else {
                    // Save dialog
                    DispatchQueue.main.async {
                        let panel = NSSavePanel()
                        panel.allowedContentTypes = [UTType(filenameExtension: "eb2") ?? .data]
                        panel.nameFieldStringValue = "\(bankName).EB2"
                        
                        if panel.runModal() == .OK, let url = panel.url {
                            DispatchQueue.global(qos: .userInitiated).async {
                                do {
                                    try SampleConverter.convertToEB2(
                                        audioURLs: audioFiles,
                                        bankName: bankName,
                                        outputURL: url
                                    )
                                    DispatchQueue.main.async {
                                        result = .savedEB2(url)
                                        isConverting = false
                                        appState.addActivity("Converted \"\(bankName)\" to .EB2", type: .success)
                                    }
                                } catch {
                                    DispatchQueue.main.async {
                                        errorMessage = error.localizedDescription
                                        isConverting = false
                                    }
                                }
                            }
                        } else {
                            isConverting = false
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    isConverting = false
                }
            }
        }
    }
}
