import Foundation

/// Represents a mounted volume (SD card, USB drive, or local folder)
struct MountedVolume: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let isRemovable: Bool
    let totalSize: Int64
    let freeSpace: Int64
    
    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file)
    }
    
    var usagePercent: Double {
        guard totalSize > 0 else { return 0 }
        return Double(totalSize - freeSpace) / Double(totalSize)
    }
    
    /// Scan for mounted removable volumes + allow local folders
    static func scanMounted() -> [MountedVolume] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        
        guard let volumes = fm.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else {
            return []
        }
        
        return volumes.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            let isRemovable = values.volumeIsRemovable ?? false
            
            // Show removable volumes (SD/USB) and /Volumes/* (skip root)
            guard isRemovable || (url.path.hasPrefix("/Volumes/") && url.path != "/Volumes") else { return nil }
            
            return MountedVolume(
                url: url,
                name: values.volumeName ?? url.lastPathComponent,
                isRemovable: isRemovable,
                totalSize: Int64(values.volumeTotalCapacity ?? 0),
                freeSpace: Int64(values.volumeAvailableCapacity ?? 0)
            )
        }
    }
}
