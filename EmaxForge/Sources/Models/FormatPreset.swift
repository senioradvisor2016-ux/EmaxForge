import Foundation

/// Physical format preset for quick-apply disk configurations
struct FormatPreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var clusterSize: Int
    var volumeSize: Int64
    var includeOS: Bool
    var isEnabled: Bool
    var isDefault: Bool
    
    // Metadata
    var createdDate: Date
    var notes: String
    
    init(
        id: UUID = UUID(),
        name: String,
        clusterSize: Int,
        volumeSize: Int64,
        includeOS: Bool = false,
        isEnabled: Bool = true,
        isDefault: Bool = false,
        createdDate: Date = Date(),
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.clusterSize = clusterSize
        self.volumeSize = volumeSize
        self.includeOS = includeOS
        self.isEnabled = isEnabled
        self.isDefault = isDefault
        self.createdDate = createdDate
        self.notes = notes
    }
    
    // MARK: - Computed Properties
    
    var formattedVolumeSize: String {
        ByteCountFormatter.string(fromByteCount: volumeSize, countStyle: .file)
    }
    
    var formattedClusterSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(clusterSize), countStyle: .file)
    }
    
    var description: String {
        var desc = "\(formattedVolumeSize), \(formattedClusterSize) clusters"
        if includeOS {
            desc += ", with OS"
        }
        return desc
    }
    
    var isFactoryDefault: Bool {
        // Check if this is one of the built-in presets
        FactoryPresets.all.contains { $0.id == id }
    }
    
    // MARK: - Validation
    
    func validate() -> ValidationResult {
        var errors: [String] = []
        
        // Name validation
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Name cannot be empty")
        }
        
        if name.count > 64 {
            errors.append("Name too long (max 64 characters)")
        }
        
        // Cluster size validation
        let validClusterSizes = [512, 1024, 2048, 4096, 6144]
        if !validClusterSizes.contains(clusterSize) {
            errors.append("Invalid cluster size (must be 512, 1024, 2048, 4096, or 6144)")
        }
        
        // Volume size validation
        if volumeSize < 1_000_000 {
            errors.append("Volume size too small (min 1 MB)")
        }
        
        if volumeSize > 4_294_967_296 {
            errors.append("Volume size too large (max 4 GB)")
        }
        
        // Cluster size vs volume size
        let minClustersNeeded = 100
        let clustersAvailable = Int(volumeSize / Int64(clusterSize))
        if clustersAvailable < minClustersNeeded {
            errors.append("Volume size too small for cluster size (need at least \(minClustersNeeded) clusters)")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    struct ValidationResult {
        let isValid: Bool
        let errors: [String]
    }
}

// MARK: - Factory Presets

extension FormatPreset {
    enum FactoryPresets {
        // HD Boot (524 MB with OS)
        static let hdBoot = FormatPreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "HD1 Boot (524 MB)",
            clusterSize: 6144,
            volumeSize: 524_288_000,
            includeOS: true,
            isDefault: true,
            notes: "Standard boot disk for EMAX II. Use for SCSI ID 1."
        )
        
        // HD Data (2 GB, no OS)
        static let hdData2GB = FormatPreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "HD1 Data (2 GB)",
            clusterSize: 6144,
            volumeSize: 2_000_000_000,
            includeOS: false,
            notes: "Data disk for sample libraries. Use for SCSI ID 1+."
        )
        
        // HD Data (4 GB, no OS)
        static let hdData4GB = FormatPreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "HD Data (4 GB)",
            clusterSize: 6144,
            volumeSize: 4_000_000_000,
            includeOS: false,
            notes: "Large data disk for extensive sample libraries."
        )
        
        // SD Boot (32 MB with OS)
        static let sdBoot = FormatPreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            name: "SD Boot (32 MB)",
            clusterSize: 512,
            volumeSize: 32_768_000,
            includeOS: true,
            notes: "Small boot disk for SD cards. Compatible with older EMAX II units."
        )
        
        // SD Data (128 MB)
        static let sdData = FormatPreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            name: "SD Data (128 MB)",
            clusterSize: 1024,
            volumeSize: 128_000_000,
            includeOS: false,
            notes: "Data disk for SD cards."
        )
        
        // Floppy HD (1.44 MB)
        static let floppyHD = FormatPreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
            name: "Floppy HD (1.44 MB)",
            clusterSize: 512,
            volumeSize: 1_474_560,
            includeOS: false,
            notes: "High-density floppy disk format."
        )
        
        static let all: [FormatPreset] = [
            hdBoot,
            hdData2GB,
            hdData4GB,
            sdBoot,
            sdData,
            floppyHD
        ]
    }
}

// MARK: - Import/Export

extension FormatPreset {
    /// Export to JSON data
    func exportToJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
    
    /// Import from JSON data
    static func importFromJSON(_ data: Data) throws -> FormatPreset {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(FormatPreset.self, from: data)
    }
}
