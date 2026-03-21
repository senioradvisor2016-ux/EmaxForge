import Foundation

/// Manages favorites for banks and samples
class FavoritesManager: ObservableObject {
    
    @Published var favoriteBanks: Set<String> = []
    @Published var favoriteSamples: Set<String> = []
    
    private let favoritesKey = "favoriteBanks"
    private let samplesKey = "favoriteSamples"
    
    init() {
        loadFavorites()
    }
    
    // MARK: - Bank Favorites
    
    func isFavorite(bankName: String) -> Bool {
        favoriteBanks.contains(bankName)
    }
    
    func toggleFavorite(bankName: String) {
        if favoriteBanks.contains(bankName) {
            favoriteBanks.remove(bankName)
        } else {
            favoriteBanks.insert(bankName)
        }
        saveFavorites()
    }
    
    func addFavorite(bankName: String) {
        favoriteBanks.insert(bankName)
        saveFavorites()
    }
    
    func removeFavorite(bankName: String) {
        favoriteBanks.remove(bankName)
        saveFavorites()
    }
    
    // MARK: - Sample Favorites
    
    func isFavorite(sampleName: String) -> Bool {
        favoriteSamples.contains(sampleName)
    }
    
    func toggleFavorite(sampleName: String) {
        if favoriteSamples.contains(sampleName) {
            favoriteSamples.remove(sampleName)
        } else {
            favoriteSamples.insert(sampleName)
        }
        saveFavorites()
    }
    
    // MARK: - Persistence
    
    private func loadFavorites() {
        if let banks = UserDefaults.standard.array(forKey: favoritesKey) as? [String] {
            favoriteBanks = Set(banks)
        }
        if let samples = UserDefaults.standard.array(forKey: samplesKey) as? [String] {
            favoriteSamples = Set(samples)
        }
    }
    
    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteBanks), forKey: favoritesKey)
        UserDefaults.standard.set(Array(favoriteSamples), forKey: samplesKey)
    }
}
