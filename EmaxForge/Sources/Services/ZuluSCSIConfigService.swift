import Foundation

/// Generate and parse zuluscsi.ini configuration files
class ZuluSCSIConfigService {
    
    struct ZuluConfig {
        var enableMAC: Bool = false
        var maxSyncSpeed: Int = 10        // MHz
        var selectionDelay: Int = 255     // ms
        var startupDelay: Int = 0         // ms
        var devicePresets: [Int: DevicePreset] = [:]
        
        struct DevicePreset {
            var vendor: String = "E-mu"
            var product: String = "EMAX II HD"
            var sectorSize: Int = 512
        }
    }
    
    /// Generate zuluscsi.ini content for EMAX II (minimal Funkar-style config)
    func generateConfig(for device: DeviceType, images: [DiskImage]) -> String {
        var lines: [String] = []
        
        // Minimal config matching verified working Funkar setup
        lines.append("; ZuluSCSI config for \(device.displayName)")
        lines.append("[SCSI]")
        lines.append("EnableParity = 1")
        lines.append("")
        
        // ZuluSCSI auto-detects drives from filenames (HD10.hda, HD20.hda, etc.)
        // EMAX II always boots from SCSI ID 1 — HD10.hda must be the boot disk
        // BlockSize = 512 is required for EMAX II (specification, section 4.5.1.2)
        lines.append("[SCSI1]")
        lines.append("BlockSize = 512")
        
        return lines.joined(separator: "\n")
    }
    
    /// Write config to volume
    func writeConfig(content: String, to volumeURL: URL) throws {
        let configURL = volumeURL.appendingPathComponent("zuluscsi.ini")
        try content.write(to: configURL, atomically: true, encoding: .utf8)
    }
    
    /// Read existing config from volume
    func readConfig(from volumeURL: URL) -> String? {
        let configURL = volumeURL.appendingPathComponent("zuluscsi.ini")
        return try? String(contentsOf: configURL, encoding: .utf8)
    }
    
    /// Check if config exists on volume
    func configExists(on volumeURL: URL) -> Bool {
        let configURL = volumeURL.appendingPathComponent("zuluscsi.ini")
        return FileManager.default.fileExists(atPath: configURL.path)
    }
}
