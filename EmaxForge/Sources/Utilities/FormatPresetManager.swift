import Foundation
import Combine

/// Manages format presets with persistent storage
@MainActor
class FormatPresetManager: ObservableObject {
    static let shared = FormatPresetManager()
    
    @Published private(set) var presets: [FormatPreset] = []
    
    private let presetsKey = "com.emaxforge.formatPresets"
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadPresets()
    }
    
    // MARK: - Persistence
    
    private func loadPresets() {
        // Try to load saved presets
        if let data = userDefaults.data(forKey: presetsKey),
           let decoded = try? JSONDecoder().decode([FormatPreset].self, from: data) {
            self.presets = decoded
        } else {
            // First launch: load factory defaults
            self.presets = FormatPreset.FactoryPresets.all
            savePresets()
        }
        
        // Ensure factory defaults are always present
        ensureFactoryDefaults()
    }
    
    private func savePresets() {
        if let encoded = try? JSONEncoder().encode(presets) {
            userDefaults.set(encoded, forKey: presetsKey)
        }
    }
    
    private func ensureFactoryDefaults() {
        let factoryIDs = Set(FormatPreset.FactoryPresets.all.map(\.id))
        let existingIDs = Set(presets.map(\.id))
        
        // Add missing factory defaults
        for factory in FormatPreset.FactoryPresets.all {
            if !existingIDs.contains(factory.id) {
                presets.append(factory)
            }
        }
        
        if existingIDs.count != presets.count {
            savePresets()
        }
    }
    
    // MARK: - CRUD Operations
    
    func addPreset(_ preset: FormatPreset) {
        presets.append(preset)
        savePresets()
    }
    
    func updatePreset(_ preset: FormatPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            savePresets()
        }
    }
    
    func deletePreset(_ preset: FormatPreset) {
        // Cannot delete factory defaults
        guard !preset.isFactoryDefault else { return }
        
        presets.removeAll { $0.id == preset.id }
        
        // If deleted preset was default, set first enabled preset as default
        if preset.isDefault, let firstEnabled = presets.first(where: { $0.isEnabled }) {
            var updated = firstEnabled
            updated.isDefault = true
            updatePreset(updated)
        }
        
        savePresets()
    }
    
    func deletePresets(_ presets: [FormatPreset]) {
        for preset in presets {
            deletePreset(preset)
        }
    }
    
    // MARK: - Default Management
    
    func setAsDefault(_ preset: FormatPreset) {
        // Remove default flag from all presets
        for i in presets.indices {
            presets[i].isDefault = false
        }
        
        // Set new default
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index].isDefault = true
        }
        
        savePresets()
    }
    
    var defaultPreset: FormatPreset? {
        presets.first { $0.isDefault && $0.isEnabled }
    }
    
    // MARK: - Enable/Disable
    
    func toggleEnabled(_ preset: FormatPreset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        
        presets[index].isEnabled.toggle()
        
        // If disabling the default preset, find new default
        if !presets[index].isEnabled && presets[index].isDefault {
            if let firstEnabled = presets.first(where: { $0.isEnabled }) {
                var updated = firstEnabled
                updated.isDefault = true
                updatePreset(updated)
            }
        }
        
        savePresets()
    }
    
    // MARK: - Filtering
    
    var enabledPresets: [FormatPreset] {
        presets.filter { $0.isEnabled }
    }
    
    var userPresets: [FormatPreset] {
        presets.filter { !$0.isFactoryDefault }
    }
    
    var factoryPresets: [FormatPreset] {
        presets.filter { $0.isFactoryDefault }
    }
    
    // MARK: - Import/Export
    
    func exportPreset(_ preset: FormatPreset, to url: URL) throws {
        let data = try preset.exportToJSON()
        try data.write(to: url)
    }
    
    func importPreset(from url: URL) throws {
        let data = try Data(contentsOf: url)
        var preset = try FormatPreset.importFromJSON(data)
        
        // Generate new ID to avoid conflicts
        preset = FormatPreset(
            id: UUID(),
            name: preset.name,
            clusterSize: preset.clusterSize,
            volumeSize: preset.volumeSize,
            includeOS: preset.includeOS,
            isEnabled: preset.isEnabled,
            isDefault: false, // Imported presets are never default
            notes: preset.notes
        )
        
        addPreset(preset)
    }
    
    func exportAllPresets(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(presets)
        try data.write(to: url)
    }
    
    func importAllPresets(from url: URL, replace: Bool = false) throws {
        let data = try Data(contentsOf: url)
        let imported = try JSONDecoder().decode([FormatPreset].self, from: data)
        
        if replace {
            // Replace all user presets, keep factory defaults
            presets = factoryPresets
        }
        
        // Add imported presets with new IDs
        for preset in imported {
            var newPreset = preset
            newPreset = FormatPreset(
                id: UUID(),
                name: newPreset.name,
                clusterSize: newPreset.clusterSize,
                volumeSize: newPreset.volumeSize,
                includeOS: newPreset.includeOS,
                isEnabled: newPreset.isEnabled,
                isDefault: false,
                notes: newPreset.notes
            )
            presets.append(newPreset)
        }
        
        savePresets()
    }
    
    // MARK: - Reset
    
    func resetToDefaults() {
        presets = FormatPreset.FactoryPresets.all
        savePresets()
    }
}
