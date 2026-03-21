import Foundation

/// Service for browsing EMAX II disk catalogs
class CatalogService {
    
    struct CatalogSummary {
        let totalEntries: Int
        let activeEntries: Int
        let bankCount: Int
        let osEntry: CatalogEntry?
        let clusterSize: Int
        let entries: [CatalogEntry]
    }
    
    struct CatalogEntry: Identifiable {
        let id: Int  // Use index as ID
        let index: Int
        let name: String
        let cluster: Int
        let sizeClusters: Int
        let sizeBytes: Int
        let sizeMB: Double
        let flags: String
        let presetCount: Int
        let isActive: Bool
        let isOS: Bool
        let isEmpty: Bool
    }
    
    /// Get catalog summary from disk image
    static func getSummary(imageURL: URL) async throws -> CatalogSummary {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["cli-anything-emaxforge", "catalog-summary", imageURL.path, "--json"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let json = try JSONDecoder().decode(CatalogSummaryResponse.self, from: data)
        
        // Convert entries
        let entries = json.entries.map { entry in
            CatalogEntry(
                id: entry.index,
                index: entry.index,
                name: entry.name,
                cluster: entry.cluster,
                sizeClusters: entry.size_clusters,
                sizeBytes: entry.size_bytes,
                sizeMB: entry.size_mb,
                flags: entry.flags,
                presetCount: entry.preset_count ?? 0,
                isActive: entry.is_active,
                isOS: entry.is_os,
                isEmpty: entry.is_empty
            )
        }
        
        // Convert OS entry
        var osEntry: CatalogEntry? = nil
        if let os = json.os_entry {
            osEntry = CatalogEntry(
                id: os.index,
                index: os.index,
                name: os.name,
                cluster: os.cluster,
                sizeClusters: os.size_clusters,
                sizeBytes: os.size_bytes,
                sizeMB: os.size_mb,
                flags: os.flags,
                presetCount: os.preset_count ?? 0,
                isActive: os.is_active,
                isOS: os.is_os,
                isEmpty: os.is_empty
            )
        }
        
        return CatalogSummary(
            totalEntries: json.total_entries,
            activeEntries: json.active_entries,
            bankCount: json.bank_count,
            osEntry: osEntry,
            clusterSize: json.cluster_size,
            entries: entries
        )
    }
    
    // MARK: - Codable Models
    
    private struct CatalogSummaryResponse: Codable {
        let total_entries: Int
        let active_entries: Int
        let bank_count: Int
        let os_entry: EntryResponse?
        let cluster_size: Int
        let entries: [EntryResponse]
    }
    
    private struct EntryResponse: Codable {
        let index: Int
        let name: String
        let cluster: Int
        let size_clusters: Int
        let size_bytes: Int
        let size_mb: Double
        let flags: String
        let preset_count: Int?
        let is_active: Bool
        let is_os: Bool
        let is_empty: Bool
    }
}
