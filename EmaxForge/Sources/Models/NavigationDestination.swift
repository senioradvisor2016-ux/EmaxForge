import Foundation

/// All navigation destinations in the app (replaces sheets with in-frame navigation)
enum NavigationDestination: Hashable {
    case imageDetail(DiskImage)
    case bankBrowser(image: DiskImage, fileSystem: EmaxIIFileSystem)
    case sampleEditor(sample: BankSampleData.SampleEntry, bankName: String)
    case presetEditor(params: VoiceParameters, presetName: String)
    case batchRename(DiskImage)
    case hexViewer(DiskImage)
    case importBanks(DiskImage)
    case convertSamples(DiskImage)
    case slotManager
    
    // Hashable conformance
    static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.imageDetail(let a), .imageDetail(let b)): return a.id == b.id
        case (.bankBrowser(let a, _), .bankBrowser(let b, _)): return a.id == b.id
        case (.batchRename(let a), .batchRename(let b)): return a.id == b.id
        case (.hexViewer(let a), .hexViewer(let b)): return a.id == b.id
        case (.importBanks(let a), .importBanks(let b)): return a.id == b.id
        case (.convertSamples(let a), .convertSamples(let b)): return a.id == b.id
        case (.slotManager, .slotManager): return true
        case (.sampleEditor(let a, let aName), .sampleEditor(let b, let bName)):
            return a.name == b.name && aName == bName
        case (.presetEditor(_, let aName), .presetEditor(_, let bName)):
            return aName == bName
        default: return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .imageDetail(let img): hasher.combine("imageDetail"); hasher.combine(img.id)
        case .bankBrowser(let img, _): hasher.combine("bankBrowser"); hasher.combine(img.id)
        case .batchRename(let img): hasher.combine("batchRename"); hasher.combine(img.id)
        case .hexViewer(let img): hasher.combine("hexViewer"); hasher.combine(img.id)
        case .importBanks(let img): hasher.combine("importBanks"); hasher.combine(img.id)
        case .convertSamples(let img): hasher.combine("convertSamples"); hasher.combine(img.id)
        case .slotManager: hasher.combine("slotManager")
        case .sampleEditor(let sample, let bankName):
            hasher.combine("sampleEditor"); hasher.combine(sample.name); hasher.combine(bankName)
        case .presetEditor(_, let presetName):
            hasher.combine("presetEditor"); hasher.combine(presetName)
        }
    }
    
    /// Breadcrumb title
    var title: String {
        switch self {
        case .imageDetail(let img): return img.filename
        case .bankBrowser: return "Banks"
        case .sampleEditor(let sample, _): return sample.name
        case .presetEditor(_, let name): return name
        case .batchRename: return "Batch Rename"
        case .hexViewer: return "Hex View"
        case .importBanks: return "Import Banks"
        case .convertSamples: return "Convert Samples"
        case .slotManager: return "Slot Manager"
        }
    }
    
    /// SF Symbol icon
    var icon: String {
        switch self {
        case .imageDetail: return "internaldrive"
        case .bankBrowser: return "music.note.list"
        case .sampleEditor: return "waveform.path"
        case .presetEditor: return "slider.horizontal.3"
        case .batchRename: return "character.textbox"
        case .hexViewer: return "doc.text.magnifyingglass"
        case .importBanks: return "square.and.arrow.down"
        case .convertSamples: return "waveform.badge.plus"
        case .slotManager: return "square.grid.3x3"
        }
    }
}
