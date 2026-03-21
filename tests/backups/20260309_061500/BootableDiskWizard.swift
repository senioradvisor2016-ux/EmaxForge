import SwiftUI
import UniformTypeIdentifiers

/// Step-by-step wizard for creating a bootable EMAX II SCSI disk image
/// ready for use with ZuluSCSI Pico
struct BootableDiskWizard: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Wizard State
    
    @State private var currentStep: WizardStep = .destination
    @State private var isCreating = false
    @State private var creationProgress: Double = 0
    @State private var errorMessage: String?
    
    // Step 1: Destination
    @State private var destinationURL: URL?
    @State private var destinationLabel: String = ""
    @State private var detectedSD = false
    
    // Step 2: Disk Size & SCSI
    @State private var sizeMB: Int = 239  // ZIP 250 (default)
    @State private var scsiID: Int = 1  // EMAX II boots from SCSI ID 1
    @State private var imageIndex: Int = 0
    @State private var useImageIndex = false
    @State private var imageCount: Int = 1  // Multi-image support
    
    // Step 3: OS
    @State private var includeOS = true
    @State private var osFileURL: URL?
    @State private var osDetected = false
    
    // Auto-enable multi-disk when OS is selected
    private var autoMultiDisk: Bool {
        includeOS && (osFileURL != nil || osDetected)
    }
    
    // Step 4: Banks
    @State private var bankFiles: [URL] = []
    
    // Step 5: ZuluSCSI Config
    @State private var generateConfig = true
    
    // Result
    @State private var createdImageURL: URL?
    @State private var importedBankCount = 0
    
    enum WizardStep: Int, CaseIterable {
        case destination = 0
        case diskSetup = 1
        case operatingSystem = 2
        case banks = 3
        case review = 4
        case creating = 5
        case done = 6
        
        var title: String {
            switch self {
            case .destination: return "Destination"
            case .diskSetup: return "Disk Setup"
            case .operatingSystem: return "Operating System"
            case .banks: return "Banks"
            case .review: return "Review"
            case .creating: return "Creating…"
            case .done: return "Done!"
            }
        }
        
        var icon: String {
            switch self {
            case .destination: return "sdcard"
            case .diskSetup: return "internaldrive"
            case .operatingSystem: return "cpu"
            case .banks: return "music.note.list"
            case .review: return "checklist"
            case .creating: return "gearshape.2"
            case .done: return "checkmark.seal.fill"
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Progress stepper
            if currentStep.rawValue < WizardStep.creating.rawValue {
                stepIndicator
                    .padding(.vertical, 12)
                Divider()
            }
            
            // Content area
            ScrollView {
                Group {
                    switch currentStep {
                    case .destination: destinationStep
                    case .diskSetup: diskSetupStep
                    case .operatingSystem: osStep
                    case .banks: banksStep
                    case .review: reviewStep
                    case .creating: creatingStep
                    case .done: doneStep
                    }
                }
                .padding(24)
            }
            
            Divider()
            
            // Navigation buttons
            navigationBar
        }
        .frame(minWidth: 700, idealWidth: 750, minHeight: 640, idealHeight: 680)
        .onAppear { detectEnvironment() }
        .onExitCommand { dismiss() }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.title2)
                .foregroundStyle(Theme.accent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Create Bootable Disk")
                    .font(.headline)
                Text("Step-by-step wizard for ZuluSCSI")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    // MARK: - Step Indicator
    
    private var stepIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { i in
                let step = WizardStep(rawValue: i)!
                let isCurrent = currentStep.rawValue == i
                let isDone = currentStep.rawValue > i
                
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(isDone ? Theme.success : (isCurrent ? Theme.accent : Color.gray.opacity(0.3)))
                            .frame(width: 24, height: 24)
                        
                        if isDone {
                            Image(systemName: "checkmark")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                        } else {
                            Text("\(i + 1)")
                                .font(.caption2.bold())
                                .foregroundStyle(isCurrent ? .white : .secondary)
                        }
                    }
                    
                    if isCurrent {
                        Text(step.title)
                            .font(.caption.bold())
                            .foregroundStyle(Theme.accent)
                    }
                }
                
                if i < 4 {
                    Rectangle()
                        .fill(isDone ? Theme.success.opacity(0.5) : Color.gray.opacity(0.2))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Step 1: Destination
    
    private var destinationStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepTitle("Where should the image be saved?", subtitle: "Pick your ZuluSCSI SD card or a local folder")
            
            // Auto-detected volumes
            if let volumes = detectRemovableVolumes(), !volumes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Detected SD Cards", systemImage: "sdcard")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    
                    ForEach(volumes, id: \.absoluteString) { vol in
                        let isSelected = destinationURL == vol
                        Button {
                            destinationURL = vol
                            destinationLabel = vol.lastPathComponent
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "sdcard.fill")
                                    .font(.title3)
                                    .foregroundStyle(isSelected ? Theme.accent : .secondary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(vol.lastPathComponent)
                                        .fontWeight(.medium)
                                    Text(vol.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            .padding(12)
                            .background(isSelected ? Theme.accent.opacity(0.1) : Color.clear,
                                       in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Theme.accent : Color.gray.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Manual selection
            HStack {
                Button("Choose Folder…") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.message = "Select destination for the disk image"
                    if panel.runModal() == .OK, let url = panel.url {
                        destinationURL = url
                        destinationLabel = url.lastPathComponent
                    }
                }
                .buttonStyle(.bordered)
                
                if let url = destinationURL {
                    Label(url.lastPathComponent, systemImage: "folder.fill")
                        .font(.callout)
                        .foregroundStyle(Theme.accent)
                }
            }
            
            // Hint
            infoBox(
                icon: "lightbulb.fill",
                text: "For ZuluSCSI: save directly to the root of your SD card. The image file will be automatically detected on boot."
            )
        }
    }
    
    // MARK: - Step 2: Disk Setup
    
    private var diskSetupStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepTitle("Configure the disk", subtitle: "Size and SCSI identity for your EMAX II")
            
            // Size
            VStack(alignment: .leading, spacing: 8) {
                Text("Image Size")
                    .font(.subheadline.bold())
                
                let sizes = [96, 239, 481, 633, 962]
                Picker("Size", selection: $sizeMB) {
                    ForEach(sizes, id: \.self) { s in
                        Text(sizeLabel(for: s)).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                
                Text(sizeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // SCSI ID
            VStack(alignment: .leading, spacing: 8) {
                Text("SCSI ID")
                    .font(.subheadline.bold())
                
                Picker("ID", selection: $scsiID) {
                    ForEach(0...6, id: \.self) { id in
                        HStack {
                            Text("ID \(id)")
                            if id == 1 { Text("(boot drive)").foregroundStyle(.secondary) }
                        }.tag(id)
                    }
                }
                .pickerStyle(.radioGroup)
                
                if scsiID == 1 {
                    infoBox(
                        icon: "cpu",
                        text: "EMAX II always boots from SCSI ID 1. This disk must contain the OS to be bootable."
                    )
                } else {
                    infoBox(
                        icon: "info.circle",
                        text: "EMAX II boots from SCSI ID 1. ID \(scsiID) will be a secondary data drive — it cannot boot the sampler."
                    )
                }
            }
            
            Divider()
            
            // Multi-image
            Toggle("Enable multi-image slot", isOn: $useImageIndex)
                .help("Auto-enabled when OS is selected (HD1 = boot, HD2+ = samples)")
            
            if useImageIndex {
                Stepper("Starting index: \(imageIndex)", value: $imageIndex, in: 0...99)
                    .frame(width: 220)
                
                Stepper("Create \(imageCount) disk(s)", value: $imageCount, in: 1...10)
                    .frame(width: 200)
                
                if imageCount > 1 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Multi-disk setup (HD1, HD2, HD3...)")
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                        Text("• HD1 = Boot disk (OS + samples)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("• HD2-HD\(imageCount) = Overflow (if HD1 is full)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("ZuluSCSI can hold multiple images per SCSI ID. Switch with buttons on the Pico.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Step 3: Operating System
    
    private var osStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepTitle("EMAX II Operating System", subtitle: "A bootable disk needs the OS installed")
            
            Toggle("Install OS (makes disk bootable)", isOn: $includeOS)
                .toggleStyle(.switch)
                .onChange(of: includeOS) { _, newValue in
                    if newValue && osFileURL != nil {
                        // Auto-enable multi-disk for boot setup
                        useImageIndex = true
                        if imageCount < 2 {
                            imageCount = 2  // HD1 (boot) + HD2 (samples)
                        }
                    }
                }
            
            if scsiID == 1 && !includeOS {
                infoBox(
                    icon: "exclamationmark.triangle.fill",
                    text: "⚠️ SCSI ID 1 without OS — the EMAX II will not boot! The sampler always loads its OS from HD1 at startup."
                )
            }
            
            if includeOS {
                if osFileURL != nil || osDetected {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Theme.success)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("OS Ready")
                                .fontWeight(.medium)
                            if let osURL = osFileURL {
                                Text(osURL.lastPathComponent)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Bundled OS (EMAX II v2.14)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Theme.success.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.title3)
                            
                            Text("No OS file found automatically")
                                .fontWeight(.medium)
                        }
                        
                        Button("Locate OS File (.EMX)…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = true
                            panel.allowedContentTypes = [UTType(filenameExtension: "EMX")].compactMap { $0 }
                            panel.message = "Select EMAX II OS file"
                            if panel.runModal() == .OK {
                                osFileURL = panel.url
                                // Auto-enable multi-disk when OS is selected
                                if includeOS {
                                    useImageIndex = true
                                    if imageCount < 2 {
                                        imageCount = 2
                                    }
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                    }
                    .padding(12)
                    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
                
                VStack(spacing: 12) {
                    infoBox(
                        icon: "cpu",
                        text: "The OS is loaded into RAM when the EMAX II boots. Recommended: v2.14 (latest). OS file is typically ~16-32KB."
                    )
                    
                    if osFileURL != nil || osDetected {
                        infoBox(
                            icon: "internaldrive",
                            text: "📀 Boot disk setup: HD1 will contain OS + sample banks. Additional disks (HD2, HD3) will hold overflow samples if needed."
                        )
                        .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            } else {
                infoBox(
                    icon: "exclamationmark.triangle",
                    text: "Without OS, this disk can only be used as a secondary data drive. The EMAX II won't boot from it."
                )
            }
        }
    }
    
    // MARK: - Step 4: Banks
    
    private var banksStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepTitle("Pre-load Banks (Optional)", subtitle: "Add sample banks to the new disk")
            
            // Warning: Can't add samples to boot-only disk
            if includeOS && (osFileURL != nil || osDetected) && (!useImageIndex || imageCount < 2) {
                infoBox(
                    icon: "exclamationmark.triangle.fill",
                    text: "⚠️ HD1 is boot-only (OS disk). Sample banks require HD2+. Multi-disk setup was auto-enabled in Disk Setup step."
                )
                .background(Theme.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            
            // Success message: Banks will go to HD2+
            if useImageIndex && imageCount >= 2 && includeOS {
                infoBox(
                    icon: "checkmark.circle.fill",
                    text: "✅ Sample banks will be imported to HD2, HD3, etc. (HD1 = boot only)"
                )
                .background(Theme.success.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
            
            if bankFiles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.5))
                    
                    Text("No banks selected")
                        .foregroundStyle(.secondary)
                    
                    Text("You can always import banks later from the main window.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 4) {
                    ForEach(bankFiles, id: \.absoluteString) { url in
                        HStack(spacing: 8) {
                            Image(systemName: "music.note")
                                .foregroundStyle(Theme.accent)
                            
                            Text(url.deletingPathExtension().lastPathComponent)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Button {
                                bankFiles.removeAll { $0 == url }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            HStack {
                Button("Add Banks…") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.allowsMultipleSelection = true
                    panel.allowedContentTypes = FormatConverter.emuExtensions.compactMap { UTType(filenameExtension: $0) }
                    panel.message = "Select bank files to pre-load"
                    if panel.runModal() == .OK {
                        for url in panel.urls where !bankFiles.contains(url) {
                            bankFiles.append(url)
                        }
                    }
                }
                .buttonStyle(.bordered)
                
                if !bankFiles.isEmpty {
                    Button("Clear All") { bankFiles.removeAll() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Step 5: Review
    
    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepTitle("Review & Create", subtitle: "Check everything before creating the disk")
            
            // Summary cards
            VStack(spacing: 12) {
                reviewRow(icon: "sdcard", label: "Destination", value: destinationURL?.lastPathComponent ?? "—")
                reviewRow(icon: "internaldrive", label: "Filename", value: previewFilename)
                reviewRow(icon: "arrow.left.arrow.right", label: "Size", value: sizeMB >= 1000 ? "\(sizeMB / 1000) GB" : "\(sizeMB) MB")
                
                if useImageIndex && imageCount > 1 {
                    reviewRow(icon: "square.stack", label: "Disks", value: "\(imageCount) images (HD1-HD\(imageCount))")
                    reviewRow(icon: "number", label: "Boot Disk", value: "HD1 (OS + \(bankFiles.count) banks)")
                    reviewRow(icon: "music.note.list", label: "Overflow Disks", value: "HD2-HD\(imageCount) (if needed)")
                } else {
                    reviewRow(icon: "number", label: "SCSI ID", value: "ID \(scsiID)")
                    reviewRow(icon: "cpu", label: "OS", value: includeOS && (osFileURL != nil || osDetected) ? "✅ Bootable" : "❌ Not bootable")
                    reviewRow(icon: "music.note.list", label: "Banks", value: bankFiles.isEmpty ? "None" : "\(bankFiles.count) bank(s)")
                }
                reviewRow(icon: "gearshape", label: "ZuluSCSI Config", value: generateConfig ? "Auto-generate" : "Skip")
            }
            .padding(16)
            .background(Theme.bgCard.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            
            Toggle("Generate zuluscsi.ini", isOn: $generateConfig)
                .font(.callout)
            
            if includeOS && (osFileURL != nil || osDetected) && !bankFiles.isEmpty {
                infoBox(
                    icon: "bolt.fill",
                    text: "Ready to go! This disk will boot your EMAX II and have \(bankFiles.count) bank(s) pre-loaded."
                )
            }
        }
    }
    
    // MARK: - Creating Step
    
    private var creatingStep: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView(value: creationProgress)
                .progressViewStyle(.linear)
                .frame(width: 300)
            
            Text(creationStatusText)
                .font(.callout)
                .foregroundStyle(.secondary)
            
            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.danger)
                    .padding()
                    .background(Theme.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            
            Spacer()
        }
    }
    
    // MARK: - Done Step
    
    private var doneStep: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.success)
            
            Text(imageCount > 1 ? "\(imageCount) Disks Created!" : "Disk Created!")
                .font(.title.bold())
            
            if let url = createdImageURL {
                if imageCount > 1 {
                    VStack(spacing: 6) {
                        Text("HD1 = Boot disk (OS)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("HD2-HD\(imageCount) = Sample banks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(url.lastPathComponent)
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                }
            }
            
            VStack(spacing: 6) {
                if includeOS { Label("Bootable with EMAX II OS", systemImage: "checkmark") }
                if importedBankCount > 0 { Label("\(importedBankCount) banks loaded", systemImage: "checkmark") }
                if generateConfig { Label("ZuluSCSI config generated", systemImage: "checkmark") }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            
            Divider().padding(.vertical, 8)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Next Steps:")
                    .font(.subheadline.bold())
                
                HStack(alignment: .top, spacing: 8) {
                    Text("1.")
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.accent)
                    Text("Eject the SD card safely")
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("2.")
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.accent)
                    Text("Insert into your ZuluSCSI Pico")
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("3.")
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.accent)
                    Text("Power on EMAX II — it should boot from the new disk")
                }
            }
            .font(.callout)
            .padding(16)
            .background(Theme.bgCard.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            
            Spacer()
        }
    }
    
    // MARK: - Navigation Bar
    
    private var navigationBar: some View {
        HStack {
            if currentStep.rawValue > 0 && currentStep != .creating && currentStep != .done {
                Button("Back") {
                    withAnimation { currentStep = WizardStep(rawValue: currentStep.rawValue - 1)! }
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            
            Spacer()
            
            if currentStep == .done {
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            } else if currentStep == .review {
                Button("Create Disk") { startCreation() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            } else if currentStep != .creating {
                Button(currentStep == .banks ? "Skip & Review" : "Next") {
                    withAnimation { advanceStep() }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!canAdvance)
            }
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private var canAdvance: Bool {
        switch currentStep {
        case .destination: return destinationURL != nil
        case .diskSetup: return true
        case .operatingSystem: return true
        case .banks: return true
        case .review: return true
        default: return false
        }
    }
    
    private func advanceStep() {
        guard let next = WizardStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }
    
    private var sizeDescription: String {
        let approxBanks = sizeMB / 2  // Rough: 1-2MB per bank
        return "~\(approxBanks) banks capacity. ZuluSCSI supports up to 4 GB per image."
    }
    
    private func sizeLabel(for mb: Int) -> String {
        if mb >= 1000 {
            return "\(mb / 1000) GB"
        } else {
            return "\(mb) MB"
        }
    }
    
    private var previewFilename: String {
        // ZuluSCSI format: HDxy where x=SCSI ID, y=unit (0-7)
        var name = "HD\(scsiID)0"  // e.g. HD00, HD10, HD20
        if useImageIndex { name += "_\(imageIndex)" }
        name += ".hda"
        return name
    }
    
    private var previewMultiImageFilenames: String {
        guard useImageIndex && imageCount > 1 else { return previewFilename }
        let names = (0..<imageCount).map { i in
            "HD\(scsiID)0_\(imageIndex + i).hda"  // ZuluSCSI double-digit format
        }
        return names.joined(separator: ", ")
    }
    
    private var creationStatusText: String {
        if creationProgress < 0.2 { return "Creating disk image…" }
        if creationProgress < 0.4 { return "Writing filesystem…" }
        if creationProgress < 0.6 { return "Installing OS…" }
        if creationProgress < 0.8 { return "Importing banks…" }
        return "Generating config…"
    }
    
    private func stepTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title3.bold())
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }
    
    private func infoBox(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Theme.accent.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private func reviewRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(Theme.accent)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Environment Detection
    
    private func detectEnvironment() {
        // OS is bundled as emax2_os.bin — no external file needed
        osFileURL = nil  // createBootableImage loads OS from bundle
        osDetected = true
        
        // Auto-enable multi-disk if OS found (HD1 = boot, HD2+ = samples)
        if includeOS && (osFileURL != nil || osDetected) {
            useImageIndex = true
            if imageCount < 2 {
                imageCount = 2
            }
        }
        
        // Auto-select first removable volume if available
        if let volumes = detectRemovableVolumes(), let first = volumes.first {
            destinationURL = first
            destinationLabel = first.lastPathComponent
            detectedSD = true
        }
    }
    
    private func detectRemovableVolumes() -> [URL]? {
        let fm = FileManager.default
        let volumeKeys: [URLResourceKey] = [.volumeIsRemovableKey, .volumeNameKey, .volumeAvailableCapacityKey]
        
        guard let mountedVolumes = fm.mountedVolumeURLs(includingResourceValuesForKeys: volumeKeys) else {
            return nil
        }
        
        return mountedVolumes.filter { url in
            guard let values = try? url.resourceValues(forKeys: Set(volumeKeys)) else { return false }
            // Check isRemovable via the volume key
            let isRemovable = (try? url.resourceValues(forKeys: [.volumeIsRemovableKey]).allValues[.volumeIsRemovableKey] as? Bool) ?? false
            return isRemovable && !url.path.hasPrefix("/System")
        }
    }
    
    // MARK: - Creation
    
    private func startCreation() {
        guard let destDir = destinationURL else { return }
        
        currentStep = .creating
        isCreating = true
        errorMessage = nil
        creationProgress = 0
        
        // Determine how many images to create
        let count = (useImageIndex && imageCount > 1) ? imageCount : 1
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var totalBankCount = 0
                var lastCreatedURL: URL?
                
                for i in 0..<count {
                    // Multi-image logic: HD1 = boot (SCSI 1), HD2+ = data (SCSI 2+)
                    let isBootDisk = (i == 0 && count > 1) || (count == 1 && scsiID == 1)
                    let currentScsiID = count > 1 ? (i + 1) : scsiID
                    let currentIndex = imageIndex + i
                    
                    let filename: String
                    if count == 1 {
                        filename = previewFilename
                    } else {
                        // Multi-image: HD10.hda, HD20.hda, HD30.hda, etc. (ZuluSCSI format)
                        filename = "HD\(currentScsiID)0.hda"
                    }
                    
                    let destURL = destDir.appendingPathComponent(filename)
                    lastCreatedURL = destURL
                    
                    let baseProgress = Double(i) / Double(count)
                    let stepProgress = 1.0 / Double(count)
                    
                    // Step 1: Create image
                    updateProgress(baseProgress + stepProgress * 0.1, "Creating \(filename)…")
                    
                    // HD1 gets OS (if includeOS), HD2+ are plain data disks
                    if i == 0 && includeOS && (osFileURL != nil || osDetected) {
                        // Boot disk with OS (HD10.hda) — osFileURL=nil uses bundled OS
                        try ImageCreator.createBootableImage(at: destURL, sizeMB: sizeMB, osFileURL: osFileURL)
                    } else {
                        // Data disk (no OS) - HD20, HD30, etc. are blank data disks for samples
                        try ImageCreator.createBlankImage(at: destURL, sizeMB: sizeMB)
                    }
                    
                    updateProgress(baseProgress + stepProgress * 0.5, "Image \(i+1)/\(count) created")
                    
                    // Step 2: Import banks (distribute across disks)
                    // CRITICAL (Mar 8, 2026): EMAX II requires samples on boot disk!
                    // Strategy: Round-robin distribution (bank 0→HD10, bank 1→HD20, bank 2→HD10, etc.)
                    // This ensures unique banks per disk and spreads load evenly
                    
                    if !bankFiles.isEmpty {
                        // Calculate which banks belong to this disk (round-robin)
                        let banksForThisDisk = bankFiles.enumerated().filter { (bi, _) in
                            count == 1 || (bi % count) == i  // Single disk gets all, multi-disk gets every Nth
                        }
                        
                        for (bi, bankURL) in banksForThisDisk {
                            let progress = baseProgress + stepProgress * (0.5 + 0.3 * Double(bi) / Double(bankFiles.count))
                            updateProgress(progress, "Importing \(bankURL.deletingPathExtension().lastPathComponent)…")
                            
                            let ext = bankURL.pathExtension.lowercased()
                            if ext == "eb2" {
                                let _ = try? BankImporter.importBank(eb2URL: bankURL, into: destURL, allowDuplicate: false)
                                totalBankCount += 1
                            } else if FormatConverter.emuExtensions.contains(ext) {
                                let (imported, _) = FormatConverter.convertAndImport(urls: [bankURL], into: destURL)
                                totalBankCount += imported.count
                            }
                        }
                    }
                }
                
                updateProgress(0.95, "Finalizing…")
                
                // Step 3: Generate ZuluSCSI config (always overwrite to ensure correct settings)
                if generateConfig {
                    let configService = ZuluSCSIConfigService()
                    
                    // Build list of all created images for config generation
                    var createdImages: [DiskImage] = []
                    for i in 0..<count {
                        let currentScsiID = count > 1 ? i : scsiID
                        let filename = count > 1 ? "HD\(currentScsiID)0.hda" : previewFilename  // ZuluSCSI format
                        let imageURL = destDir.appendingPathComponent(filename)
                        
                        // Create DiskImage object for config generation
                        if let image = try? DiskImage.parse(url: imageURL, device: appState.currentDevice) {
                            createdImages.append(image)
                        }
                    }
                    
                    // Generate proper config with all SCSI IDs
                    let configContent = configService.generateConfig(for: appState.currentDevice, images: createdImages)
                    let configURL = destDir.appendingPathComponent("zuluscsi.ini")
                    try configContent.write(to: configURL, atomically: true, encoding: .utf8)
                }
                
                updateProgress(1.0, "Done!")
                
                DispatchQueue.main.async {
                    createdImageURL = lastCreatedURL
                    importedBankCount = totalBankCount
                    isCreating = false
                    currentStep = .done
                    appState.refreshImages()
                }
                
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
    
    private func updateProgress(_ value: Double, _ status: String) {
        DispatchQueue.main.async {
            creationProgress = value
        }
    }
}
