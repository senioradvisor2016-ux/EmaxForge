import Foundation

/// Floppy disk capacity variants (EMAX II / Gotek)
enum FloppySize: Int, CaseIterable {
    case singleDensity = 184_320   // 180 KB EMAX I
    case doubleDensity = 819_200   // 800 KB EMAX II standard
    case highDensity   = 1_474_560 // 1.44 MB PC HD

    var displayName: String {
        switch self {
        case .singleDensity: return "180 KB (SD)"
        case .doubleDensity: return "800 KB (DD)"
        case .highDensity:   return "1.44 MB (HD)"
        }
    }

    /// Detect from file size, nil if not a recognised floppy
    static func detect(bytes: Int64) -> FloppySize? {
        allCases.min(by: { abs($0.rawValue - Int(bytes)) < abs($1.rawValue - Int(bytes)) })
            .flatMap { candidate in
                // within 5% tolerance
                abs(candidate.rawValue - Int(bytes)) < candidate.rawValue / 20 ? candidate : nil
            }
    }
}

/// Represents a single disk image file on the volume
struct DiskImage: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let filename: String
    let fileSize: Int64
    let scsiID: Int?
    let imageIndex: Int?
    let label: String?
    let deviceType: DeviceType

    /// Whether this is a Gotek/floppy image (FD prefix or floppy extension)
    var isFloppy: Bool {
        let nameUpper = url.deletingPathExtension().lastPathComponent.uppercased()
        return nameUpper.hasPrefix(deviceType.floppyPrefix)
            || deviceType.floppyExtensions.contains(fileExtension)
    }

    /// Detected floppy capacity, nil for HD images
    var floppySize: FloppySize? {
        isFloppy ? FloppySize.detect(bytes: fileSize) : nil
    }

    /// Original extension (hda, ez2, hfe, etc.)
    var fileExtension: String {
        url.pathExtension.lowercased()
    }

    /// Human-readable size
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// ZuluSCSI-compatible filename: HD10.hda  or  FD00.img
    var zuluSCSIName: String {
        guard let scsiID else { return filename }
        let prefix = isFloppy ? deviceType.floppyPrefix : deviceType.scsiPrefix
        var name = "\(prefix)\(scsiID)"
        if let idx = imageIndex {
            name += "_\(idx)"
        }
        if let label, !label.isEmpty {
            name += "_\(label)"
        }
        name += isFloppy ? ".img" : ".hda"
        return name
    }

    /// Parse a filename into components (supports HD and FD prefixes)
    static func parse(url: URL, device: DeviceType) -> DiskImage {
        let filename = url.lastPathComponent
        let nameWithoutExt = url.deletingPathExtension().lastPathComponent
        let nameUpper = nameWithoutExt.uppercased()
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        var scsiID: Int?
        var imageIndex: Int?
        var label: String?

        // Try HD prefix first, then FD prefix
        for prefix in [device.scsiPrefix, device.floppyPrefix] {
            if nameUpper.hasPrefix(prefix) {
                let remainder = nameWithoutExt.dropFirst(prefix.count)
                let parts = remainder.split(separator: "_", maxSplits: 2)

                if let first = parts.first {
                    let firstStr = String(first)

                    // ZuluSCSI two-digit format: HD10 → SCSI 1, index 0
                    if firstStr.count == 2, parts.count == 1 {
                        if let firstDigit = Int(String(firstStr.prefix(1))),
                           let secondDigit = Int(String(firstStr.suffix(1))) {
                            scsiID = firstDigit
                            imageIndex = secondDigit
                        }
                    } else {
                        if let id = Int(firstStr) {
                            scsiID = id
                        }
                    }
                }

                if parts.count >= 2, let idx = Int(parts[1]) {
                    imageIndex = idx
                }
                if parts.count >= 3 {
                    label = String(parts[2])
                }
                break
            }
        }

        return DiskImage(
            url: url,
            filename: filename,
            fileSize: fileSize,
            scsiID: scsiID,
            imageIndex: imageIndex,
            label: label,
            deviceType: device
        )
    }

#if DEBUG
    /// Preview / test placeholder
    static var example: DiskImage {
        DiskImage(
            url: URL(fileURLWithPath: "/Volumes/SD/HD10.hda"),
            filename: "HD10.hda",
            fileSize: 239 * 1024 * 1024,
            scsiID: 1,
            imageIndex: 0,
            label: nil,
            deviceType: .emaxII
        )
    }
#endif
}
