import Foundation

/// Supported E-mu device families — add new models here
enum DeviceType: String, CaseIterable, Identifiable, Codable {
    case emaxII = "EMAX II"
    // Future:
    // case emaxI = "EMAX I"
    // case esi32 = "ESI-32"
    // case emulatorIII = "Emulator III"
    // case proteus = "Proteus"

    var id: String { rawValue }

    var displayName: String { rawValue }

    /// Valid file extensions for this device (HD + FD/Gotek formats)
    var imageExtensions: Set<String> {
        switch self {
        case .emaxII:
            return ["hda", "ez2", "img", "iso", "hfe", "dsk"]
        }
    }

    /// Extensions that indicate floppy/Gotek images
    var floppyExtensions: Set<String> {
        switch self {
        case .emaxII:
            return ["hfe", "dsk"]
        }
    }

    /// Valid bank/preset extensions
    var bankExtensions: Set<String> {
        switch self {
        case .emaxII:
            return ["eb2", "emx"]
        }
    }

    /// ZuluSCSI hard disk image filename prefix
    var scsiPrefix: String {
        switch self {
        case .emaxII:
            return "HD"
        }
    }

    /// Gotek/floppy image filename prefix (FD00.img, FD10.hfe, etc.)
    var floppyPrefix: String {
        switch self {
        case .emaxII:
            return "FD"
        }
    }

    /// Max supported SCSI IDs
    var maxScsiID: Int {
        switch self {
        case .emaxII:
            return 6  // 0-6, 7 reserved for host
        }
    }
}
