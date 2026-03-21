import SwiftUI
import AppKit

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingCreateFloppySheet = false
    @State private var detectedVolumes: [MountedVolume] = []
    @State private var showWizard = true
    @State private var wizardStep = 0
    @State private var volumeImages: [String: [URL]] = [:]  // volumeName -> images
    @State private var showOnboardingTour = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("onboardingStep") private var currentOnboardingStep = 0
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Enhanced onboarding banner
                if showWizard {
                    enhancedWizardBanner
                }
                
                // Main content: Drive browser
                if detectedVolumes.isEmpty {
                    enhancedEmptyState
                } else {
                    driveBrowser
                }
            }
            .background(Theme.bgDeep)
            
            // Onboarding tour overlay
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
        .sheet(isPresented: $showingCreateFloppySheet) {
            CreateFloppySheet()
        }
        .onAppear {
            refreshVolumes()
            // Show wizard for new users (but allow it to be shown even if dismissed)
            let wizardDismissed = UserDefaults.standard.bool(forKey: "wizardDismissed")
            // Show wizard only for new users who haven't completed onboarding
            if !hasCompletedOnboarding && !wizardDismissed {
                showWizard = true
            }
            
            // Auto-start onboarding tour for first-time users
            if !hasCompletedOnboarding && !wizardDismissed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showOnboardingTour = true
                }
            }
        }
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            refreshVolumes()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showOnboardingTour)) { _ in
            currentOnboardingStep = 0
            showOnboardingTour = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showGettingStarted)) { _ in
            withAnimation(.spring(response: 0.3)) {
                showWizard = true
            }
        }
    }
    
    // MARK: - Enhanced Wizard Banner
    
    private var enhancedWizardBanner: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Logo/Icon
                ZStack {
                    Circle()
                        .fill(Theme.accentGradient)
                        .frame(width: 40, height: 40)
                    Image(systemName: "waveform.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to EmaxForge")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Get started in 4 simple steps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Progress indicator
                HStack(spacing: 12) {
                    ForEach(1...4, id: \.self) { step in
                        let isActive = step <= calculateProgress()
                        Circle()
                            .fill(isActive ? Theme.accent : Color.secondary.opacity(0.2))
                            .frame(width: 8, height: 8)
                            .animation(.spring(response: 0.3), value: isActive)
                    }
                }
                
                // Action buttons
                HStack(spacing: 8) {
                    Button {
                        showOnboardingTour = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.circle.fill")
                            Text("Take Tour")
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showWizard = false
                        }
                        UserDefaults.standard.set(true, forKey: "wizardDismissed")
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(Color.secondary.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss getting started guide")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.bgCard.opacity(0.8))
            
            // Steps progress bar
            HStack(spacing: 0) {
                ForEach(1...4, id: \.self) { step in
                    let isDone = step <= calculateProgress()
                    let stepInfo = onboardingSteps[step - 1]
                    
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(isDone ? Theme.accent : Color.secondary.opacity(0.2))
                                .frame(width: 24, height: 24)
                            if isDone {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: stepInfo.icon)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stepInfo.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(isDone ? Theme.textPrimary : .secondary)
                            Text(stepInfo.subtitle)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(isDone ? Theme.accent.opacity(0.1) : Color.clear)
                    
                    if step < 4 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 4)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Theme.bgSurface.opacity(0.5))
        }
    }
    
    private func calculateProgress() -> Int {
        var progress = 0
        if detectedVolumes.contains(where: \.isRemovable) { progress += 1 }
        // Add more progress checks as features are used
        return progress
    }
    
    private let onboardingSteps: [(title: String, subtitle: String, icon: String)] = [
        ("Insert SD Card", "Connect your ZuluSCSI", "sdcard.fill"),
        ("Create Boot Disk", "Set up HD1 with OS", "wand.and.stars"),
        ("Import Banks", "Add your sound banks", "square.and.arrow.down"),
        ("Eject & Play", "Ready to use!", "eject.fill")
    ]
    
    // MARK: - Enhanced Empty State (Workflow Cards)
    
    private var enhancedEmptyState: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Compact hero
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.accentGradient)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("EmaxForge")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("Disk image manager for E-mu samplers")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 24)
                
                // ── Workflow Cards ──
                VStack(spacing: 12) {
                    Text("Workflows")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        WorkflowCard(
                            icon: "wand.and.stars",
                            title: "ZuluSCSI Setup",
                            description: "Create boot disk + data disks for ZuluSCSI",
                            color: Theme.accent,
                            badge: "HD"
                        ) {
                            NotificationCenter.default.post(name: .bootableDiskWizard, object: nil)
                        }
                        
                        WorkflowCard(
                            icon: "opticaldiscdrive",
                            title: "Gotek Floppy",
                            description: "Create .HFE floppy images for Gotek drive",
                            color: .purple,
                            badge: "FD"
                        ) {
                            NotificationCenter.default.post(name: .createFloppy, object: nil)
                        }
                        
                        WorkflowCard(
                            icon: "square.and.arrow.down",
                            title: "Import Banks",
                            description: "Add .EB2 bank files to an existing disk image",
                            color: .mint,
                            badge: "EB2"
                        ) {
                            NotificationCenter.default.post(name: .importBanks, object: nil)
                        }
                        
                        WorkflowCard(
                            icon: "waveform.badge.plus",
                            title: "Convert Samples",
                            description: "Convert WAV/AIFF to EMAX II format",
                            color: .cyan,
                            badge: "WAV"
                        ) {
                            NotificationCenter.default.post(name: .convertSamples, object: nil)
                        }
                        
                        WorkflowCard(
                            icon: "doc.on.doc",
                            title: "Blank Image",
                            description: "Create empty HD image (any EMXP size)",
                            color: .blue,
                            badge: "NEW"
                        ) {
                            NotificationCenter.default.post(name: .newImage, object: nil)
                        }
                        
                        WorkflowCard(
                            icon: "folder.badge.plus",
                            title: "Open Folder",
                            description: "Browse disk images on your Mac",
                            color: .orange,
                            badge: nil
                        ) {
                            openLocalFolder()
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                // ── Connected Drives ──
                detectedDrivesSection
                    .padding(.horizontal, 24)
                
                // ── Keyboard shortcuts hint ──
                HStack(spacing: 16) {
                    shortcutHint("⌘K", "Command Palette")
                    shortcutHint("⌘⇧B", "Boot Disk")
                    shortcutHint("⌘⇧F", "Floppy")
                    shortcutHint("⌘O", "Open Folder")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var detectedDrivesSection: some View {
        if !detectedVolumes.isEmpty {
            VStack(spacing: 8) {
                Text("Detected Drives")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(detectedVolumes) { volume in
                    driveRow(volume)
                }
            }
        } else {
            HStack(spacing: 12) {
                Image(systemName: "sdcard.fill")
                    .font(.title2)
                    .foregroundStyle(.orange.opacity(0.6))
                VStack(alignment: .leading, spacing: 2) {
                    Text("No drives detected")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("Insert a ZuluSCSI SD card or connect a USB drive")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(16)
            .background(Color.orange.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        }
    }
    
    private func driveRow(_ volume: MountedVolume) -> some View {
        Button {
            appState.selectedVolume = volume
            appState.refreshImages()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: volume.isRemovable ? "sdcard.fill" : "externaldrive.fill")
                    .font(.title3)
                    .foregroundStyle(volume.isRemovable ? .orange : .blue)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(volume.name)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(volume.url.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if volume.isRemovable {
                    Text("SD/USB")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Theme.bgCard, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
    
    private func shortcutHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
    
    // MARK: - Drive Browser (full-width, Disk Utility style)
    
    private var driveBrowser: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(detectedVolumes) { volume in
                        driveSection(volume)
                    }
                    
                    // Open folder option at bottom
                    openFolderRow
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func driveSection(_ volume: MountedVolume) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drive header
            Button {
                appState.selectedVolume = volume
                appState.refreshImages()
            } label: {
                HStack(spacing: 12) {
                    // Drive icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(volume.isRemovable ? Color.orange.gradient : Color.blue.gradient)
                            .frame(width: 36, height: 36)
                        Image(systemName: volume.isRemovable ? "sdcard.fill" : "externaldrive.fill")
                            .font(.body)
                            .foregroundStyle(.white)
                    }
                    
                    // Drive info
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(volume.name)
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                            
                            if volume.isRemovable {
                                Text("REMOVABLE")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.orange.opacity(0.15), in: Capsule())
                            }
                        }
                        
                        HStack(spacing: 12) {
                            // Usage bar
                            HStack(spacing: 6) {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.secondary.opacity(0.2))
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Theme.accent.gradient)
                                            .frame(width: geo.size.width * volume.usagePercent)
                                    }
                                }
                                .frame(width: 80, height: 4)
                                
                                Text(volume.formattedFree + " free of " + ByteCountFormatter.string(fromByteCount: volume.totalSize, countStyle: .file))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.001)) // hit target
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Image files on this drive
            let images = volumeImages[volume.name] ?? []
            if !images.isEmpty {
                // File list (Finder-style)
                VStack(spacing: 0) {
                    // Column headers
                    HStack(spacing: 0) {
                        Text("Name")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("SCSI ID")
                            .frame(width: 70)
                        Text("Size")
                            .frame(width: 90, alignment: .trailing)
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 20)
                    .padding(.leading, 48)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.02))
                    
                    ForEach(images, id: \.lastPathComponent) { url in
                        fileRow(url, volume: volume)
                    }
                    
                    // Boot check
                    let hasHD1 = images.contains { $0.lastPathComponent.lowercased().hasPrefix("hd1") }
                    if !hasHD1 {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text("No HD1 found — EMAX II won't boot from this drive")
                                .font(.caption2)
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 20)
                        .padding(.leading, 48)
                        .padding(.vertical, 6)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("No disk images")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 20)
                .padding(.leading, 48)
                .padding(.vertical, 8)
            }
            
            Divider()
                .padding(.horizontal, 20)
        }
    }
    
    private func fileRow(_ url: URL, volume: MountedVolume) -> some View {
        Button {
            appState.selectedVolume = volume
            appState.refreshImages()
        } label: {
            HStack(spacing: 0) {
                // Filename with icon
                HStack(spacing: 8) {
                    let scsiID = parseScsiID(from: url.lastPathComponent)
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(scsiID != nil ? Color.orange.gradient : Color.gray.gradient)
                            .frame(width: 22, height: 22)
                        if let id = scsiID {
                            Text("\(id)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                    
                    Text(url.lastPathComponent)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // SCSI ID
                let scsiID = parseScsiID(from: url.lastPathComponent)
                Text(scsiID != nil ? "ID \(scsiID!)" : "—")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(scsiID != nil ? Color.orange : Color.gray)
                    .frame(width: 70)
                
                // Size
                let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
                Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.leading, 48)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.001))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var openFolderRow: some View {
        Button(action: openLocalFolder) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "folder.badge.plus")
                        .font(.body)
                        .foregroundStyle(.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open Local Folder")
                        .font(.callout.bold())
                        .foregroundStyle(Theme.textPrimary)
                    Text("Browse disk images on your Mac")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Action Bar (bottom)
    
    private var actionBar: some View {
        HStack(spacing: 10) {
            ActionPill(icon: "wand.and.stars", title: "Create Boot Disk", color: Theme.accent) {
                NotificationCenter.default.post(name: .bootableDiskWizard, object: nil)
            }
            ActionPill(icon: "opticaldiscdrive", title: "Create Floppy", color: .purple) {
                showingCreateFloppySheet = true
            }
            ActionPill(icon: "sdcard.fill", title: "Format SD/USB", color: .orange) {
                NotificationCenter.default.post(name: .formatVolume, object: nil)
            }
            ActionPill(icon: "externaldrive.badge.timemachine", title: "Backup", color: .blue) {
                NotificationCenter.default.post(name: .backupRestore, object: nil)
            }
            
            Spacer()
            
            // Small branding
            HStack(spacing: 6) {
                Image(systemName: "waveform.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.accent.opacity(0.5))
                Text("EMULOTION")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
    
    // MARK: - Helpers
    
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
    
    private func refreshVolumes() {
        detectedVolumes = MountedVolume.scanMounted()
        // Scan images on each volume
        for vol in detectedVolumes {
            volumeImages[vol.name] = scanImagesOnVolume(vol)
        }
    }
    
    private func scanImagesOnVolume(_ volume: MountedVolume) -> [URL] {
        let fm = FileManager.default
        let extensions = ["hda", "ez2", "eb2"]
        guard let contents = try? fm.contentsOfDirectory(at: volume.url, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles) else {
            return []
        }
        return contents
            .filter { extensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCompare($1.lastPathComponent) == .orderedAscending }
    }
    
    private func parseScsiID(from filename: String) -> Int? {
        let lower = filename.lowercased()
        guard lower.hasPrefix("hd") else { return nil }
        let rest = lower.dropFirst(2)
        if let firstChar = rest.first, let digit = Int(String(firstChar)), digit >= 0 && digit <= 7 {
            return digit
        }
        return nil
    }
}

// MARK: - Wizard Chip (inline step indicator)

struct WizardChip: View {
    let step: Int
    let label: String
    let icon: String
    let isDone: Bool
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isDone ? .green : color.opacity(0.15))
                    .frame(width: 20, height: 20)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(step)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }
            }
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isDone ? .secondary : Theme.textPrimary)
        }
    }
}

// MARK: - Action Pill

struct ActionPill: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(isHovering ? 0.15 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(color.opacity(isHovering ? 0.3 : 0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Legacy (kept for other views)

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .buttonStyle(.plain)
    }
}

struct GettingStartedCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let shortcut: String?
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            VStack(alignment: .leading) {
                Text(title).fontWeight(.semibold)
                if let subtitle = subtitle as String? {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let shortcut {
                Text(shortcut).font(.caption.monospaced()).foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Theme.bgCard, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Quick Start Card

struct QuickStartCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(isHovering ? 0.25 : 0.15))
                        .frame(height: 60)
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.bgCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(isHovering ? 0.3 : 0.1), lineWidth: 1)
                    )
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Workflow Card (compact, badge-labeled)

struct WorkflowCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let badge: String?
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                        .frame(width: 32, height: 32)
                        .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                    
                    Spacer()
                    
                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.bgCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(isHovering ? 0.4 : 0.1), lineWidth: 1)
                    )
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Tip Card

