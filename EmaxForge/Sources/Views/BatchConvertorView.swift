import SwiftUI

/// Batch convertor for converting multiple files at once
struct BatchConvertorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var files: [URL] = []
    @State private var outputDirectory: URL?
    @State private var isConverting = false
    @State private var progress: Double = 0
    @State private var progressMessage = ""
    @State private var results: [ConvertResult] = []
    @State private var errors: [(String, Error)] = []
    @State private var dragOver = false
    
    struct ConvertResult {
        let inputFile: String
        let outputFile: URL?
        let bankCount: Int
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Batch Convertor",
                subtitle: "Convert multiple files to EB2 banks",
                icon: "square.stack.3d.up",
                onClose: { dismiss() }
            )
            
            Divider()
            
            if isConverting {
                progressView
            } else if !results.isEmpty {
                resultsView
            } else {
                convertForm
            }
        }
        .frame(width: 700, height: 600)
        .onExitCommand { dismiss() }
    }
    
    // MARK: - Form
    
    private var convertForm: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // File list or drop zone
            if files.isEmpty {
                dropZone
            } else {
                fileList
            }
            
            Divider()
            
            // Output directory
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Output Directory")
                    .font(Theme.Typography.headline)
                
                HStack(spacing: Theme.Spacing.md) {
                    if let dir = outputDirectory {
                        Text(dir.lastPathComponent)
                            .font(Theme.Typography.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("Not selected")
                            .font(Theme.Typography.body)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Choose...") {
                        chooseOutputDirectory()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            
            // Action buttons
            HStack(spacing: Theme.Spacing.md) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Convert All") {
                    startConversion()
                }
                .buttonStyle(.borderedProminent)
                .disabled(files.isEmpty || outputDirectory == nil)
            }
            .padding(Theme.Spacing.lg)
        }
    }
    
    // MARK: - Drop Zone
    
    private var dropZone: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accent.opacity(0.6))
            
            Text("Drop files here")
                .font(Theme.Typography.title)
            
            Text("EB2 · EM2 · HFE · SF2 · WAV · AIFF")
                .font(Theme.Typography.body)
                .foregroundStyle(.secondary)
            
            Text("or")
                .font(Theme.Typography.caption)
                .foregroundStyle(.tertiary)
            
            Button("Choose Files...") {
                pickFiles()
            }
            .buttonStyle(.borderedProminent)
            
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
    
    // MARK: - File List
    
    private var fileList: some View {
        VStack(spacing: 0) {
            List {
                ForEach(files.indices, id: \.self) { i in
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: fileIcon(for: files[i]))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(files[i].lastPathComponent)
                                .font(Theme.Typography.body)
                                .lineLimit(1)
                            
                            Text(files[i].pathExtension.uppercased())
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            files.remove(at: i)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
            
            HStack {
                Text("\(files.count) file(s)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button("Add More...") {
                    pickFiles()
                }
                .buttonStyle(.bordered)
            }
            .padding(Theme.Spacing.md)
        }
    }
    
    // MARK: - Progress
    
    private var progressView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ProgressView(value: progress)
                .frame(width: 500)
            
            Text(progressMessage)
                .font(Theme.Typography.body)
                .foregroundStyle(.secondary)
            
            Text("\(Int(progress * 100))%")
                .font(Theme.Typography.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Results
    
    private var resultsView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title)
                
                Text("Conversion Complete")
                    .font(Theme.Typography.title)
                
                Spacer()
            }
            .padding(Theme.Spacing.lg)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ForEach(results.indices, id: \.self) { i in
                        let result = results[i]
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(.green)
                            Text(result.inputFile)
                                .font(Theme.Typography.body)
                            Spacer()
                            Text("\(result.bankCount) bank(s)")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if !errors.isEmpty {
                        Divider()
                            .padding(.vertical, Theme.Spacing.sm)
                        
                        ForEach(errors.indices, id: \.self) { i in
                            let (file, error) = errors[i]
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(.red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file)
                                        .font(Theme.Typography.body)
                                    Text(error.localizedDescription)
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            
            Divider()
            
            HStack {
                if let dir = outputDirectory {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([dir])
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(Theme.Spacing.lg)
        }
    }
    
    // MARK: - Actions
    
    private func fileIcon(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "eb2", "em2", "eb1", "em1": return "doc.text"
        case "sf2": return "waveform"
        case "hfe": return "opticaldiscdrive"
        case "wav", "aiff", "aif", "mp3", "flac": return "waveform"
        default: return "doc"
        }
    }
    
    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [
            .data,
            .audio
        ]
        
        if panel.runModal() == .OK {
            files.append(contentsOf: panel.urls)
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, error in
                defer { group.leave() }
                if let data = data as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
            }
        }
        
        group.notify(queue: .main) {
            files.append(contentsOf: urls)
        }
        
        return true
    }
    
    private func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        
        if panel.runModal() == .OK {
            outputDirectory = panel.url
        }
    }
    
    private func startConversion() {
        guard let outputDir = outputDirectory else { return }
        
        isConverting = true
        progress = 0
        results = []
        errors = []
        
        Task {
            for (i, file) in files.enumerated() {
                let fileProgress = Double(i) / Double(files.count)
                await MainActor.run {
                    progress = fileProgress
                    progressMessage = "Converting \(file.lastPathComponent)..."
                }
                
                do {
                    let banks = try FormatConverter.convertToEB2(url: file)
                    
                    for (j, (bankName, bankData)) in banks.enumerated() {
                        let outputFile = outputDir
                            .appendingPathComponent(bankName)
                            .appendingPathExtension("EB2")
                        
                        try bankData.write(to: outputFile)
                        
                        await MainActor.run {
                            results.append(ConvertResult(
                                inputFile: file.lastPathComponent,
                                outputFile: outputFile,
                                bankCount: banks.count
                            ))
                        }
                    }
                } catch {
                    await MainActor.run {
                        errors.append((file.lastPathComponent, error))
                    }
                }
            }
            
            await MainActor.run {
                progress = 1.0
                progressMessage = "Done"
                isConverting = false
            }
        }
    }
}
