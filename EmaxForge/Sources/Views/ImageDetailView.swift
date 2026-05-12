import SwiftUI
import UniformTypeIdentifiers

/// Detail panel showing image info, actions, and hex preview
struct ImageDetailView: View {
    @EnvironmentObject var appState: AppState
    let image: DiskImage
    
    @State private var validation: ImageValidation?
    @State private var hexPreview: String = ""
    @State private var showRenameSheet = false
    @State private var showDuplicateSheet = false
    @State private var showConvertAlert = false
    @State private var showBankBrowser = false
    @State private var showImportBanks = false
    @State private var showAdvancedImport = false
    @State private var showConvertSamples = false
    @State private var showCatalogBrowser = false
    @State private var showBankTemplates = false
    @State private var bankCount: Int?
    @State private var osName: String?
    @State private var freeSpace: String?
    @State private var showHex = false
    @State private var dragOver = false
    @State private var showDeleteConfirmation = false
    @State private var showFormatSheet = false
    @State private var showBulkExport = false
    @State private var showBankExport = false
    @State private var parseTask: Task<Void, Never>?
    @State private var isParsing = false
    @State private var parsedFileSystem: EmaxIIFileSystem?
    @State private var showVerifyDisk = false
    @State private var showSampleBrowser = false
    @State private var showPresetBrowser = false
    @State private var showBootDiskValidator = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                quickInfoCards
                
                Divider().padding(.horizontal, -20)
                
                actionsSection
                
                Divider().padding(.horizontal, -20)
                
                fileInfoSection
                