struct TipCard: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.yellow)
                .frame(width: 24)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.bgCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Onboarding Tour Overlay

struct OnboardingTourOverlay: View {
    @Binding var currentStep: Int
    @Binding var isPresented: Bool
    let onComplete: () -> Void
    
    private let steps: [OnboardingStep] = [
        OnboardingStep(
            title: "Welcome to EmaxForge",
            description: "Manage your EMAX II disk images with ease. Let's get you started!",
            icon: "waveform.circle.fill",
            highlight: nil
        ),
        OnboardingStep(
            title: "Open a Volume",
            description: "Click 'Open Folder' to browse local disk images, or insert an SD card.",
            icon: "folder.badge.plus",
            highlight: .button("Open Folder")
        ),
        OnboardingStep(
            title: "Create Boot Disk",
            description: "Use the Bootable Disk Wizard to set up HD1 with EMAX II OS.",
            icon: "wand.and.stars",
            highlight: .button("Create Boot Disk")
        ),
        OnboardingStep(
            title: "Import Banks",
            description: "Drag .EB2 files onto disk images, or use the Import Banks feature.",
            icon: "square.and.arrow.down",
            highlight: .button("Import Banks")
        ),
        OnboardingStep(
            title: "You're All Set!",
            description: "Explore the app and use ⌘K for quick actions. Happy sampling!",
            icon: "checkmark.circle.fill",
            highlight: nil
        )
    ]
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    // Don't dismiss on background tap
                }
            
            // Content
            VStack(spacing: 0) {
                Spacer()
                
                if currentStep < steps.count {
                    let step = steps[currentStep]
                    
                    VStack(spacing: 20) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Theme.accentGradient.opacity(0.2))
                                .frame(width: 80, height: 80)
                            Image(systemName: step.icon)
                                .font(.system(size: 36))
                                .foregroundStyle(Theme.accentGradient)
                        }
                        
                        // Text
                        VStack(spacing: 8) {
                            Text(step.title)
                                .font(.title2.bold())
                                .foregroundStyle(Theme.textPrimary)
                            
                            Text(step.description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        
                        // Progress dots
                        HStack(spacing: 8) {
                            ForEach(0..<steps.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentStep ? Theme.accent : Color.secondary.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                    .animation(.spring(response: 0.3), value: currentStep)
                            }
                        }
                        
                        // Buttons
                        HStack(spacing: 12) {
                            if currentStep > 0 {
                                Button("Back") {
                                    withAnimation {
                                        currentStep -= 1
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            Spacer()
                            
                            Button(currentStep == steps.count - 1 ? "Get Started" : "Next") {
                                if currentStep == steps.count - 1 {
                                    onComplete()
                                } else {
                                    withAnimation {
                                        currentStep += 1
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                            
                            Button("Skip") {
                                onComplete()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(32)
                    .frame(width: 500)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Theme.bgCard)
                            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                    )
                }
                
                Spacer()
            }
            .padding(40)
        }
    }
}

struct OnboardingStep {
    let title: String
    let description: String
    let icon: String
    let highlight: Highlight?
    
    enum Highlight {
        case button(String)
        case view(String)
    }
}
