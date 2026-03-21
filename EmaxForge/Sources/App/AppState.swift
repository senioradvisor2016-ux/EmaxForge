import SwiftUI
import Combine

/// Global app state
class AppState: ObservableObject {
    @Published var selectedVolume: MountedVolume? {
        didSet { startDirectoryMonitor() }
    }
    @Published var currentDevice: DeviceType = .emaxII
    @Published var images: [DiskImage] = []
    @Published var selectedImage: DiskImage?
    @Published var statusMessage: String = "Ready"
    @Published var statusType: ActivityItem.ActivityType = .info
    @Published var recentActivity: [ActivityItem] = []
    
    // Navigation (replaces sheets with in-frame navigation)
    @Published var navigationPath = NavigationPath()
    
    // Progress tracking
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var progressMessage = ""
    
    // Undo/Redo
    private let undoManager = UndoManager()
    @Published var canUndo = false
    @Published var canRedo = false
    
    let fileService = FileService()
    let imageService = ImageService()
    let autoSaveManager = AutoSaveManager()
    let favoritesManager = FavoritesManager()
    
    // File system watcher for auto-refresh
    private var directoryMonitorSource: DispatchSourceFileSystemObject?
    private var monitorFileDescriptor: Int32 = -1
    
    init() {
        // Update undo/redo state when manager changes
        NotificationCenter.default.addObserver(
            forName: .NSUndoManagerDidUndoChange,
            object: undoManager,
            queue: .main
        ) { [weak self] _ in
            self?.updateUndoRedoState()
        }
        
        NotificationCenter.default.addObserver(
            forName: .NSUndoManagerDidRedoChange,
            object: undoManager,
            queue: .main
        ) { [weak self] _ in
            self?.updateUndoRedoState()
        }
        
        NotificationCenter.default.addObserver(
            forName: .NSUndoManagerWillUndoChange,
            object: undoManager,
            queue: .main
        ) { [weak self] _ in
            self?.updateUndoRedoState()
        }
        
        NotificationCenter.default.addObserver(
            forName: .NSUndoManagerWillRedoChange,
            object: undoManager,
            queue: .main
        ) { [weak self] _ in
            self?.updateUndoRedoState()
        }
    }
    