                if showHex {
                    Divider().padding(.horizontal, -20)
                    hexSection
                }
            }
            .padding(24)
        }
        .overlay {
            if dragOver {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.mint, lineWidth: 3, antialiased: true)
                    .background(.mint.opacity(0.08))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 36))
                            Text("Drop .EB2 files to import banks")
                                .font(.headline)
                        }
                        .foregroundStyle(.mint)
                    }
            }
        }
        .overlay {
            if isParsing {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Parsing image...")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Large files may take 10-30 seconds")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Button("Cancel") {
                            parseTask?.cancel()
                            isParsing = false
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }
                    .padding(40)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            handleEB2Drop(providers)
        }
        .onAppear { loadImageInfo() }
        .onDisappear { parseTask?.cancel() }
        .onChange(of: image) { _, _ in
            parseTask?.cancel()
            loadImageInfo()
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameImageSheet(image: image)
        }
        .sheet(isPresented: $showDuplicateSheet) {
            DuplicateImageSheet(image: image)
        }
        .sheet(isPresented: $showBankBrowser) {
            BankBrowserView(image: image)
        }
        .sheet(isPresented: $showImportBanks) {
            ImportBanksView(image: image)
                .onDisappear { loadBankCount() }
        }
        .sheet(isPresented: $showConvertSamples) {
            ConvertSamplesView(targetImage: image)
                .onDisappear { loadBankCount() }
        }
        .sheet(isPresented: $showFormatSheet) {
            FormatDiskSheet(image: image)
                .onDisappear { loadBankCount() }
        }
        .sheet(isPresented: $showBulkExport) {
            BulkExportView(image: image)
        }
        .sheet(isPresented: $showBankExport) {
            BankExportView(image: image)
        }
        .sheet(isPresented: $showVerifyDisk) {
            VerifyDiskSheet(imageURL: image.url)
        }
        .sheet(isPresented: $showBootDiskValidator) {
            BootDiskValidatorSheet(imageURL: image.url)
        }
        .sheet(isPresented: $showSampleBrowser) {
            SampleBrowserView(image: image)
        }
        .sheet(isPresented: $showPresetBrowser) {
            PresetBrowserView(image: image)
        }
        .sheet(isPresented: $showAdvancedImport) {
            AdvancedImportSheet(imageURL: image.url)
        }
        .sheet(isPresented: $showCatalogBrowser) {
            CatalogBrowserView(image: image)
        }
        .sheet(isPresented: $showBankTemplates) {
            BankTemplatesSheet(image: image)
        }
        .onReceive(NotificationCenter.default.publisher(for: .convertSamples)) { _ in
            showConvertSamples = true
        }
        .alert("Convert to .hda", isPresented: $showConvertAlert) {
            Button("Convert") { convertToHDA() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will create a copy as .hda (identical content, just renamed). The original .EZ2 will be kept.")
        }
        // Menu command listeners
        .onReceive(NotificationCenter.default.publisher(for: .browseBanks)) { _ in
            openBankBrowser()
        }
        .onReceive(NotificationCenter.default.publisher(for: .importBanks)) { _ in
            showImportBanks = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .duplicateImage)) { _ in
            showDuplicateSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteImage)) { _ in
            showDeleteConfirmation = true
        }
        .alert("Delete Image?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                performDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to move \"\(image.filename)\" to the trash? This action can be undone from the Trash.")
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            // SCSI badge
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.accentGradient)
                    .frame(width: 76, height: 76)
                    .shadow(color: Theme.accent.opacity(0.3), radius: 10, y: 4)
                
                if let id = image.scsiID {
                    VStack(spacing: 2) {
                        Text("SCSI")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1)
                        Text("\(id)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                } else {
                    Image(systemName: "questionmark")
                        .font(.title)
                        .foregroundStyle(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(image.filename)
                    .font(.system(size: 22, weight: .bold))
                
                HStack(spacing: 12) {
                    if let label = image.label {
                        Label(label, systemImage: "tag")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let os = osName {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .font(.caption)
                            Text(os)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.blue.opacity(0.15), in: Capsule())
                        .foregroundStyle(.blue)
                    }
                }
                
                // Validation
                if let v = validation {
                    HStack(spacing: 6) {
                        Image(systemName: v.isValid ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        Text(v.message)
                    }
                    .font(.callout)
                    .foregroundStyle(v.isValid ? .green : .red)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Quick Info
    
    private var quickInfoCards: some View {
        HStack(spacing: 10) {
            QuickInfoCard(title: "Size", value: image.formattedSize, icon: "internaldrive", color: .blue)
            QuickInfoCard(title: "Format", value: image.fileExtension.uppercased(), icon: "doc", color: .purple)
            
            Button { openBankBrowser() } label: {
                if let count = bankCount {
                    QuickInfoCard(title: "Banks", value: "\(count)", icon: "list.bullet.rectangle", color: .orange)
                } else if isParsing {
                    QuickInfoCard(title: "Banks", value: "…", icon: "list.bullet.rectangle", color: .secondary)
                } else {
                    QuickInfoCard(title: "Banks", value: "—", icon: "list.bullet.rectangle", color: .secondary)
                }
            }
            .buttonStyle(.plain)
            .help("Browse banks (⌘B)")
            
            if let free = freeSpace {
                QuickInfoCard(title: "Free", value: free, icon: "chart.pie", color: .green)
            }
            
            if let idx = image.imageIndex {
                QuickInfoCard(title: "Slot", value: "\(idx)", icon: "number", color: .cyan)
            }
            
            // Boot disk indicator
            if image.filename.lowercased().hasPrefix("hd1") && image.filename.lowercased().hasSuffix(".hda") {
                QuickInfoCard(title: "BOOT", value: "OS", icon: "power", color: .orange)
                    .help("Boot disk (SCSI ID 1) - contains operating system")
            }
        }
    }
    
    // MARK: - Actions (grouped by category)
    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Banks & Samples
            actionGroup(title: "Banks & Samples", items: bankActions)
            
            // Export
            actionGroup(title: "Export", items: exportActions)
            
            // File Management
            actionGroup(title: "File", items: fileActions)
            
            // Inspect & Debug
            actionGroup(title: "Inspect", items: inspectActions)
            
            // Destructive (visually separated)
            actionGroup(title: "Danger Zone", items: dangerActions, dangerous: true)
        }
    }
    
    private func actionGroup(title: String, items: [ActionItem], dangerous: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(dangerous ? .red.opacity(0.8) : .secondary)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 95), spacing: 8)], spacing: 8) {
                ForEach(items) { item in
                    ActionCard(title: item.title, icon: item.icon, color: item.color, action: item.action)
                }
            }
        }
    }
    
    private struct ActionItem: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let color: Color
        let action: () -> Void
    }
    
    private var bankActions: [ActionItem] {
        var items = [
            ActionItem(title: "Browse Banks", icon: "list.bullet.rectangle", color: .indigo) { openBankBrowser() },
            ActionItem(title: "Import Banks", icon: "square.and.arrow.down", color: .mint) { showImportBanks = true },
            ActionItem(title: "Template", icon: "square.grid.3x3.square", color: .indigo) { showBankTemplates = true },
            ActionItem(title: "Adv. Import", icon: "waveform.badge.magnifyingglass", color: .purple) { showAdvancedImport = true },
            ActionItem(title: "Convert Audio", icon: "waveform.badge.plus", color: Theme.accent) { showConvertSamples = true },
        ]
        if image.fileExtension == "ez2" {
            items.append(ActionItem(title: "→ .hda", icon: "arrow.triangle.2.circlepath", color: .purple) { showConvertAlert = true })
        }
        return items
    }
    
    private var exportActions: [ActionItem] {
        [
            ActionItem(title: "Export WAV", icon: "square.and.arrow.up", color: .cyan) { exportImageToWAV() },
            ActionItem(title: "Export Banks", icon: "square.and.arrow.up.on.square", color: .blue) { showBankExport = true },
            ActionItem(title: "Export Samples", icon: "waveform.and.arrow.up", color: .cyan) { showBulkExport = true },
        ]
    }
    
    private var fileActions: [ActionItem] {
        [
            ActionItem(title: "Rename", icon: "pencil", color: .blue) { showRenameSheet = true },
            ActionItem(title: "Duplicate", icon: "doc.on.doc", color: .green) { showDuplicateSheet = true },
            ActionItem(title: "Finder", icon: "folder", color: .orange) { NSWorkspace.shared.activateFileViewerSelecting([image.url]) },
        ]
    }
    
    private var inspectActions: [ActionItem] {
        [
            ActionItem(title: "Verify Disk", icon: "checkmark.seal", color: .green) { showVerifyDisk = true },
            ActionItem(title: "Validate Boot", icon: "bolt.shield", color: .indigo) { showBootDiskValidator = true },
            ActionItem(title: "Catalog", icon: "list.bullet.rectangle", color: .orange) { showCatalogBrowser = true },
            ActionItem(title: "Samples", icon: "waveform", color: .cyan) { showSampleBrowser = true },
            ActionItem(title: "Presets", icon: "music.note.list", color: .purple) { showPresetBrowser = true },
            ActionItem(title: showHex ? "Hide Hex" : "Hex View", icon: "number.square", color: .gray) { withAnimation { showHex.toggle() } },
        ]
    }
    
    private var dangerActions: [ActionItem] {
        [
            ActionItem(title: "Format", icon: "internaldrive.trianglebadge.exclamationmark", color: .orange) { showFormatSheet = true },
            ActionItem(title: "Trash", icon: "trash", color: .red) { showDeleteConfirmation = true },
        ]
    }
    
    // MARK: - Details
    
    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.headline)
            
            DetailGrid {
                DetailRow(label: "SCSI ID", value: image.scsiID.map { "\($0)" } ?? "Not assigned")
                DetailRow(label: "Image Index", value: image.imageIndex.map { "\($0)" } ?? "None")
                DetailRow(label: "ZuluSCSI Name", value: image.zuluSCSIName)
                DetailRow(label: "Path", value: image.url.lastPathComponent, detail: image.url.deletingLastPathComponent().path)
            }
        }
    }
    
    // MARK: - Hex
    
    private var hexSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Hex Preview")
                    .font(.headline)
                Text("· first 512 bytes")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(hexPreview, forType: .string)
                    appState.addActivity("Hex dump copied", type: .info)
                } label: {
                    Label("Copy", systemImage: "doc.on.clipboard")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            
            ScrollView([.horizontal, .vertical]) {
                Text(hexPreview)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxHeight: 240)
        }
    }
    
    // MARK: - Bank Browser
    
    private func openBankBrowser() {
        // For now, always use sheet mode (works reliably)
        // NavigationStack + async parsing has issues
        showBankBrowser = true
    }
    
    // MARK: - Data loading
    
    private func loadImageInfo() {
        validation = appState.imageService.validateImage(at: image.url, device: image.deviceType)
        loadHexPreview()
        // Fast BNT-only scan — reads header (512B) + BNT (< 3KB), no cluster data
        Task {
            do {
                let result = try BankExtractor.countBanks(in: image.url)
                await MainActor.run {
                    self.bankCount = result.count
                }
            } catch {
                await MainActor.run {
                    self.bankCount = nil
                }
            }
        }
        osName = nil
        freeSpace = nil
    }
    
    private func loadHexPreview() {
        guard let handle = try? FileHandle(forReadingFrom: image.url) else {
            hexPreview = "Cannot read file"
            return
        }
        defer { handle.closeFile() }
        hexPreview = formatHexDump(handle.readData(ofLength: 512))
    }
    
    private func exportImageToWAV() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Choose export destination for WAV files"
        panel.prompt = "Export"
        
        guard panel.runModal() == .OK, let destURL = panel.url else { return }
        
        appState.statusMessage = "Exporting samples…"
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let results = try SampleExporter.exportImage(
                    imageURL: image.url,
                    to: destURL,
                    format: .wav,
                    normalize: false
                ) { name, progress in
                    DispatchQueue.main.async {
                        appState.statusMessage = "Exporting \(name)… (\(Int(progress * 100))%)"
                    }
                }
                
                DispatchQueue.main.async {
                    appState.addActivity("Exported \(results.count) WAVs from \(image.filename)", type: .success)
                    NSWorkspace.shared.open(destURL)
                }
            } catch {
                DispatchQueue.main.async {
                    appState.addActivity("Export failed: \(error.localizedDescription)", type: .error)
                }
            }
        }
    }
    
    private func loadBankCount() {
        // Cancel previous parse if still running
        parseTask?.cancel()
        
        // Show placeholder immediately
        bankCount = nil
        osName = "Loading..."
        freeSpace = "..."
        
        let imageURL = image.url
        
        parseTask = Task.detached(priority: .userInitiated) {
            // Add 3 second timeout
            let parseTask = Task {
                try EmaxIIParser.parseHDImage(at: imageURL)
            }
            
            do {
                // Wait with timeout
                try await withThrowingTaskGroup(of: EmaxIIFileSystem?.self) { group in
                    group.addTask { try await parseTask.value }
                    
                    // Timeout task
                    group.addTask {
                        try await Task.sleep(for: .seconds(3))
                        return nil
                    }
                    
                    // Return first completed task
                    if let fs = try await group.next() ?? nil {
                        guard !Task.isCancelled else { return }
                        
                        await MainActor.run {
                            self.bankCount = fs.userBanks.count
                            self.osName = fs.osName
                            let freeBytes = fs.freeClusters * fs.clusterSize
                            self.freeSpace = ByteCountFormatter.string(fromByteCount: Int64(freeBytes), countStyle: .file)
                        }
                    } else {
                        // Timeout
                        parseTask.cancel()
                        await MainActor.run {
                            self.bankCount = nil
                            self.osName = "Timeout"
                            self.freeSpace = "Try Browse Banks"
                        }
                    }
                    
                    // Cancel remaining tasks
                    group.cancelAll()
                }
            } catch {
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.bankCount = nil
                    self.osName = "Parse error"
                    self.freeSpace = "N/A"
                }
            }
        }
    }
    
    private func formatHexDump(_ data: Data) -> String {
        var lines: [String] = []
        let bpl = 16
        for offset in stride(from: 0, to: data.count, by: bpl) {
            let end = min(offset + bpl, data.count)
            let chunk = data[offset..<end]
            let addr = String(format: "%04X", offset)
            let hex = chunk.map { String(format: "%02X", $0) }.joined(separator: " ")
            let ascii = chunk.map { (0x20...0x7E).contains($0) ? String(UnicodeScalar($0)) : "." }.joined()
            let padded = hex.padding(toLength: bpl * 3 - 1, withPad: " ", startingAt: 0)
            lines.append("\(addr)  \(padded)  |\(ascii)|")
        }
        return lines.joined(separator: "\n")
    }
    
    private func convertToHDA() {
        let dir = image.url.deletingLastPathComponent()
        let newName = image.url.deletingPathExtension().lastPathComponent + ".hda"
        let dest = dir.appendingPathComponent(newName)
        do {
            try appState.imageService.convertEZ2toHDA(source: image.url, destination: dest)
            appState.refreshImages()
            appState.addActivity("Converted → \(newName)", type: .success)
        } catch {
            appState.addActivity("Error: \(error.localizedDescription)", type: .error)
        }
    }
    
    // MARK: - Drag & drop EB2 directly onto detail view
    
    private func handleEB2Drop(_ providers: [NSItemProvider]) -> Bool {
        var eb2URLs: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                defer { group.leave() }
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                let ext = url.pathExtension.lowercased()
                if ext == "eb2" {
                    eb2URLs.append(url)
                } else if SampleConverter.supportedExtensions.contains(ext) {
                    // Audio file — convert and import
                    DispatchQueue.main.async {
                        let name = String(url.deletingPathExtension().lastPathComponent.prefix(12))
                        do {
                            let result = try SampleConverter.convertAndImport(audioURLs: [url], bankName: name, imageURL: image.url)
                            appState.addActivity("Converted & imported \"\(result.bankName)\"", type: .success)
                            loadBankCount()
                        } catch {
                            appState.addActivity("Convert error: \(error.localizedDescription)", type: .error)
                        }
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            guard !eb2URLs.isEmpty else { return }
            
            let (results, errors) = BankImporter.importBanks(eb2URLs: eb2URLs, into: image.url)
            if !results.isEmpty {
                appState.addActivity("Imported \(results.count) bank(s)", type: .success)
                loadBankCount()
            }
            if !errors.isEmpty {
                appState.addActivity("\(errors.count) import error(s)", type: .error)
            }
        }
        return true
    }
    
    private func performDelete() {
        do {
            try appState.fileService.trashImage(image)
            appState.refreshImages()
            appState.selectedImage = nil
            appState.addActivity("Moved \(image.filename) to trash", type: .warning)
        } catch {
            appState.addActivity("Failed to delete: \(error.localizedDescription)", type: .error)
        }
    }
}

// MARK: - Supporting Views

struct QuickInfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct ActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
        }
        .buttonStyle(.bordered)
        .tint(color)
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
        }
        .font(.callout)
    }
}

struct DetailGrid<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
