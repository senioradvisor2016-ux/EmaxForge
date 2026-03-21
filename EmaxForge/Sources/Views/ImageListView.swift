import SwiftUI
import UniformTypeIdentifiers

struct ImageListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.toastManager) var toastManager
    @State private var showingNewImageSheet = false
    @State private var showingFormatSheet = false
    @State private var showingFormatVolumeSheet = false
    @State private var showingCreateFloppySheet = false
    @State private var imageToFormat: DiskImage?
    @State private var dragOver = false
    @State private var searchText = ""
    @FocusState private var searchFieldFocused: Bool
    @State private var selectedImages: Set<DiskImage.ID> = []
    @State private var showDeleteConfirmation = false
    @State private var imageToDelete: DiskImage?
    @State private var showingRenameSheet = false
    @State private var imageToRename: DiskImage?
    @State private var showingDuplicateSheet = false
    @State private var imageToDuplicate: DiskImage?
    
    var filteredImages: [DiskImage] {
        let images = appState.images
        if searchText.isEmpty { return images }
        
        // Enhanced search with lookup functions
        let query = searchText.lowercased()
        return images.filter { image in
            // Filename search
            image.filename.lowercased().contains(query) ||
            // Label search
            (image.label?.lowercased().contains(query) ?? false) ||
            // Extension search
            image.fileExtension.lowercased().contains(query) ||
            // SCSI ID search
            (image.scsiID != nil && "\(image.scsiID!)".contains(query)) ||
            // Size search (e.g., "100mb", "1gb")
            image.formattedSize.lowercased().contains(query)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Breadcrumb Navigation
            if let vol = appState.selectedVolume {
                BreadcrumbView(
                    volumeName: vol.name,
                    volumeIcon: vol.isRemovable ? "sdcard.fill" : "folder.fill",
                    selectedImage: appState.selectedImage,
                    onVolumeClick: {
                        appState.selectedImage = nil
                    }
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)
            }
            
            // Volume Actions Bar
            if let vol = appState.selectedVolume {
                HStack(spacing: 8) {
                    if vol.isRemovable {
                        Button {
                            showingFormatVolumeSheet = true
                        } label: {
                            Label("Format", systemImage: "sdcard.fill")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .help("Format SD/USB to FAT32 (⌘⌥V)")
                    }
                    
                    Button {
                        showingCreateFloppySheet = true
                    } label: {
                        Label("Floppy", systemImage: "opticaldiscdrive")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                    .help("Create blank .HFE floppy image (⌘⇧F)")
                    
                    Button {
                        NotificationCenter.default.post(name: .bootableDiskWizard, object: nil)
                    } label: {
                        Label("Boot Disk", systemImage: "wand.and.stars")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                    .help("Create bootable HD image (⌘⇧B)")
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            
            // Search (always visible)
            if !appState.images.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(searchFieldFocused ? Theme.accent : .secondary)
                        .font(.system(size: 14))
                    TextField("Search images... (⌘F)", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($searchFieldFocused)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(searchFieldFocused ? Theme.accent.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            
            Divider()
            
            // Boot drive warning
            if !appState.images.isEmpty && !appState.images.contains(where: { $0.scsiID == 1 }) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No boot disk (HD1)")
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text("EMAX II requires HD1 with OS to boot. Add an image with SCSI ID 1.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    Button("Create HD1…") {
                                                NotificationCenter.default.post(name: .bootableDiskWizard, object: nil)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .accessibilityIdentifier("createHD1Button")
                }
                .padding(10)
                .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            
            // Image list
            if appState.isProcessing && appState.images.isEmpty {
                // Skeleton loading state
                ScrollView {
                    VStack(spacing: 0) {
                        ImageListSkeleton(count: 8)
                            .padding(.horizontal, Theme.Spacing.md)
                    }
                }
            } else if appState.images.isEmpty {
                emptyState
            } else if filteredImages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No matches for \"\(searchText)\"")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Multi-select toolbar
                if !selectedImages.isEmpty && selectedImages.count > 1 {
                    HStack {
                        Text("\(selectedImages.count) images selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Delete All") {
                            showDeleteConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.bar)
                }
                
                List(filteredImages, id: \.id, selection: Binding(
                    get: { 
                        if selectedImages.isEmpty {
                            return appState.selectedImage.map { Set([$0.id]) } ?? Set()
                        }
                        return selectedImages
                    },
                    set: { newSelection in
                        // Batch selection updates to prevent flicker
                        var transaction = Transaction(animation: nil)
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            if newSelection.count == 1, let first = newSelection.first {
                                selectedImages = newSelection
                                appState.selectedImage = filteredImages.first { $0.id == first }
                            } else if newSelection.count > 1 {
                                selectedImages = newSelection
                                appState.selectedImage = nil
                            } else {
                                selectedImages = newSelection
                                appState.selectedImage = nil
                            }
                        }
                    }
                )) { image in
                    ImageRow(image: image, isSelected: selectedImages.contains(image.id) || appState.selectedImage?.id == image.id)
                        .tag(image.id)
                        .contextMenu { imageContextMenu(for: image) }
                        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                            handleEB2DropOnImage(providers, image: image)
                        }
                }
                .listStyle(.plain)
                // Disable implicit animations on list to prevent flicker
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
            
            // Status bar
            HStack {
                Image(systemName: "info.circle")
                Text(appState.statusMessage)
                Spacer()
                Text(appState.currentDevice.displayName)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(Theme.accent)
                    .font(.caption.bold())
            }
            .font(.caption)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(.bar)
        }
        .overlay {
            if dragOver {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.blue, lineWidth: 3, antialiased: true)
                    .background(.blue.opacity(0.08))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 36))
                            Text("Drop .hda, .EZ2, or .EB2 files")
                                .font(.headline)
                        }
                        .foregroundStyle(.blue)
                    }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            handleDrop(providers)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingNewImageSheet = true }) {
                    Label("New Image", systemImage: "plus")
                }
                .help("Create new image (⇧⌘N)")
            }
        }
        .sheet(isPresented: $showingNewImageSheet) {
            NewImageSheet()
        }
        .sheet(isPresented: $showingFormatSheet) {
            if let img = imageToFormat {
                FormatDiskSheet(image: img)
            }
        }
        .sheet(isPresented: $showingFormatVolumeSheet) {
            if let vol = appState.selectedVolume {
                FormatVolumeSheet(volume: vol)
            }
        }
        .sheet(isPresented: $showingCreateFloppySheet) {
            CreateFloppySheet()
        }
        .sheet(isPresented: $showingRenameSheet) {
            if let img = imageToRename {
                RenameImageSheet(image: img)
            }
        }
        .sheet(isPresented: $showingDuplicateSheet) {
            if let img = imageToDuplicate {
                DuplicateImageSheet(image: img)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newImage)) { _ in
            showingNewImageSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in
            searchFieldFocused = true
        }
        .alert("Delete Image?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                imageToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let image = imageToDelete {
                    appState.deleteImage(image)
                    toastManager?.show(
                        message: "Trashed \(image.filename)",
                        icon: "trash.fill",
                        color: .orange,
                        undoAction: {
                            appState.undo()
                        }
                    )
                    imageToDelete = nil
                    selectedImages.remove(image.id)
                } else if !selectedImages.isEmpty {
                    // Batch delete
                    let imagesToDelete = filteredImages.filter { selectedImages.contains($0.id) }
                    for image in imagesToDelete {
                        appState.deleteImage(image)
                    }
                    toastManager?.show(
                        message: "Trashed \(imagesToDelete.count) image(s)",
                        icon: "trash.fill",
                        color: .orange
                    )
                    selectedImages.removeAll()
                }
            }
        } message: {
            if let image = imageToDelete {
                Text("This will move '\(image.filename)' to Trash. This action can be undone.")
            } else if !selectedImages.isEmpty {
                Text("This will move \(selectedImages.count) image(s) to Trash. This action can be undone.")
            } else {
                Text("This will move the selected image(s) to Trash. This action can be undone.")
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sdcard")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No images found")
                .font(.title2)
            Text("Drop .hda or .EZ2 files here, or click + to create")
                .foregroundStyle(.secondary)
            
            Button("Create New Image") { showingNewImageSheet = true }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func imageContextMenu(for image: DiskImage) -> some View {
        Button("Browse Banks") {
            appState.selectedImage = image
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .browseBanks, object: nil)
            }
        }
        
        Button("Import Banks…") {
            appState.selectedImage = image
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .importBanks, object: nil)
            }
        }
        
        Divider()
        
        Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([image.url])
        }
        
        Button("Rename for ZuluSCSI…") {
            imageToRename = image
            showingRenameSheet = true
        }

        Button("Duplicate…") {
            imageToDuplicate = image
            showingDuplicateSheet = true
        }
        
        Divider()
        
        Button("Format Disk…", role: .destructive) {
            imageToFormat = image
            showingFormatSheet = true
        }
        
        Button("Move to Trash", role: .destructive) {
            imageToDelete = image
            showDeleteConfirmation = true
        }
    }
    
    // MARK: - Drop handlers
    
    /// Drop .hda/.ez2 onto the list → copy to volume
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let volume = appState.selectedVolume else { return false }
        
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                
                let ext = url.pathExtension.lowercased()
                
                if appState.currentDevice.imageExtensions.contains(ext) {
                    // .hda/.ez2 → copy to volume
                    let dest = volume.url.appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.copyItem(at: url, to: dest)
                    DispatchQueue.main.async {
                        appState.refreshImages()
                        appState.addActivity("Imported \(url.lastPathComponent)", type: .success)
                    }
                }
            }
        }
        return true
    }
    
    /// Drop E-mu files or audio onto a specific image → import banks
    private func handleEB2DropOnImage(_ providers: [NSItemProvider], image: DiskImage) -> Bool {
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
            var totalImported = 0
            
            let emuFiles = fileURLs.filter { FormatConverter.emuExtensions.contains($0.pathExtension.lowercased()) }
            let audioFiles = fileURLs.filter { SampleConverter.supportedExtensions.contains($0.pathExtension.lowercased()) && !FormatConverter.emuExtensions.contains($0.pathExtension.lowercased()) }
            
            if !emuFiles.isEmpty {
                let (imported, _) = FormatConverter.convertAndImport(urls: emuFiles, into: image.url)
                totalImported += imported.count
            }
            
            for audioURL in audioFiles {
                let name = String(audioURL.deletingPathExtension().lastPathComponent.prefix(12))
                if let _ = try? SampleConverter.convertAndImport(audioURLs: [audioURL], bankName: name, imageURL: image.url) {
                    totalImported += 1
                }
            }
            
            appState.addActivity("Imported \(totalImported) bank(s) into \(image.filename)", type: totalImported > 0 ? .success : .warning)
        }
        return true
    }
    
    // MARK: - Keyboard Navigation
    
    private func selectPreviousImage() {
        guard !filteredImages.isEmpty else { return }
        let currentIndex = appState.selectedImage.flatMap { image in
            filteredImages.firstIndex { $0.id == image.id }
        } ?? -1
        
        let previousIndex = max(0, currentIndex - 1)
        appState.selectedImage = filteredImages[previousIndex]
    }
    
    private func selectNextImage() {
        guard !filteredImages.isEmpty else { return }
        let currentIndex = appState.selectedImage.flatMap { image in
            filteredImages.firstIndex { $0.id == image.id }
        } ?? (filteredImages.count - 1)
        
        let nextIndex = min(filteredImages.count - 1, currentIndex + 1)
        appState.selectedImage = filteredImages[nextIndex]
    }
}

