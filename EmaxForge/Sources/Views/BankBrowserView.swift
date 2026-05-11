import SwiftUI
import UniformTypeIdentifiers

/// Browse, delete, export, and import banks in an EMAX II HD image
struct BankBrowserView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let image: DiskImage
    let preloadedFileSystem: EmaxIIFileSystem?
    
    @State private var fileSystem: EmaxIIFileSystem?
    
    init(image: DiskImage, preloadedFileSystem: EmaxIIFileSystem? = nil) {
        self.image = image
        self.preloadedFileSystem = preloadedFileSystem
    }
    @State private var selectedBank: BankCatalogEntry?
    @State private var bankDetail: EmaxIIBankData?
    @State private var parseError: String?
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var showDeleteConfirm = false
    @State private var bankToDelete: BankCatalogEntry?
    @State private var dragOver = false
    @State private var statusMessage: String?
    @State private var isImporting = false
    @State private var importProgress: String?
    
    // Sample preview
    @StateObject private var samplePlayer = SamplePlayer()
    @StateObject private var instrumentPlayer = InstrumentPlayer()
    @State private var sampleData: BankSampleData?
    @State private var waveformSamples: [Float] = []
    @State private var selectedSampleIndex: Int = 0
    @State private var selectedSampleRate: Double = Double(EmaxIIFormat.defaultSampleRate)
    @State private var showInstrumentPlayer = false
    
    // Sample editor
    @State private var showSampleEditor = false
    @State private var sampleToEdit: BankSampleData.SampleEntry?
    
    // Preset editor
    @State private var showPresetEditor = false
    @State private var showExtractSamples = false
    @State private var bankToExtract: BankCatalogEntry?
    @State private var showInspector = false
    @State private var currentPresetParams: VoiceParameters?
    @State private var currentPresetIndex: Int = 0
    
    // Multi-bank selection (issue #1)
    @State private var selectedBanks: Set<UUID> = []
    @State private var showBatchDeleteConfirm = false
    @State private var lastSelectedBankIndex: Int? = nil
    
    // Export banks sheet (issue #1)
    @State private var showExportBanks = false

    // Batch sample processing sheet
    @State private var showBatchProcessing = false

    // Voice zone editor sheet
    @State private var showVoiceZoneEditor = false

    // Bank merge sheet
    @State private var showMerge = false

    // Preset reorder sheet
    @State private var showPresetReorder = false
    
    var filteredBanks: [BankCatalogEntry] {
        guard let fs = fileSystem else { return [] }
        let banks = fs.userBanks
        if searchText.isEmpty { return banks }
        return banks.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    // Fix #2: Detect if image is on SD card
    var isOnSDCard: Bool {
        image.url.path.starts(with: "/Volumes/")
    }
    
    // Fix #4: Disk type label
    var diskTypeLabel: String? {
        let filename = image.filename.lowercased()
        if filename.hasPrefix("hd0") || filename.hasPrefix("hd10") {
            return fileSystem?.hasOS == true ? "Boot Disk" : "SCSI ID 1"
        } else if filename.hasPrefix("hd1") || filename.hasPrefix("hd20") {
            return "Data Disk"
        } else if filename.hasPrefix("hd2") || filename.hasPrefix("hd30") {
            return "Data Disk"
        }
        return nil
    }
    
    // Fix #4: Multi-disk pairing hint
    var multiDiskHint: String? {
        let filename = image.filename.lowercased()
        if filename.hasPrefix("hd10") {
            return "↳ Pairs with HD20.hda (data disk)"
        } else if filename.hasPrefix("hd20") {
            return "↳ Pairs with HD10.hda (boot disk)"
        }
        return nil
    }
    
    // Fix #5: Estimate max banks based on cluster size
    func estimateMaxBanks(fs: EmaxIIFileSystem) -> Int {
        // Average bank size: ~500 KB = ~16 clusters (32 KB each)
        // Conservative estimate: 70% of free space for banks
        let usableSpace = Double(fs.freeClusters) * 0.7
        let avgClustersPerBank = 16.0
        return max(10, Int(usableSpace / avgClustersPerBank))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            // Fix #2: SD card warning
            if isOnSDCard {
                HStack(spacing: 8) {
                    Image(systemName: "sdcard")
                        .foregroundStyle(.orange)
                    Text("Writing to SD card - imports may be slow")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.1))
            }
            
            Divider()
            
            if isLoading {
                ProgressView("Parsing image…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = parseError {
                errorView(error)
            } else if let fs = fileSystem {
                ZStack {
                    HSplitView {
                        bankListPanel(fs)
                            .frame(minWidth: 300, idealWidth: 340)
                        
                        if let bank = selectedBank {
                            bankDetailPanel(bank, fs: fs)
                        } else {
                            emptyDetailPanel
                        }
                    }
                    .disabled(isImporting)
                    .blur(radius: isImporting ? 2 : 0)
                    
                    // Progress overlay (Fix #1)
                    if isImporting {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(.circular)
                            Text(importProgress ?? "Writing to disk...")
                                .font(.headline)
                            Text("This may take a while on SD cards")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(32)
                        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 20)
                    }
                }
            }
            
            // Status bar
            if let msg = statusMessage {
                HStack {
                    Image(systemName: "info.circle")
                    Text(msg)
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(.bar)
                .transition(.move(edge: .bottom))
            }
        }
        .frame(minWidth: 1100, idealWidth: 1200, minHeight: 700, idealHeight: 750)
        .task { await parseImage() }
        .onExitCommand { dismiss() }
        .sheet(isPresented: $showSampleEditor) {
            if let sample = sampleToEdit {
                WaveformEditorView(
                    pcmData: sample.pcmData,
                    sampleRate: Double(sample.sampleRate),
                    sampleName: sample.name
                ) { editedPCM in
                    guard let bank = selectedBank, let fs = fileSystem else { return }
                    Task {
                        do {
                            try PCMReallocator.replaceSamplePCM(
                                bankEntry: bank,
                                sampleIndex: sample.index,
                                newPCM: editedPCM,
                                imageURL: image.url
                            )
                            await MainActor.run {
                                statusMessage = "Sample '\(sample.name)' saved to bank ✓"
                                loadBankDetail(bank, fs: fs)
                            }
                        } catch {
                            await MainActor.run {
                                statusMessage = "Save failed: \(error.localizedDescription)"
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPresetEditor) {
            if let params = currentPresetParams, let bank = selectedBank {
                PresetEditorView(
                    params: params,
                    presetName: bank.name
                ) { editedParams in
                    // Wired: voiceRecords (all 16 voice params). Name/keyMap require extended PresetEditorView.
                    let presetIndex = currentPresetIndex
                    let update = PresetWriteService.PresetUpdate(
                        name: nil,
                        voiceRecords: [editedParams.toData()],
                        keyMap: nil
                    )
                    do {
                        try PresetWriteService.updatePreset(
                            at: presetIndex, update: update, in: bank, imageURL: image.url
                        )
                        statusMessage = "Preset \(presetIndex + 1) saved to \(bank.name) ✓"
                    } catch {
                        statusMessage = "Save failed: \(error.localizedDescription)"
                    }
                }
            }
        }
        .sheet(isPresented: $showExtractSamples) {
            if let bank = bankToExtract {
                ExtractSamplesSheet(image: image, bankName: bank.name)
            }
        }
        .sheet(isPresented: $showInspector) {
            if let bank = selectedBank {
                InspectorPanel(bank: bank, imageURL: image.url)
            }
        }
        .sheet(isPresented: $showExportBanks) {
            BankExportView(image: image)
        }
        .sheet(isPresented: $showBatchProcessing) {
            if let bank = selectedBank, let sd = sampleData {
                BatchSampleProcessingView(
                    bankEntry: bank,
                    imageURL: image.url,
                    samples: sd.samples
                )
            }
        }
        .sheet(isPresented: $showVoiceZoneEditor) {
            if let bank = selectedBank, let sd = sampleData {
                let presetCount = bankDetail?.numPresets ?? 1
                let names: [String] = (0..<presetCount).map { _ in "" } // preset names not yet parsed per-slot
                VoiceZoneEditorView(
                    bankEntry: bank,
                    imageURL: image.url,
                    initialPresetIndex: 0,
                    presetNames: names,
                    samples: sd.samples
                )
            }
        }
        .sheet(isPresented: $showMerge) {
            if let bank = selectedBank, let fs = fileSystem {
                BankMergeView(
                    sourceBank: bank,
                    imageURL: image.url,
                    allBanks: fs.userBanks
                )
            }
        }
        .sheet(isPresented: $showPresetReorder) {
            if let bank = selectedBank {
                PresetReorderView(
                    bankEntry: bank,
                    imageURL: image.url
                )
            }
        }
        .alert("Delete Bank?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let bank = bankToDelete {
                Text("Delete \"\(bank.name)\" from this image? This frees \(bank.formattedSize) but cannot be undone.")
            }
        }
        .alert("Delete \(selectedBanks.count) Banks?", isPresented: $showBatchDeleteConfirm) {
            Button("Delete All", role: .destructive) { performBatchDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Permanently delete \(selectedBanks.count) selected banks? This cannot be undone.")
        }
    }
    
    // MARK: - Header
    
    private var headerBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "internaldrive")
                .foregroundStyle(Theme.accent)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                // Fix #4: Show disk type context
                HStack(spacing: 6) {
                    Text(image.filename)
                        .font(.headline)
                    if let diskType = diskTypeLabel {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(diskType)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
                if let fs = fileSystem {
                    // Fix #5: Show capacity with max banks
                    let maxBanks = estimateMaxBanks(fs: fs)
                    Text("\(fs.userBanks.count)/\(maxBanks) banks · \(ByteCountFormatter.string(fromByteCount: Int64(fs.imageSize), countStyle: .file)) · \(fs.freeClusters) clusters free")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // Fix #4: Multi-disk hint
                if let pairHint = multiDiskHint {
                    Text(pairHint)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            // Multi-select batch toolbar (issue #4)
            if selectedBanks.count > 1 {
                HStack(spacing: 8) {
                    Text("\(selectedBanks.count) selected")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.accent.opacity(0.15), in: Capsule())
                    
                    Button {
                        batchExportBanks()
                    } label: {
                        Label("Export All", systemImage: "square.and.arrow.up.on.square")
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.cyan)
                    
                    Button(role: .destructive) {
                        showBatchDeleteConfirm = true
                    } label: {
                        Label("Delete All", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                
                Divider()
                    .frame(height: 20)
            }
            
            // Export banks button (issue #1)
            Button {
                showExportBanks = true
            } label: {
                Label("Export Banks…", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .disabled(fileSystem == nil)
            
            // Import button
            Button {
                importEB2Files()
            } label: {
                Label("Import .EB2", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)
            .tint(Theme.cyan)
            
            Button("Done") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
        .background(.bar)
    }
    
    // MARK: - Bank list panel
    
    private func bankListPanel(_ fs: EmaxIIFileSystem) -> some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                TextField("Search banks…", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            .padding(10)
            
            List(selection: $selectedBank) {
                if fs.hasOS, let osEntry = fs.banks.first, searchText.isEmpty {
                    Section("System") {
                        BankRow(entry: osEntry, isOS: true, sourceImagePath: nil)
                            .tag(osEntry)
                    }
                }
                
                Section("\(filteredBanks.count) Bank\(filteredBanks.count == 1 ? "" : "s")") {
                    // Fix #3: Empty state
                    if filteredBanks.isEmpty && searchText.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 32))
                                .foregroundStyle(.tertiary)
                            Text("No banks yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Button {
                                importEB2Files()
                            } label: {
                                Label("Import Banks", systemImage: "square.and.arrow.down")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.cyan)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                        .listRowBackground(Color.clear)
                    }
                    
                    ForEach(Array(filteredBanks.enumerated()), id: \.element.id) { index, bank in
                        let isMultiSelected = selectedBanks.contains(bank.id)
                        BankRow(
                            entry: bank,
                            isOS: false,
                            sourceImagePath: image.url.path,
                            isFavorite: appState.favoritesManager.isFavorite(bankName: bank.name),
                            isMultiSelected: isMultiSelected
                        )
                        .tag(bank)
                        .background(
                            isMultiSelected
                                ? Theme.accent.opacity(0.15)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .simultaneousGesture(
                            TapGesture()
                                .modifiers(.command)
                                .onEnded {
                                    // Cmd+click: toggle individual selection
                                    if selectedBanks.contains(bank.id) {
                                        selectedBanks.remove(bank.id)
                                    } else {
                                        selectedBanks.insert(bank.id)
                                        selectedBank = bank
                                    }
                                    lastSelectedBankIndex = index
                                }
                        )
                        .simultaneousGesture(
                            TapGesture()
                                .modifiers(.shift)
                                .onEnded {
                                    // Shift+click: range select
                                    let anchor = lastSelectedBankIndex ?? index
                                    let lo = min(anchor, index)
                                    let hi = max(anchor, index)
                                    for i in lo...hi {
                                        selectedBanks.insert(filteredBanks[i].id)
                                    }
                                    selectedBank = bank
                                    lastSelectedBankIndex = index
                                }
                        )
                        .contextMenu {
                            if selectedBanks.count > 1 && selectedBanks.contains(bank.id) {
                                Button("Export \(selectedBanks.count) Banks…") { batchExportBanks() }
                                Button("Delete \(selectedBanks.count) Banks", role: .destructive) {
                                    showBatchDeleteConfirm = true
                                }
                                Divider()
                                Button("Clear Selection") { selectedBanks.removeAll() }
                                Divider()
                            }
                            Button {
                                appState.favoritesManager.toggleFavorite(bankName: bank.name)
                            } label: {
                                Label(
                                    appState.favoritesManager.isFavorite(bankName: bank.name) ? "Unfavorite" : "Favorite",
                                    systemImage: appState.favoritesManager.isFavorite(bankName: bank.name) ? "star.slash" : "star"
                                )
                            }
                            Button("Export as .EB2…") { exportSingleBank(bank) }
                            Button("Extract Samples…") {
                                bankToExtract = bank
                                showExtractSamples = true
                            }
                            Button("Inspect Bank…") {
                                selectedBank = bank
                                showInspector = true
                            }
                            Divider()
                            Button("Delete Bank", role: .destructive) {
                                bankToDelete = bank
                                showDeleteConfirm = true
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .onChange(of: selectedBank) { _, newBank in
                loadBankDetail(newBank, fs: fs)
            }
        }
        .overlay {
            if dragOver {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.mint, lineWidth: 3)
                    .background(.mint.opacity(0.08))
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.title)
                            Text("Drop .EB2 to import")
                                .font(.headline)
                        }
                        .foregroundStyle(.mint)
                    }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            handleEB2Drop(providers)
        }
    }
    
    // MARK: - Bank detail panel
    
    private func bankDetailPanel(_ entry: BankCatalogEntry, fs: EmaxIIFileSystem) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.accentGradient)
                            .frame(width: 64, height: 64)
                            .shadow(color: .orange.opacity(0.3), radius: 6, y: 3)
                        VStack(spacing: 0) {
                            Text("BANK")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .tracking(1)
                            Text("\(entry.catalogIndex)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.name)
                            .font(.title2.bold())
                        Text("\(entry.numPresets) preset(s) · \(entry.formattedSize) · \(entry.clusterChain.count) cluster(s)")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                
                // Actions
                HStack(spacing: 8) {
                    Button {
                        appState.favoritesManager.toggleFavorite(bankName: entry.name)
                    } label: {
                        Label(
                            appState.favoritesManager.isFavorite(bankName: entry.name) ? "Favorited" : "Favorite",
                            systemImage: appState.favoritesManager.isFavorite(bankName: entry.name) ? "star.fill" : "star"
                        )
                    }
                    .buttonStyle(.bordered)
                    .tint(appState.favoritesManager.isFavorite(bankName: entry.name) ? .yellow : .secondary)
                    
                    Button {
                        currentPresetIndex = 0   // Edit first preset; user can switch in PresetEditorView
                        currentPresetParams = VoiceParameters()
                        showPresetEditor = true
                    } label: {
                        Label("Edit Preset", systemImage: "waveform.path")
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                    
                    Button {
                        exportSingleBank(entry)
                    } label: {
                        Label("Export .EB2", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.cyan)

                    Button {
                        showBatchProcessing = true
                    } label: {
                        Label("Batch Process", systemImage: "waveform.badge.magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                    .disabled(sampleData?.samples.isEmpty ?? true)

                    Button {
                        showVoiceZoneEditor = true
                    } label: {
                        Label("Voice Zones", systemImage: "pianokeys")
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                    .disabled(sampleData?.samples.isEmpty ?? true)

                    if let fs = fileSystem, fs.userBanks.count >= 2 {
                        Button {
                            showMerge = true
                        } label: {
                            Label("Merge Into…", systemImage: "arrow.triangle.merge")
                        }
                        .buttonStyle(.bordered)
                        .tint(.indigo)
                    }

                    Button {
                        showPresetReorder = true
                    } label: {
                        Label("Reorder Presets", systemImage: "arrow.up.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                    .disabled((entry.numPresets) < 2)

                    Button(role: .destructive) {
                        bankToDelete = entry
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(entry.startCluster == 1) // Can't delete OS
                }
                
                Divider()
                
                // Catalog info
                DetailGrid {
                    DetailRow(label: "Start Cluster", value: "\(entry.startCluster)")
                    DetailRow(label: "Chain", value: entry.clusterChain.map(String.init).joined(separator: " → "))
                    DetailRow(label: "Presets", value: "\(entry.numPresets)")
                    DetailRow(label: "Flags", value: String(format: "0x%02X", entry.flags))
                }
                
                // Parsed bank detail
                if let detail = bankDetail {
                    DetailGrid {
                        Text("Bank Data")
                            .font(.headline)
                            .padding(.bottom, 4)
                        DetailRow(label: "Internal Name", value: "\"\(detail.bankName)\"")
                        DetailRow(label: "Presets", value: "\(detail.numPresets)")
                        DetailRow(label: "Samples", value: "\(detail.numSamples)")
                        if detail.numZones > 0 {
                            DetailRow(label: "Zones (P1)", value: "\(detail.numZones)")
                        }
                        DetailRow(label: "Sample Data", value: "~\(ByteCountFormatter.string(fromByteCount: Int64(detail.sampleDataSize), countStyle: .file))")
                    }

                    // EB2 format detected: no sample param table — offer one-click EMX conversion
                    if detail.sampleParameters.isEmpty && detail.numSamples > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("EB2 format — sample param table missing. Batch processing and pitch editing require EMX format.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Convert to EMX") {
                                convertBankToEMX(entry)
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                            .disabled(isImporting)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(6)
                    }

                    if let preset = detail.presetHeader {
                        DetailGrid {
                            Text("Preset Parameters")
                                .font(.headline)
                                .padding(.bottom, 4)
                            DetailRow(label: "Volume", value: "\(preset.volume)")
                            DetailRow(label: "Transpose", value: "\(preset.transpose)")
                            DetailRow(label: "Tune", value: "\(preset.tuneCoarse) / \(preset.tuneFine)")
                        }
                    }
                }
                
                // Sample Preview & List
                if let sData = sampleData, !sData.samples.isEmpty {
                    samplePreviewSection(sData)
                    
                    // Piano keyboard for playing samples
                    keyboardSection(sData)
                    
                    if sData.samples.count > 1 || sData.samples.first?.name != "Full Bank" {
                        sampleListSection(sData)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Sample Preview
    
    private func samplePreviewSection(_ sData: BankSampleData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                Text("Sample Preview")
                    .font(.headline)
                
                if sData.samples.count > 1 {
                    Text("(\(sData.samples.count) samples)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Duration of selected sample
                let currentSample = selectedSample(from: sData)
                Text(SamplePlayer.formatDuration(currentSample.duration))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                // Sample rate picker (EMAX II native rates)
                Picker("Rate", selection: $selectedSampleRate) {
                    ForEach(SamplePlayer.sampleRates, id: \.self) { rate in
                        Text(rate >= 1000 ? "\(String(format: "%.1f", rate / 1000))k" : "\(Int(rate))").tag(rate)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
                .onChange(of: selectedSampleRate) { _, newRate in
                    if samplePlayer.isPlaying {
                        samplePlayer.play(pcmData: selectedSample(from: sData).pcmData, sampleRate: newRate)
                    }
                }
            }
            
            // Waveform
            WaveformView(
                samples: waveformSamples,
                playbackProgress: samplePlayer.playbackProgress,
                accentColor: Theme.accent
            )
            .frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Transport controls
            HStack(spacing: 16) {
                // Play/Stop
                Button {
                    let sample = selectedSample(from: sData)
                    samplePlayer.togglePlayback(pcmData: sample.pcmData, sampleRate: selectedSampleRate)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: samplePlayer.isPlaying ? "stop.fill" : "play.fill")
                            .font(.title3)
                        Text(samplePlayer.isPlaying ? "Stop" : "Play")
                    }
                    .frame(width: 80)
                }
                .buttonStyle(.borderedProminent)
                .tint(samplePlayer.isPlaying ? Theme.danger : Theme.accent)
                .keyboardShortcut(.space, modifiers: [])
                
                // Sample picker (if multiple samples with names from param table)
                if sData.samples.count > 1 {
                    Picker("Sample", selection: $selectedSampleIndex) {
                        ForEach(sData.samples.indices, id: \.self) { i in
                            Text(sData.samples[i].name).tag(i)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                    .onChange(of: selectedSampleIndex) { _, _ in
                        let sample = selectedSample(from: sData)
                        selectedSampleRate = Double(sample.sampleRate)
                        waveformSamples = SamplePlayer.waveformSamples(from: sample.pcmData, targetPoints: 250)
                        if samplePlayer.isPlaying { samplePlayer.stop() }
                    }
                }
                
                Spacer()
                
                // Info
                VStack(alignment: .trailing, spacing: 2) {
                    let sample = selectedSample(from: sData)
                    Text("\(sample.frameCount) frames")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text("16-bit mono")
                        if sample.loopStart != nil { Text("· 🔁 loop") }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .background(Theme.bgCard.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Keyboard
    
    private func keyboardSection(_ sData: BankSampleData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "pianokeys")
                    .foregroundStyle(Theme.accent)
                Text("Play Instrument")
                    .font(.headline)
                
                Spacer()
                
                if instrumentPlayer.isReady {
                    if let note = instrumentPlayer.activeNote {
                        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
                        let octave = Int(note) / 12 - 1
                        let semitone = Int(note) % 12
                        Text("\(names[semitone])\(octave)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Theme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                    }
                    
                    Text("Root: \(rootKeyName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            KeyboardView(
                startOctave: max(0, Int(instrumentPlayer.rootKey) / 12 - 2),
                octaves: 3,
                activeNote: instrumentPlayer.activeNote,
                onNoteOn: { note in
                    instrumentPlayer.noteOn(note, velocity: 100)
                },
                onNoteOff: { note in
                    instrumentPlayer.noteOff(note)
                }
            )
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Hint
            Text("Click keys to play the sample at different pitches")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Theme.bgCard.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .onAppear {
            // Load all samples as instrument
            instrumentPlayer.loadSamples(from: sData)
        }
        .onChange(of: selectedSampleIndex) { _, _ in
            // When switching samples, load the selected one
            let sample = selectedSample(from: sData)
            instrumentPlayer.loadSingle(
                pcmData: sample.pcmData,
                sampleRate: sample.sampleRate,
                rootKey: sample.rootKey
            )
        }
    }
    
    private var rootKeyName: String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let note = Int(instrumentPlayer.rootKey)
        let octave = note / 12 - 1
        let semitone = note % 12
        return "\(names[semitone])\(octave)"
    }
    
    /// Get the currently selected sample entry
    private func selectedSample(from sData: BankSampleData) -> BankSampleData.SampleEntry {
        let idx = min(selectedSampleIndex, sData.samples.count - 1)
        return sData.samples[max(0, idx)]
    }
    
    // MARK: - Sample List
    
    private func sampleListSection(_ sData: BankSampleData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Samples")
                    .font(.headline)
                
                Spacer()
                
                // Export all button
                Button {
                    exportSamples(sData)
                } label: {
                    Label("Export All to WAV", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
            }
            
            // Sample rows with mini waveforms
            ForEach(sData.samples.indices, id: \.self) { i in
                let sample = sData.samples[i]
                let isSelected = selectedSampleIndex == i
                
                HStack(spacing: 10) {
                    // Play button
                    Button {
                        selectedSampleIndex = i
                        selectedSampleRate = Double(sample.sampleRate)
                        waveformSamples = SamplePlayer.waveformSamples(from: sample.pcmData, targetPoints: 250)
                        samplePlayer.play(pcmData: sample.pcmData, sampleRate: Double(sample.sampleRate))
                    } label: {
                        Image(systemName: samplePlayer.isPlaying && isSelected ? "stop.circle.fill" : "play.circle.fill")
                            .font(.title3)
                            .foregroundStyle(isSelected ? Theme.accent : .secondary)
                    }
                    .buttonStyle(.plain)
                    
                    // Sample info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sample.name)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            Text(SamplePlayer.formatDuration(sample.duration))
                                .font(.caption2.monospaced())
                            Text("·")
                            Text("\(sample.sampleRate / 1000)k")
                                .font(.caption2)
                            if sample.loopStart != nil {
                                Text("· 🔁")
                                    .font(.caption2)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Mini waveform
                    MiniWaveformView(
                        samples: SamplePlayer.waveformSamples(from: sample.pcmData, targetPoints: 40),
                        color: isSelected ? Theme.accent : .gray
                    )
                    .frame(width: 80, height: 24)
                    .opacity(0.8)
                    
                    // Size
                    Text(ByteCountFormatter.string(fromByteCount: Int64(sample.pcmData.count), countStyle: .file))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 50, alignment: .trailing)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(isSelected ? Theme.accent.opacity(0.1) : Color.clear,
                           in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedSampleIndex = i
                    selectedSampleRate = Double(sample.sampleRate)
                    waveformSamples = SamplePlayer.waveformSamples(from: sample.pcmData, targetPoints: 250)
                    if samplePlayer.isPlaying { samplePlayer.stop() }
                }
                .contextMenu {
                    Button("Edit Sample…") {
                        sampleToEdit = sample
                        showSampleEditor = true
                    }
                    
                    Divider()
                    
                    Button("Export as WAV…") {
                        exportSingleSample(sample)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.bgCard.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Export
    
    @State private var exportMessage: String?
    
    private func exportSingleSample(_ sample: BankSampleData.SampleEntry) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Choose export destination"
        panel.prompt = "Export"
        
        guard panel.runModal() == .OK, let destDir = panel.url else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try SampleExporter.exportSample(
                    sample,
                    to: destDir,
                    format: .wav,
                    normalize: false
                )
                
                DispatchQueue.main.async {
                    statusMessage = "Exported \(sample.name) to WAV"
                    NSWorkspace.shared.activateFileViewerSelecting([result.outputURL])
                }
            } catch {
                DispatchQueue.main.async {
                    statusMessage = "Export failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func exportSamples(_ sData: BankSampleData) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Choose export destination"
        panel.prompt = "Export"
        
        guard panel.runModal() == .OK, let destURL = panel.url else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let bankName = bankDetail?.bankName ?? "Untitled"
                let results = try SampleExporter.exportAllSamples(
                    from: sData,
                    bankName: bankName,
                    to: destURL,
                    format: .wav,
                    normalize: false,
                    createSubfolder: true
                )
                
                DispatchQueue.main.async {
                    statusMessage = "Exported \(results.count) samples to \(destURL.lastPathComponent)/\(bankName)"
                    NSWorkspace.shared.open(destURL.appendingPathComponent(SampleExporter.sanitizeFilename(bankName)))
                }
            } catch {
                DispatchQueue.main.async {
                    statusMessage = "Export failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Empty detail
    
    private var emptyDetailPanel: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Select a bank")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Right-click to export or delete")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Theme.danger)
            Text(message)
                .foregroundStyle(.secondary)
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func parseImage() async {
        // If preloaded data exists, use it immediately
        if let preloaded = preloadedFileSystem {
            await MainActor.run {
                fileSystem = preloaded
                isLoading = false
            }
            return
        }
        
        // Otherwise parse normally (for sheet mode)
        isLoading = true
        defer { isLoading = false }
        do {
            let fs = try EmaxIIParser.parseHDImage(at: image.url)
            await MainActor.run { fileSystem = fs }
        } catch {
            await MainActor.run { parseError = error.localizedDescription }
        }
    }
    
    private func loadBankDetail(_ entry: BankCatalogEntry?, fs: EmaxIIFileSystem) {
        // Stop any playing sample when switching banks
        samplePlayer.stop()
        sampleData = nil
        waveformSamples = []
        selectedSampleIndex = 0
        
        guard let entry else { bankDetail = nil; return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = EmaxIIParser.readBankData(from: image.url, entry: entry, clusterSize: fs.clusterSize, clusterAreaStartSector: fs.clusterAreaStartSector) else { return }
            let detail = EmaxIIParser.parseBankData(data)
            let samples = EmaxIIParser.extractSampleData(from: data)
            
            // Generate waveform for first sample on background thread
            let waveform: [Float]
            if let firstSample = samples?.samples.first {
                waveform = SamplePlayer.waveformSamples(from: firstSample.pcmData, targetPoints: 250)
            } else {
                waveform = []
            }
            
            DispatchQueue.main.async {
                bankDetail = detail
                sampleData = samples
                waveformSamples = waveform
                if let firstSample = samples?.samples.first {
                    selectedSampleRate = Double(firstSample.sampleRate)
                }
            }
        }
    }
    
    private func performDelete() {
        guard let bank = bankToDelete, let _ = fileSystem else { return }
        do {
            try BankManager.deleteBank(entry: bank, from: image.url)
            selectedBank = nil
            bankDetail = nil
            statusMessage = "Deleted \"\(bank.name)\""
            appState.addActivity("Deleted bank \"\(bank.name)\"", type: .warning)
            // Re-parse
            Task {
                let newFS = try? EmaxIIParser.parseHDImage(at: image.url)
                await MainActor.run { fileSystem = newFS }
            }
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
        bankToDelete = nil
    }
    
    private func performBatchDelete() {
        guard fileSystem != nil else { return }
        let banksToDelete = filteredBanks.filter { selectedBanks.contains($0.id) }
        var deletedCount = 0
        var errors: [String] = []
        for bank in banksToDelete {
            do {
                try BankManager.deleteBank(entry: bank, from: image.url)
                deletedCount += 1
            } catch {
                errors.append(bank.name)
            }
        }
        selectedBanks.removeAll()
        selectedBank = nil
        bankDetail = nil
        let msg = "Deleted \(deletedCount) bank(s)" + (errors.isEmpty ? "" : ", \(errors.count) failed")
        statusMessage = msg
        appState.addActivity(msg, type: errors.isEmpty ? .success : .warning)
        Task {
            let newFS = try? EmaxIIParser.parseHDImage(at: image.url)
            await MainActor.run { fileSystem = newFS }
        }
    }
    
    private func batchExportBanks() {
        guard let fs = fileSystem else { return }
        let banksToExport = filteredBanks.filter { selectedBanks.contains($0.id) }
        guard !banksToExport.isEmpty else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Choose destination folder for \(banksToExport.count) banks"
        panel.prompt = "Export Here"
        
        guard panel.runModal() == .OK, let destDir = panel.url else { return }
        
        isImporting = true
        importProgress = "Exporting \(banksToExport.count) banks…"
        
        Task.detached(priority: .userInitiated) {
            var exportedCount = 0
            for bank in banksToExport {
                let destURL = destDir.appendingPathComponent("\(bank.name.trimmingCharacters(in: .whitespaces)).EB2")
                do {
                    try BankManager.exportBank(entry: bank, from: image.url, to: destURL, clusterSize: fs.clusterSize, clusterAreaStartSector: fs.clusterAreaStartSector)
                    exportedCount += 1
                } catch {
                    // Skip failed exports
                }
            }
            await MainActor.run {
                isImporting = false
                statusMessage = "Exported \(exportedCount) bank(s) to \(destDir.lastPathComponent)"
                appState.addActivity("Batch exported \(exportedCount) banks", type: .success)
                NSWorkspace.shared.open(destDir)
            }
        }
    }
    
    private func exportSingleBank(_ entry: BankCatalogEntry) {
        guard let fs = fileSystem else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "eb2") ?? .data]
        panel.nameFieldStringValue = "\(entry.name.trimmingCharacters(in: .whitespaces)).EB2"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try BankManager.exportBank(entry: entry, from: image.url, to: url, clusterSize: fs.clusterSize, clusterAreaStartSector: fs.clusterAreaStartSector)
                statusMessage = "Exported \"\(entry.name)\""
                appState.addActivity("Exported \"\(entry.name)\" to .EB2", type: .success)
            } catch {
                statusMessage = "Export error: \(error.localizedDescription)"
            }
        }
    }
    
    /// Convert an EB2-format bank (no sample param table) to full EMX format by injecting
    /// a generated parameter table. Required before batch processing or pitch editing.
    private func convertBankToEMX(_ entry: BankCatalogEntry) {
        guard let fs = fileSystem else { return }
        isImporting = true
        statusMessage = "Converting '\(entry.name)' to EMX format…"

        Task {
            do {
                let result = try EB2ParamTableBuilder.convertEB2ToEMX(
                    bankEntry: entry,
                    imageURL: image.url
                )
                await MainActor.run {
                    isImporting = false
                    statusMessage = "Converted '\(entry.name)': \(result.samplesDetected) sample(s) detected ✓"
                    appState.addActivity("Converted '\(entry.name)' to EMX format", type: .success)
                    // Reload bank data to show the new param table
                    loadBankDetail(entry, fs: fs)
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    statusMessage = "Conversion failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func importEB2Files() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = FormatConverter.emuExtensions.compactMap { UTType(filenameExtension: $0) }
        panel.message = "Select E-mu bank/image files to import"
        
        if panel.runModal() == .OK {
            let urls = panel.urls
            // Fix #1: Show progress during import
            isImporting = true
            importProgress = "Importing \(urls.count) bank(s)..."
            
            Task.detached(priority: .userInitiated) {
                let (results, errors) = FormatConverter.convertAndImport(urls: urls, into: image.url)
                
                await MainActor.run {
                    isImporting = false
                    statusMessage = "Imported \(results.count) bank(s)" + (errors.isEmpty ? "" : ", \(errors.count) error(s)")
                    appState.addActivity("Imported \(results.count) bank(s)", type: results.isEmpty ? .warning : .success)
                }
                
                let newFS = try? EmaxIIParser.parseHDImage(at: image.url)
                await MainActor.run { fileSystem = newFS }
            }
        }
    }
    
    private func handleEB2Drop(_ providers: [NSItemProvider]) -> Bool {
        var fileURLs: [URL] = []
        let group = DispatchGroup()
        let validExts = FormatConverter.emuExtensions.union(Set(SampleConverter.supportedExtensions))
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                defer { group.leave() }
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      validExts.contains(url.pathExtension.lowercased()) else { return }
                fileURLs.append(url)
            }
        }
        
        group.notify(queue: .main) {
            guard !fileURLs.isEmpty else { return }
            
            // Fix #1: Show progress during drag & drop import
            isImporting = true
            importProgress = "Importing \(fileURLs.count) file(s)..."
            
            Task.detached(priority: .userInitiated) {
                // Split into E-mu formats and audio files
                let emuFiles = fileURLs.filter { FormatConverter.emuExtensions.contains($0.pathExtension.lowercased()) }
                let audioFiles = fileURLs.filter { SampleConverter.supportedExtensions.contains($0.pathExtension.lowercased()) && !FormatConverter.emuExtensions.contains($0.pathExtension.lowercased()) }
                
                var totalImported = 0
                
                // Import E-mu formats
                if !emuFiles.isEmpty {
                    let (imported, _) = FormatConverter.convertAndImport(urls: emuFiles, into: image.url)
                    totalImported += imported.count
                }
                
                // Convert audio files
                for audioURL in audioFiles {
                    let name = String(audioURL.deletingPathExtension().lastPathComponent.prefix(12))
                    if let _ = try? SampleConverter.convertAndImport(audioURLs: [audioURL], bankName: name, imageURL: image.url) {
                        totalImported += 1
                    }
                }
                
                await MainActor.run {
                    isImporting = false
                    statusMessage = "Imported \(totalImported) bank(s)"
                    appState.addActivity("Dropped & imported \(totalImported) bank(s)", type: .success)
                }
                
                let newFS = try? EmaxIIParser.parseHDImage(at: image.url)
                await MainActor.run { fileSystem = newFS }
            }
        }
        return true
    }
}

// MARK: - Bank Row

struct BankRow: View {
    let entry: BankCatalogEntry
    let isOS: Bool
    var sourceImagePath: String? = nil  // For drag support
    var isFavorite: Bool = false
    var isMultiSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isOS ? Color.blue.gradient : Color.orange.gradient)
                    .frame(width: 32, height: 32)
                
                if isOS {
                    Image(systemName: "cpu")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                } else {
                    Text("\(entry.catalogIndex)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if !isOS {
                        Text("\(entry.numPresets)P")
                    }
                    Text(entry.formattedSize)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
            
            // Multi-select checkmark indicator
            if isMultiSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }
            
            // Drag indicator
            if !isOS && sourceImagePath != nil {
                Image(systemName: "hand.raised.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .draggable(createTransferPayload()) {
            // Drag preview
            HStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .foregroundStyle(Theme.accent)
                Text(entry.name)
                    .font(.caption.bold())
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
    }
    
    private func createTransferPayload() -> Data {
        guard let srcPath = sourceImagePath else { return Data() }
        
        let payload = BankTransferPayload(
            bankName: entry.name,
            catalogIndex: entry.catalogIndex,
            sourceImagePath: srcPath
        )
        return payload.jsonData ?? Data()
    }
}
