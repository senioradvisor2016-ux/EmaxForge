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
        let base = "EMULOTION"
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
        if appState.selectedVolume != nil {
            // 3-column: Sidebar + Image List + Detail
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
            } content: {
                ImageListView()
                    .navigationSplitViewColumnWidth(min: 220, ideal: 280)
            } detail: {
                detailColumn
            }
        } else {
            // 2-column: Sidebar + WelcomeView (full width)
            NavigationSplitView {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
            } detail: {
                WelcomeView()
            }
        }
    }
    
    @ViewBuilder
    private var detailColumn: some View {
        NavigationStack(path: $appState.navigationPath) {
            if let image = appState.selectedImage {
                ImageDetailView(image: image)
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        navigationDestinationView(for: destination)
                    }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 44))
                        .foregroundStyle(.tertiary)
                    Text("Select an image to view details")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Or drag .EB2 files onto an image to import banks")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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
                // TODO: Create dedicated HexViewerView
                ImageDetailView(image: image)
                
            case .batchRename:
                BatchRenameView()
                
            case .sampleEditor(let sample, let bankName):
                WaveformEditorView(
                    pcmData: sample.pcmData,
                    sampleRate: Double(sample.sampleRate),
                    sampleName: sample.name
                ) { _ in
                    // Save callback - TODO
                }
                
            case .presetEditor(let params, let presetName):
                PresetEditorView(params: params, presetName: presetName) { _ in
                    // Save callback - TODO
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
                
                Button(action: { 
                    NotificationCenter.default.post(name: .showOnboardingTour, object: nil)
                }) {
                    Label("Take Tour", systemImage: "play.circle.fill")
                }
                .help("Take Interactive Tour")
                
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
                
                Button(action: { 
                    // Trigger onboarding tour via notification
                    NotificationCenter.default.post(name: .showOnboardingTour, object: nil)
                }) {
                    Label("Take Tour", systemImage: "play.circle.fill")
                }
                .help("Take Interactive Tour")
            }
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
                }
            }
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
