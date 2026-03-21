import Foundation
import Combine

/// Manages auto-save functionality
class AutoSaveManager: ObservableObject {
    private var saveTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let saveInterval: TimeInterval = 30.0 // 30 seconds
    private let saveURL: URL
    
    @Published var hasUnsavedChanges = false
    @Published var lastSaveTime: Date?
    
    init() {
        let tempDir = FileManager.default.temporaryDirectory
        saveURL = tempDir.appendingPathComponent("EmaxForge_autosave.json")
    }
    
    func startAutoSave(for appState: AppState) {
        stopAutoSave()
        
        // Save immediately on start
        saveState(appState)
        
        // Set up periodic saves
        saveTimer = Timer.scheduledTimer(withTimeInterval: saveInterval, repeats: true) { [weak self] _ in
            self?.saveState(appState)
        }
        
        // Track changes
        appState.$images
            .dropFirst()
            .sink { [weak self] _ in
                self?.hasUnsavedChanges = true
            }
            .store(in: &cancellables)
    }
    
    func stopAutoSave() {
        saveTimer?.invalidate()
        saveTimer = nil
    }
    
    func saveState(_ appState: AppState) {
        // Serialize minimal state for recovery
        let state = AutoSaveState(
            selectedVolumePath: appState.selectedVolume?.url.path,
            selectedImagePath: appState.selectedImage?.url.path,
            timestamp: Date()
        )
        
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: saveURL)
            lastSaveTime = Date()
            hasUnsavedChanges = false
        }
    }
    
    func restoreState() -> AutoSaveState? {
        guard let data = try? Data(contentsOf: saveURL),
              let state = try? JSONDecoder().decode(AutoSaveState.self, from: data) else {
            return nil
        }
        return state
    }
    
    func clearAutoSave() {
        try? FileManager.default.removeItem(at: saveURL)
        hasUnsavedChanges = false
    }
}

struct AutoSaveState: Codable {
    let selectedVolumePath: String?
    let selectedImagePath: String?
    let timestamp: Date
}