    private func updateUndoRedoState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.canUndo = self.undoManager.canUndo
            self.canRedo = self.undoManager.canRedo
        }
    }
    
    private var refreshTask: Task<Void, Never>?
    
    func refreshImages() {
        // Cancel any pending refresh
        refreshTask?.cancel()
        
        // Debounce rapid refresh calls
        refreshTask = Task {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms debounce
            
            guard !Task.isCancelled, let volume = selectedVolume else {
                await MainActor.run {
                    images = []
                }
                return
            }
            
            // Perform scan on background thread
            let scannedImages = fileService.scanForImages(at: volume.url, device: currentDevice)
            
            await MainActor.run {
                if !Task.isCancelled {
                    // Use transaction to batch the update
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        images = scannedImages
                        statusMessage = "Found \(images.count) image(s)"
                    }
                }
            }
        }
    }
    
    // MARK: - Directory Monitor (auto-refresh on file changes)
    
    private func startDirectoryMonitor() {
        stopDirectoryMonitor()
        
        guard let volume = selectedVolume else { return }
        let path = volume.url.path
        
        monitorFileDescriptor = open(path, O_EVTONLY)
        guard monitorFileDescriptor >= 0 else { return }
        
        directoryMonitorSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: monitorFileDescriptor,
            eventMask: [.write, .delete, .rename, .link],
            queue: DispatchQueue.global(qos: .utility)
        )
        
        directoryMonitorSource?.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.refreshImages()
            }
        }
        
        directoryMonitorSource?.setCancelHandler { [weak self] in
            if let fd = self?.monitorFileDescriptor, fd >= 0 {
                close(fd)
                self?.monitorFileDescriptor = -1
            }
        }
        
        directoryMonitorSource?.resume()
    }
    
    private func stopDirectoryMonitor() {
        directoryMonitorSource?.cancel()
        directoryMonitorSource = nil
    }
    
    deinit {
        stopDirectoryMonitor()
    }
    
    func addActivity(_ message: String, type: ActivityItem.ActivityType = .info) {
        let item = ActivityItem(message: message, type: type)
        recentActivity.insert(item, at: 0)
        if recentActivity.count > 50 { recentActivity.removeLast() }
        statusMessage = message
        statusType = type
        
        // Trigger success animation for completed operations
        if type == .success {
            NotificationCenter.default.post(name: .showSuccess, object: nil)
        }
    }
    
    func ejectVolume(_ specificVolume: MountedVolume? = nil) {
        let target = specificVolume ?? selectedVolume
        guard let volume = target else { return }
        
        // UX-03: Validation - prevent ejecting wrong volume
        if let selected = selectedVolume, let specific = specificVolume {
            if selected.id != specific.id {
                addActivity("⚠️ Cannot eject \(specific.name) while \(selected.name) is active", type: .error)
                return
            }
        }
        
        let url = volume.url

        // Clear state if ejecting the selected volume
        if selectedVolume?.id == volume.id {
            selectedImage = nil
            selectedVolume = nil
            images = []
        }

        DispatchQueue.global().async {
            try? FileManager.default.unmountVolume(at: url)
            DispatchQueue.main.async {
                self.addActivity("Ejected \(volume.name)", type: .success)
            }
        }
    }
    
    // MARK: - Undo/Redo
    
    func undo() {
        guard undoManager.canUndo else { return }
        undoManager.undo()
        refreshImages()
        // Update state after undo completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateUndoRedoState()
        }
    }
    
    func redo() {
        guard undoManager.canRedo else { return }
        undoManager.redo()
        refreshImages()
        // Update state after redo completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateUndoRedoState()
        }
    }
    
    /// Delete image with undo support and optimistic update
    func deleteImage(_ image: DiskImage) {
        let imageURL = image.url
        let imageFilename = image.filename
        let wasSelected = selectedImage?.id == image.id
        let imageIndex = images.firstIndex { $0.id == image.id }
        
        // Register undo
        undoManager.registerUndo(withTarget: self) { state in
            // Restore: copy from trash back to original location
            if let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first {
                let trashedFile = trashURL.appendingPathComponent(imageFilename)
                if FileManager.default.fileExists(atPath: trashedFile.path) {
                    try? FileManager.default.moveItem(at: trashedFile, to: imageURL)
                    state.refreshImages()
                    if wasSelected {
                        state.selectedImage = state.images.first { $0.url == imageURL }
                    }
                    state.addActivity("Restored \(imageFilename)", type: .success)
                }
            }
        }
        undoManager.setActionName("Delete \(imageFilename)")
        
        // Optimistic update: Remove from UI immediately
        if let index = imageIndex {
            images.remove(at: index)
        }
        if wasSelected && selectedImage?.id == image.id {
            selectedImage = nil
        }
        addActivity("Trashed \(imageFilename)", type: .warning)
        
        // Perform actual delete in background
        Task {
            do {
                try fileService.trashImage(image)
                // Update undo/redo state after delete completes
                await MainActor.run {
                    updateUndoRedoState()
                }
            } catch {
                // Rollback on error
                await MainActor.run {
                    if let index = imageIndex, index <= images.count {
                        images.insert(image, at: index)
                    } else {
                        images.append(image)
                    }
                    if wasSelected {
                        selectedImage = image
                    }
                    addActivity("Failed to delete \(imageFilename): \(error.localizedDescription)", type: .error)
                }
            }
        }
    }
    
    /// Rename image with undo support
    func renameImage(_ image: DiskImage, scsiID: Int, imageIndex: Int?, label: String?) {
        let oldURL = image.url
        let oldFilename = image.filename
        
        // Register undo
        undoManager.registerUndo(withTarget: self) { state in
            // Restore old name
            if let newURL = try? state.fileService.renameImage(
                DiskImage.parse(url: oldURL, device: state.currentDevice),
                scsiID: image.scsiID ?? 0,
                imageIndex: image.imageIndex,
                label: image.label
            ) {
                state.refreshImages()
                state.selectedImage = state.images.first { $0.url == newURL }
                state.addActivity("Renamed back to \(oldFilename)", type: .info)
            }
        }
        undoManager.setActionName("Rename \(oldFilename)")
        
        // Perform rename
        do {
            let newURL = try fileService.renameImage(image, scsiID: scsiID, imageIndex: imageIndex, label: label)
            refreshImages()
            selectedImage = images.first { $0.url == newURL }
            addActivity("Renamed to \(DiskImage.parse(url: newURL, device: currentDevice).filename)", type: .success)
            // Update undo/redo state after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.updateUndoRedoState()
            }
        } catch {
            addActivity("Failed to rename: \(error.localizedDescription)", type: .error)
        }
    }
    
    // MARK: - Progress
    
    func startProgress(message: String) {
        isProcessing = true
        progress = 0.0
        progressMessage = message
        statusMessage = message
    }
    
    func updateProgress(_ value: Double, message: String? = nil) {
        progress = max(0.0, min(1.0, value))
        if let msg = message {
            progressMessage = msg
            statusMessage = msg
        }
    }
    
    func endProgress(message: String? = nil) {
        isProcessing = false
        progress = 0.0
        if let msg = message {
            progressMessage = msg
            statusMessage = msg
        } else {
            progressMessage = ""
        }
    }
}

struct ActivityItem: Identifiable {
    let id = UUID()
    let message: String
    let type: ActivityType
    let timestamp = Date()
    
    enum ActivityType {
        case info, success, warning, error
        
        var color: Color {
            switch self {
            case .info: return .secondary
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .success: return "checkmark.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            }
        }
    }
}

extension FileManager {
    func unmountVolume(at url: URL) throws {
        try NSWorkspace.shared.unmountAndEjectDevice(at: url)
    }
}