struct ImageRow: View {
    @EnvironmentObject var appState: AppState
    let image: DiskImage
    let isSelected: Bool
    
    @State private var isDragOver = false
    @State private var isHovered = false
    @State private var copyStatus: String?
    
    init(image: DiskImage, isSelected: Bool = false) {
        self.image = image
        self.isSelected = isSelected
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(image.scsiID != nil ? Color.orange.gradient : Color.gray.gradient)
                    .frame(width: 40, height: 40)
                
                if let id = image.scsiID {
                    Text("ID\(id)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "questionmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(image.filename)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label(image.formattedSize, systemImage: "internaldrive")
                    if let label = image.label {
                        Text("· \(label)")
                    }
                    if let idx = image.imageIndex {
                        Text("· Slot \(idx)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                
                if let status = copyStatus {
                    Text(status)
                        .font(.caption2)
                        .foregroundStyle(Theme.success)
                }
            }
            
            Spacer()
            
            if isDragOver {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.title3)
            }
            
            Text(image.fileExtension.uppercased())
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(image.fileExtension == "ez2" ? .purple.opacity(0.15) : .orange.opacity(0.15))
                .foregroundStyle(image.fileExtension == "ez2" ? .purple : .orange)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            Group {
                if isSelected {
                    Theme.accent.opacity(0.2)
                } else if isHovered {
                    Theme.bgElevated
                } else if isDragOver {
                    Theme.accent.opacity(0.1)
                } else {
                    Color.clear
                }
            }
            .animation(.easeOut(duration: 0.2), value: isHovered)
            .animation(.easeOut(duration: 0.2), value: isSelected)
            .animation(.easeOut(duration: 0.15), value: isDragOver)
        )
        .overlay {
            if isDragOver {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.accent, lineWidth: 2)
            } else if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.accent.opacity(0.5), lineWidth: 1)
            }
        }
        // Use drawingGroup only for complex rows to improve performance
        .drawingGroup(opaque: true, colorMode: .extendedLinear)
        .onHover { hovering in
            // Throttle hover updates to prevent flicker
            if hovering != isHovered {
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
        }
        .dropDestination(for: Data.self) { items, _ in
            handleBankDrop(items)
        } isTargeted: { isTargeted in
            isDragOver = isTargeted
        }
    }
    
    private func handleBankDrop(_ items: [Data]) -> Bool {
        guard let data = items.first,
              let payload = BankTransferPayload.from(data: data) else {
            return false
        }
        
        // Don't allow drop on same image
        guard payload.sourceImagePath != image.url.path else {
            return false
        }
        
        // Perform copy in background
        Task.detached {
            do {
                let sourceURL = URL(fileURLWithPath: payload.sourceImagePath)
                
                // Parse source to get bank entry
                let sourceFS = try EmaxIIParser.parseHDImage(at: sourceURL)
                guard let bankEntry = sourceFS.userBanks.first(where: { $0.catalogIndex == payload.catalogIndex }) else { return }
                
                // Copy bank
                try BankManager.copyBank(
                    entry: bankEntry,
                    sourceImageURL: sourceURL,
                    destinationImageURL: image.url,
                    clusterSize: sourceFS.clusterSize,
                    clusterAreaStartSector: sourceFS.clusterAreaStartSector
                )
                
                await MainActor.run {
                    copyStatus = "✓ Copied \(payload.bankName)"
                    appState.addActivity("Copied bank \"\(payload.bankName)\" to \(image.filename)", type: .success)
                }
                
                // Clear status after 3 seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    copyStatus = nil
                }
            } catch {
                await MainActor.run {
                    appState.addActivity("Failed to copy bank: \(error.localizedDescription)", type: .error)
                }
            }
        }
        
        return true
    }
}

struct BreadcrumbView: View {
    let volumeName: String
    let volumeIcon: String
    let selectedImage: DiskImage?
    let onVolumeClick: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            // Volume breadcrumb (clickable)
            Button(action: onVolumeClick) {
                HStack(spacing: 6) {
                    Image(systemName: volumeIcon)
                        .font(.system(size: 13))
                    Text(volumeName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(selectedImage != nil ? .secondary : Theme.accent)
            }
            .buttonStyle(.plain)
            .help("Click to deselect image")
            
            // Separator
            if selectedImage != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                
                // Image breadcrumb (current selection)
                HStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 13))
                    Text(selectedImage?.filename ?? "")
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.accent)
            }
            
            Spacer()
            
            // Image count badge
            if selectedImage != nil {
                Text("1 selected")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1), in: Capsule())
            }
        }
    }
}
