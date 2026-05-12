import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showBatchRename = false
    @State private var showBatchConvertor = false
    @State private var showZuluConfig = false
    @State private var showKnowledgeBase = false
    @State private var showBootableWizard = false
    @State private var showSlotManager = false
    @State private var showBackupRestore = false
    @State private var showFormatDisk = false
    @State private var showFormatVolume = false
    @State private var showCreateFloppy = false

    // New feature sheets (v0.6)
    @State private var showFATAnalyzer = false
    @State private var showBatchImport = false
    @State private var showHFEConverter = false
    @State private var showTemplateCreator = false
    @State private var showCatalogRaw = false
    @State private var showTemplateBrowser = false
    @State private var showTerminal = false
    @State private var showImageScanner = false
    @State private var showZuluValidator = false
    @State private var showAIAssistant = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        mainView
            .formatSheets(
                showFormatDisk: $showFormatDisk,
                showFormatVolume: $showFormatVolume,
                showCreateFloppy: $showCreateFloppy,
                appState: appState
            )
    }
    
    @State private var showCommandPalette = false
    @State private var showSuccessAnimation = false
    @State private var showOnboardingTour = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("onboardingStep") private var currentOnboardingStep = 0
    
    private var windowTitle: String {
        let base = "EmaxForge"
        return appState.autoSaveManager.hasUnsavedChanges ? base + " •" : base
    }
    
    private var mainView: some View {
        navigationSplitView
            .toolbar { toolbarContent }
            .navigationTitle(windowTitle)
            .navigationSubtitle(appState.selectedVolume?.name ?? "")
            .safeAreaInset(edge: .bottom) { statusBar }
            .successOverlay(isPresented: $showSuccessAnimation)
            .overlay {
                CommandPalette(isPresented: $showCommandPalette)
                    .environmentObject(appState)
            }
            .overlay {
                if showOnboardingTour {
                    OnboardingTourOverlay(
                        currentStep: $currentOnboardingStep,
                        isPresented: $showOnboardingTour,
                        onComplete: {
                            hasCompletedOnboarding = true
                            showOnboardingTour = false
                        }
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .commandPalette)) { _ in
                showCommandPalette = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .showOnboardingTour)) { _ in
                currentOnboardingStep = 0
                showOnboardingTour = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .showSuccess)) { _ in
                showSuccessAnimation = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .showGettingStarted)) { _ in
                // Reset wizard dismissed state and go to welcome
                UserDefaults.standard.set(false, forKey: "wizardDismissed")
                appState.selectedVolume = nil
                appState.selectedImage = nil
                appState.images = []
            }
            .appSheets(
                showBatchRename: $showBatchRename,
                showBatchConvertor: $showBatchConvertor,
                showZuluConfig: $showZuluConfig,
                showKnowledgeBase: $showKnowledgeBase,
                showBootableWizard: $showBootableWizard,
                showSlotManager: $showSlotManager,
                showBackupRestore: $showBackupRestore,
                appState: appState
            )
            .newFeatureSheets(
                showFATAnalyzer: $showFATAnalyzer,
                showBatchImport: $showBatchImport,
                showHFEConverter: $showHFEConverter,
                showTemplateCreator: $showTemplateCreator,
                showCatalogRaw: $showCatalogRaw,
                showTemplateBrowser: $showTemplateBrowser,
                showTerminal: $showTerminal,
                showImageScanner: $showImageScanner,
                showZuluValidator: $showZuluValidator,
                appState: appState
            )
            .menuHandlers(
                appState: appState,
                showKnowledgeBase: $showKnowledgeBase,
                showBootableWizard: $showBootableWizard,
                showBatchRename: $showBatchRename,
                showBatchConvertor: $showBatchConvertor,
                showSlotManager: $showSlotManager,
                showBackupRestore: $showBackupRestore,
                showZuluConfig: $showZuluConfig,
                showFormatDisk: $showFormatDisk,
                showFormatVolume: $showFormatVolume,
                showCreateFloppy: $showCreateFloppy,
                openLocalFolder: openLocalFolder
            )
            .newFeatureMenuHandlers(
                showFATAnalyzer: $showFATAnalyzer,
                showBatchImport: $showBatchImport,
                showHFEConverter: $showHFEConverter,
                showTemplateCreator: $showTemplateCreator,
                showCatalogRaw: $showCatalogRaw,
                showTemplateBrowser: $showTemplateBrowser,
                showTerminal: $showTerminal,
                showImageScanner: $showImageScanner,
                showZuluValidator: $showZuluValidator
            )
    }
    
    private func openLocalFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder containing disk images"
        
        if panel.runModal() == .OK, let url = panel.url {
            let volume = MountedVolume(
                url: url,
                name: url.lastPathComponent,
                isRemovable: false,
                totalSize: 0,
                freeSpace: 0
            )
            appState.selectedVolume = volume
            appState.refreshImages()
        }
    }
    
    private func closeVolume() {
        appState.selectedVolume = nil
        appState.selectedImage = nil
        appState.images = []
        appState.statusMessage = "Ready"
    }
    
    @ViewBuilder
    private var navigationSplitView: some View {
        // Always show 3-column layout; dashboard appears in detail when no image selected
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } content: {
            ImageListView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        } detail: {
            detailColumn
        }
    }
    
    @ViewBuilder
    private var detailColumn: some View {
        HStack(spacing: 0) {
            NavigationStack(path: $appState.navigationPath) {
                if let image = appState.selectedImage {
                    ImageDetailView(image: image)
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            navigationDestinationView(for: destination)
                        }
                } else {
                    WelcomeView()
                }
            }
            
            if showAIAssistant {
                Divider()
                AIAssistantView()
                    .environmentObject(appState)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showAIAssistant)
    }
    
    @ViewBuilder
    private func navigationDestinationView(for destination: NavigationDestination) -> some View {
        Group {
            switch destination {
            case .imageDetail(let image):
                ImageDetailView(image: image)
                
            case .bankBrowser(let image, let fileSystem):
                BankBrowserView(image: image, preloadedFileSystem: fileSystem)
                
            case .importBanks(let image):
                ImportBanksView(image: image)
                
            case .convertSamples(let image):
                ConvertSamplesView(targetImage: image)
                
            case .hexViewer(let image):
                HexViewerView(image: image)
                
            case .batchRename:
                BatchRenameView()
                
            case .sampleEditor(let sample, let bankName):
                WaveformEditorView(
                    pcmData: sample.pcmData,
                    sampleRate: Double(sample.sampleRate),
                    sampleName: sample.name
                ) { editedPCM in
                    guard let imageURL = appState.selectedImage?.url else { return }
                    let sampleIndex = sample.index
                    let sampleName  = sample.name
                    Task {
                        do {
                            let fs = try await EmaxIIParser.parseHDImageAsync(at: imageURL)
                            guard let bank = fs.userBanks.first(where: { $0.name == bankName }) else {
                                await MainActor.run {
                                    appState.addActivity("Bank '\(bankName)' not found on disk", type: .error)
                                }
                                return
                            }
                            _ = try PCMReallocator.replaceSamplePCM(
                                bankEntry: bank,
                                sampleIndex: sampleIndex,
                                newPCM: editedPCM,
                                imageURL: imageURL
                            )
                            await MainActor.run {
                                appState.addActivity("Sample '\(sampleName)' saved to \(bankName) ✓", type: .success)
                            }
                        } catch {
                            await MainActor.run {
                                appState.addActivity("Save failed: \(error.localizedDescription)", type: .error)
                            }
                        }
                    }
                }

            case .presetEditor(let params, let presetName):
                PresetEditorView(params: params, presetName: presetName) { editedParams in
                    // presetName is the bank name; preset index defaults to 0
                    // (mirrors BankBrowserView which initialises currentPresetIndex = 0).
                    guard let imageURL = appState.selectedImage?.url else { return }
                    Task {
                        do {
                            let fs = try await EmaxIIParser.parseHDImageAsync(at: imageURL)
                            guard let bank = fs.userBanks.first(where: { $0.name == presetName }) else {
                                await MainActor.run {
                                    appState.addActivity("Bank '\(presetName)' not found on disk", type: .error)
                                }
                                return
                            }
                            let update = PresetWriteService.PresetUpdate(
                                name: nil,
                                voiceRecords: [editedParams.toData()],
                                keyMap: nil
                            )
                            try PresetWriteService.updatePreset(
                                at: 0, update: update, in: bank, imageURL: imageURL
                            )
                            await MainActor.run {
                                appState.addActivity("Preset saved to \(presetName) ✓", type: .success)
                            }
                        } catch {
                            await MainActor.run {
                                appState.addActivity("Save failed: \(error.localizedDescription)", type: .error)
                            }
                        }
                    }
                }
                
            case .slotManager:
                if let volume = appState.selectedVolume {
                    SlotManagerView(volumeURL: volume.url, volumeName: volume.name)
                }
            }
        }
        .toolbar {
            // Back button (optional - breadcrumbs handle this)
            ToolbarItem(placement: .navigation) {
                Button {
                    appState.navigationPath.removeLast()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .disabled(appState.navigationPath.isEmpty)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // 5 primary actions with labels
        ToolbarItemGroup(placement: .primaryAction) {
            DevicePicker()
            
            // Undo/Redo buttons
            if appState.selectedVolume != nil {
                Button(action: { appState.undo() }) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .help("Undo (⌘Z)")
                .keyboardShortcut("z")
                .disabled(!appState.canUndo)
                
                Button(action: { appState.redo() }) {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                }
                .help("Redo (⌘⇧Z)")
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!appState.canRedo)
                
                Divider()
            }
            
            if appState.selectedVolume != nil {
                Button(action: { closeVolume() }) {
                    Label("Home", systemImage: "house")
                }
                .help("Back to Welcome (⌘W)")
                .keyboardShortcut("w")
                
                Button(action: { appState.refreshImages() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh (⌘R)")
                .keyboardShortcut("r")
                
                if appState.selectedVolume?.isRemovable == true {
                    Button(action: { appState.ejectVolume() }) {
                        Label("Eject", systemImage: "eject.fill")
                    }
                    .help("Eject Volume (⌘E)")
                }
            } else {
                Button(action: { openLocalFolder() }) {
                    Label("Open Folder", systemImage: "folder")
                }
                .help("Open Folder (⌘O)")
            }
        }
        
        // AI Assistant toggle
        ToolbarItem(placement: .primaryAction) {
            Button(action: { withAnimation { showAIAssistant.toggle() } }) {
                Label("AI Assistant", systemImage: "sparkles")
            }
            .help("Toggle AI Assistant (⌘/)")
            .keyboardShortcut("/", modifiers: .command)
            .foregroundStyle(showAIAssistant ? Theme.accent : .secondary)
        }
        
        // Overflow: all tools (accessible via ›› or Tools menu)
        ToolbarItemGroup(placement: .secondaryAction) {
            Button(action: { showBootableWizard = true }) {
                Label("Create Bootable Disk", systemImage: "wand.and.stars")
            }
            .help("Create bootable HD image (⌘⇧B)")
            
            Button(action: { showCreateFloppy = true }) {
                Label("Create Floppy", systemImage: "opticaldiscdrive")
            }
            .help("Create floppy .HFE image (⌘⇧F)")
            
            Divider()
            
            Button(action: { showFormatDisk = true }) {
                Label("Format Disk Image", systemImage: "internaldrive.trianglebadge.exclamationmark")
            }
            .disabled(appState.selectedImage == nil)
            
            Button(action: { showFormatVolume = true }) {
                Label("Format SD/USB", systemImage: "sdcard.fill")
            }
            .disabled(appState.selectedVolume == nil)
            
            Divider()
            
            Button(action: { showBatchRename = true }) {
                Label("Batch Rename", systemImage: "pencil.and.list.clipboard")
            }
            .disabled(appState.images.isEmpty)
            
            Button(action: { showSlotManager = true }) {
                Label("Multi-Image Slots", systemImage: "square.stack.3d.up")
            }
            .disabled(appState.images.isEmpty)
            
            Button(action: { showBackupRestore = true }) {
                Label("Backup & Restore", systemImage: "externaldrive.badge.timemachine")
            }
            .disabled(appState.selectedVolume == nil)
            
            Divider()
            
            Button(action: { showZuluConfig = true }) {
                Label("ZuluSCSI Config", systemImage: "doc.text")
            }
            .disabled(appState.selectedVolume == nil)
            
            Button(action: { showKnowledgeBase = true }) {
                Label("Knowledge Base", systemImage: "book")
            }
            
            Divider()
            
            Button(action: {
                NotificationCenter.default.post(name: .showOnboardingTour, object: nil)
            }) {
                Label("Take Tour", systemImage: "play.circle.fill")
            }
        }
    }
    
    private var statusBar: some View {
        HStack(spacing: Theme.Spacing.md) {
            if appState.selectedVolume == nil {
                // Welcome mode: action pills
                ActionPill(icon: "wand.and.stars", title: "Create Boot Disk", color: Theme.accent) {
                    NotificationCenter.default.post(name: .bootableDiskWizard, object: nil)
                }
                ActionPill(icon: "opticaldiscdrive", title: "Create Floppy", color: .purple) {
                    showCreateFloppy = true
                }
                ActionPill(icon: "sdcard.fill", title: "Format SD/USB", color: .orange) {
                    NotificationCenter.default.post(name: .formatVolume, object: nil)
                }
                ActionPill(icon: "externaldrive.badge.timemachine", title: "Backup", color: .blue) {
                    NotificationCenter.default.post(name: .backupRestore, object: nil)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.accent.opacity(0.5))
                    Text("EMULOTION")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                // Volume mode: status info
                if appState.isProcessing {
                    // Progress indicator
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        HStack(spacing: Theme.Spacing.sm) {
                            ProgressView(value: appState.progress)
                                .frame(width: 200)
                                .progressViewStyle(.linear)
                            Text("\(Int(appState.progress * 100))%")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !appState.progressMessage.isEmpty {
                            Text(appState.progressMessage)
                                .font(Theme.Typography.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .transaction { transaction in
                        transaction.animation = .linear(duration: 0.1)
                    }
                } else if !appState.statusMessage.isEmpty {
                    HStack(spacing: Theme.Spacing.sm) {
                        statusIcon
                        Text(appState.statusMessage)
                            .font(Theme.Typography.body)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if !appState.images.isEmpty {
                    Text("\(appState.images.count) image\(appState.images.count == 1 ? "" : "s")")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Volume space with progress bar
            if let volume = appState.selectedVolume, volume.totalSize > 0 {
                Text("•")
                    .foregroundStyle(.tertiary)
                    .font(Theme.Typography.caption)
                
                let used = volume.totalSize - volume.freeSpace
                let usedFormatted = ByteCountFormatter.string(fromByteCount: used, countStyle: .file)
                let totalFormatted = ByteCountFormatter.string(fromByteCount: volume.totalSize, countStyle: .file)
                let usagePercent = Double(used) / Double(volume.totalSize)
                
                HStack(spacing: Theme.Spacing.xs) {
                    Text("\(usedFormatted) / \(totalFormatted)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                    
                    // Mini progress bar - cache calculation to prevent re-renders
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(0.2))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(usagePercent > 0.9 ? Color.red : Color.blue)
                                .frame(width: max(0, min(geo.size.width, geo.size.width * usagePercent)))
                        }
                    }
                    .frame(width: 60, height: 4)
                    .drawingGroup() // Optimize progress bar rendering
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))
        .drawingGroup() // Optimize status bar rendering
    }
    
    private var statusIcon: some View {
        Group {
            switch appState.statusType {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .error:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            case .warning:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            case .info:
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .font(.system(size: 14))
    }
}

struct DevicePicker: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Picker("Device", selection: $appState.currentDevice) {
            ForEach(DeviceType.allCases) { device in
                Text(device.displayName).tag(device)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 140)
        .onChange(of: appState.currentDevice) { _, _ in
            appState.refreshImages()
        }
    }
}

// MARK: - View Extensions

extension View {
    func formatSheets(
        showFormatDisk: Binding<Bool>,
        showFormatVolume: Binding<Bool>,
        showCreateFloppy: Binding<Bool>,
        appState: AppState
    ) -> some View {
        self
            .sheet(isPresented: showFormatDisk) {
                if let image = appState.selectedImage {
                    FormatDiskSheet(image: image)
                }
            }
            .sheet(isPresented: showFormatVolume) {
                if let volume = appState.selectedVolume {
                    FormatVolumeSheet(volume: volume)
                } else {
                    NoVolumeSelectedView(action: "format this volume")
                }
            }
            .sheet(isPresented: showCreateFloppy) {
                CreateFloppySheet()
            }
    }
    
    func appSheets(
        showBatchRename: Binding<Bool>,
        showBatchConvertor: Binding<Bool>,
        showZuluConfig: Binding<Bool>,
        showKnowledgeBase: Binding<Bool>,
        showBootableWizard: Binding<Bool>,
        showSlotManager: Binding<Bool>,
        showBackupRestore: Binding<Bool>,
        appState: AppState
    ) -> some View {
        self
            .sheet(isPresented: showBatchRename) { BatchRenameView() }
            .sheet(isPresented: showBatchConvertor) { BatchConvertorView() }
            .sheet(isPresented: showZuluConfig) { ZuluSCSIConfigView() }
            .sheet(isPresented: showKnowledgeBase) { KnowledgeBaseView() }
            .sheet(isPresented: showBootableWizard) { BootableDiskWizard() }
            .sheet(isPresented: showSlotManager) {
                if let volume = appState.selectedVolume {
                    SlotManagerView(volumeURL: volume.url, volumeName: volume.name)
                }
            }
            .sheet(isPresented: showBackupRestore) {
                if let volume = appState.selectedVolume {
                    BackupRestoreView(volumeURL: volume.url, volumeName: volume.name, images: appState.images)
                } else {
                    NoVolumeSelectedView(action: "backup or restore")
                }
            }
    }
    
    // MARK: - New Feature Sheets (v0.6)

    func newFeatureSheets(
        showFATAnalyzer: Binding<Bool>,
        showBatchImport: Binding<Bool>,
        showHFEConverter: Binding<Bool>,
        showTemplateCreator: Binding<Bool>,
        showCatalogRaw: Binding<Bool>,
        showTemplateBrowser: Binding<Bool>,
        showTerminal: Binding<Bool>,
        showImageScanner: Binding<Bool>,
        showZuluValidator: Binding<Bool>,
        appState: AppState
    ) -> some View {
        self
            .sheet(isPresented: showFATAnalyzer) { FATAnalyzerView() }
            .sheet(isPresented: showBatchImport) { BatchBankImportSheet().environmentObject(appState) }
            .sheet(isPresented: showHFEConverter) { HFEConverterSheet() }
            .sheet(isPresented: showTemplateCreator) { TemplateCreatorSheet().environmentObject(appState) }
            .sheet(isPresented: showCatalogRaw) { CatalogRawView().environmentObject(appState) }
            .sheet(isPresented: showTemplateBrowser) { TemplateBrowserView().environmentObject(appState) }
            .sheet(isPresented: showTerminal) { TerminalView() }
            .sheet(isPresented: showImageScanner) { ImageScannerView().environmentObject(appState) }
            .sheet(isPresented: showZuluValidator) { ZuluConfigValidatorSheet().environmentObject(appState) }
    }

    func newFeatureMenuHandlers(
        showFATAnalyzer: Binding<Bool>,
        showBatchImport: Binding<Bool>,
        showHFEConverter: Binding<Bool>,
        showTemplateCreator: Binding<Bool>,
        showCatalogRaw: Binding<Bool>,
        showTemplateBrowser: Binding<Bool>,
        showTerminal: Binding<Bool>,
        showImageScanner: Binding<Bool>,
        showZuluValidator: Binding<Bool>
    ) -> some View {
        self
            .onReceive(NotificationCenter.default.publisher(for: .analyzeFAT)) { _ in showFATAnalyzer.wrappedValue = true }
            .onReceive(NotificationCenter.default.publisher(for: .batchImportBanks)) { _ in showBatchImport.wrappedValue = true }
            .onReceive(NotificationCenter.default.publisher(for: .convertHFE)) { _ in showHFEConverter.wrappedValue = true }
            .onReceive(NotificationCenter.default.publisher(for: .createTemplate)) { _ in showTemplateCreator.wrappedValue = true }
            .onReceive(NotificationCenter.default.publisher(for: .listCatalog)) { _ in showCatalogRaw.wrappedValue = true }
            .onReceive(NotificationCenter.default.publisher(for: .browseTemplates)) { _ in showTemplateBrowser.wrappedValue = true }
            .onReceive(NotificationCenter.default.publisher(for: .showTerminal)) { _ in showTerminal.wrappedValue = true }
            .onReceive(NotificationCenter.default.publisher(for: .scanImages)) { _ in showImageScanner.wrappedValue = true }
            .onReceive(NotificationCenter.default.publisher(for: .validateZuluConfig)) { _ in showZuluValidator.wrappedValue = true }
    }

    func menuHandlers(
        appState: AppState,
        showKnowledgeBase: Binding<Bool>,
        showBootableWizard: Binding<Bool>,
        showBatchRename: Binding<Bool>,
        showBatchConvertor: Binding<Bool>,
        showSlotManager: Binding<Bool>,
        showBackupRestore: Binding<Bool>,
        showZuluConfig: Binding<Bool>,
        showFormatDisk: Binding<Bool>,
        showFormatVolume: Binding<Bool>,
        showCreateFloppy: Binding<Bool>,
        openLocalFolder: @escaping () -> Void
    ) -> some View {
        self
            .onReceive(NotificationCenter.default.publisher(for: .openFolder)) { _ in openLocalFolder() }
            .onReceive(NotificationCenter.default.publisher(for: .showKnowledgeBase)) { _ in showKnowledgeBase.wrappedValue = true }
            .onReceive(NotificationCenter.default.publisher(for: .ejectVolume)) { _ in appState.ejectVolume() }
            .onReceive(NotificationCenter.default.publisher(for: .bootableDiskWizard)) { _ in showBootableWizard.wrappedValue = true }
            .onReceive(NotificationCenter.default.publisher(for: .batchRename)) { _ in showBatchRename.wrappedValue = true }
            .onReceive(NotificationCenter.default.publisher(for: .batchConvertor)) { _ in showBatchConvertor.wrappedValue = true }
            .onReceive(NotificationCenter.default.publisher(for: .slotManager)) { _ in showSlotManager.wrappedValue = true }
            .onReceive(NotificationCenter.default.publisher(for: .backupRestore)) { _ in showBackupRestore.wrappedValue = true }
            .onReceive(NotificationCenter.default.publisher(for: .zuluConfig)) { _ in showZuluConfig.wrappedValue = true }
            .onReceive(NotificationCenter.default.publisher(for: .formatDisk)) { _ in showFormatDisk.wrappedValue = true }
            .onReceive(NotificationCenter.default.publisher(for: .formatVolume)) { _ in showFormatVolume.wrappedValue = true }
            .onReceive(NotificationCenter.default.publisher(for: .createFloppy)) { _ in showCreateFloppy.wrappedValue = true }
    }
}
