import SwiftUI
import UniformTypeIdentifiers

// MARK: - Scanned Image Entry

struct ScannedImage: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let filename: String
    let fileSize: Int64
    let scsiID: Int?
    let imageIndex: Int?
    let isBootDisk: Bool
    let bankCount: Int
    let lastModified: Date
    let parentFolder: String

    var isFloppy: Bool { filename.lowercased().hasPrefix("fd") || filename.hasSuffix(".hfe") || filename.hasSuffix(".dsk") }

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var scsiLabel: String {
        guard let id = scsiID else { return "—" }
        return "ID \(id)"
    }

    static func == (lhs: ScannedImage, rhs: ScannedImage) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Scanner

private enum ImageScanner {
    static let extensions: Set<String> = ["hda", "ez2", "img", "hfe", "dsk", "iso"]

    static func scan(directory: URL) async -> [ScannedImage] {
        var results = [ScannedImage]()
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for case let url as URL in enumerator {
            let ext = url.pathExtension.lowercased()
            guard extensions.contains(ext) else { continue }

            let attrs = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(attrs?.fileSize ?? 0)
            let modified = attrs?.contentModificationDate ?? Date()
            let name = url.lastPathComponent

            let scsiID = parseScsiID(name)
            let imageIndex = parseIndex(name)
            let isBootDisk = checkBootDisk(url)
            let bankCount = estimateBankCount(url)
            let parent = url.deletingLastPathComponent().lastPathComponent

            results.append(ScannedImage(
                url: url,
                filename: name,
                fileSize: size,
                scsiID: scsiID,
                imageIndex: imageIndex,
                isBootDisk: isBootDisk,
                bankCount: bankCount,
                lastModified: modified,
                parentFolder: parent
            ))
        }
        return results.sorted { $0.filename < $1.filename }
    }

    private static func parseScsiID(_ name: String) -> Int? {
        let lower = name.lowercased()
        guard lower.hasPrefix("hd") || lower.hasPrefix("cd") || lower.hasPrefix("fd") else { return nil }
        var digits = ""
        for c in lower.dropFirst(2) {
            if c.isNumber { digits.append(c) }
            else { break }
        }
        return Int(digits)
    }

    private static func parseIndex(_ name: String) -> Int? {
        // HD10_1.hda → index 1
        let parts = name.components(separatedBy: "_")
        if parts.count >= 2, let idx = Int(parts.last?.components(separatedBy: ".").first ?? "") {
            return idx
        }
        return nil
    }

    private static func checkBootDisk(_ url: URL) -> Bool {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? fh.close() }
        let data = (try? fh.read(upToCount: 512)) ?? Data()
        // Check for EMAX II boot signature at offset 0x1E0
        if data.count >= 0x1E2 {
            let sig = Array(data[0x1E0..<0x1E2])
            return sig == [0x55, 0xAA]
        }
        return false
    }

    private static func estimateBankCount(_ url: URL) -> Int {
        // Read BNT offset from header[0x10], entries are 32 bytes
        guard let fh = try? FileHandle(forReadingFrom: url) else { return 0 }
        defer { try? fh.close() }
        guard let header = try? fh.read(upToCount: 512), header.count >= 0x24 else { return 0 }
        
        let bntSector = Int(header.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0x10, as: UInt32.self) })
        let maxBanks = Int(header.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0x14, as: UInt32.self) })
        let bntOffset = UInt64(bntSector * 512)
        
        try? fh.seek(toOffset: bntOffset)
        guard let data = try? fh.read(upToCount: (maxBanks + 1) * 32) else { return 0 }
        
        var count = 0
        for i in 0...(maxBanks) {
            let off = i * 32
            guard off + 32 <= data.count else { break }
            // Non-empty, non-deleted entry
            if data[off] != 0x00 && data[off] != 0xFF { count += 1 }
        }
        return count
    }
}

// MARK: - Main View

struct ImageScannerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var rootDirectory: URL?
    @State private var scanResults: [ScannedImage] = []
    @State private var isScanning = false
    @State private var filterMode: FilterMode = .all
    @State private var searchText = ""
    @State private var selectedImage: ScannedImage?
    @State private var sortBy: SortKey = .name

    enum FilterMode: String, CaseIterable {
        case all = "All"
        case boot = "Boot Disks"
        case data = "Data Disks"
        case floppy = "Floppies"
    }

    enum SortKey: String, CaseIterable {
        case name = "Name"
        case size = "Size"
        case scsiID = "SCSI ID"
        case banks = "Banks"
        case modified = "Modified"
    }

    private var filtered: [ScannedImage] {
        var result = scanResults
        switch filterMode {
        case .all:    break
        case .boot:   result = result.filter { $0.isBootDisk }
        case .data:   result = result.filter { !$0.isBootDisk && !$0.isFloppy }
        case .floppy: result = result.filter { $0.isFloppy }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.filename.localizedCaseInsensitiveContains(searchText) ||
                $0.parentFolder.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortBy {
        case .name:     result.sort { $0.filename < $1.filename }
        case .size:     result.sort { $0.fileSize > $1.fileSize }
        case .scsiID:   result.sort { ($0.scsiID ?? 99) < ($1.scsiID ?? 99) }
        case .banks:    result.sort { $0.bankCount > $1.bankCount }
        case .modified: result.sort { $0.lastModified > $1.lastModified }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Image Scanner",
                subtitle: "Recursively find .hda files in a directory",
                icon: "magnifyingglass",
                onClose: { dismiss() }
            )

            Divider()

            // Toolbar
            toolBar

            Divider()

            if isScanning {
                loadingView
            } else if scanResults.isEmpty && rootDirectory != nil {
                emptyView
            } else if !scanResults.isEmpty {
                resultsTable
            } else {
                placeholderView
            }

            Divider()

            footerButtons
        }
        .frame(width: 820, height: 600)
        .onExitCommand { dismiss() }
    }

    // MARK: - Toolbar

    private var toolBar: some View {
        HStack(spacing: 12) {
            if let dir = rootDirectory {
                Image(systemName: "folder").foregroundStyle(Theme.accent)
                Text(dir.path).font(Theme.Typography.body).lineLimit(1).truncationMode(.middle)
                Button("Change…") { pickDirectory() }.buttonStyle(.bordered)
            } else {
                Button("Select Directory…") { pickDirectory() }
                    .buttonStyle(.bordered)
            }

            Button {
                guard rootDirectory != nil else { return }
                performScan()
            } label: {
                Label("Scan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(rootDirectory == nil || isScanning)

            Spacer()

            // Filter
            Picker("Filter", selection: $filterMode) {
                ForEach(FilterMode.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)

            TextField("Search…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Theme.bgSurface)
    }

    // MARK: - Results Table

    private var resultsTable: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack(spacing: 0) {
                sortHeader("Name", .name, flex: true)
                sortHeader("Size", .size, width: 80)
                sortHeader("SCSI", .scsiID, width: 60)
                sortHeader("Banks", .banks, width: 60)
                Text("Boot").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    .frame(width: 50).padding(.vertical, 8)
                Text("Folder").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    .frame(width: 120).padding(.vertical, 8)
                Text("Actions").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    .frame(width: 80).padding(.vertical, 8)
            }
            .padding(.horizontal, 12)
            .background(Theme.bgSurface)

            Divider()

            List(filtered, selection: Binding(
                get: { selectedImage?.id },
                set: { id in selectedImage = filtered.first(where: { $0.id == id }) }
            )) { img in
                tableRow(img)
                    .tag(img.id)
            }
            .listStyle(.plain)
        }
    }

    private func sortHeader(_ label: String, _ key: SortKey, flex: Bool = false, width: CGFloat? = nil) -> some View {
        Button {
            if sortBy == key { sortBy = .name }
            else { sortBy = key }
        } label: {
            HStack(spacing: 4) {
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                if sortBy == key {
                    Image(systemName: "chevron.down").font(.system(size: 9))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: flex ? .infinity : width, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func tableRow(_ img: ScannedImage) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: img.isFloppy ? "opticaldiscdrive" : "internaldrive")
                    .foregroundStyle(img.isBootDisk ? Theme.accent : .secondary)
                    .frame(width: 16)
                Text(img.filename).font(Theme.Typography.body).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(img.sizeFormatted)
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)

            Text(img.scsiLabel)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.cyan)
                .frame(width: 60, alignment: .center)

            Text(img.bankCount > 0 ? "\(img.bankCount)" : "—")
                .font(Theme.Typography.caption)
                .foregroundStyle(img.bankCount > 0 ? .primary : .tertiary)
                .frame(width: 60, alignment: .center)

            Group {
                if img.isBootDisk {
                    Image(systemName: "star.fill").foregroundStyle(Theme.amber)
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            .frame(width: 50, alignment: .center)

            Text(img.parentFolder)
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)

            HStack(spacing: 8) {
                Button {
                    openInEmaxForge(img)
                } label: {
                    Image(systemName: "arrow.right.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                .help("Open in EmaxForge")

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([img.url])
                } label: {
                    Image(systemName: "folder")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Reveal in Finder")
            }
            .frame(width: 80, alignment: .center)
        }
        .padding(.vertical, 3)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.1)
            Text("Scanning directory…").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray").font(.system(size: 36)).foregroundStyle(.tertiary)
            Text("No disk images found in this directory").font(.headline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass").font(.system(size: 40)).foregroundStyle(.tertiary)
            Text("Select a directory and click Scan").font(.headline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footerButtons: some View {
        HStack(spacing: 12) {
            Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            Spacer()
            if !scanResults.isEmpty {
                Text("\(filtered.count) of \(scanResults.count) images")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select root directory to scan"
        if panel.runModal() == .OK, let url = panel.url {
            rootDirectory = url
            performScan()
        }
    }

    private func performScan() {
        guard let dir = rootDirectory else { return }
        isScanning = true
        scanResults = []
        Task {
            let results = await ImageScanner.scan(directory: dir)
            await MainActor.run {
                scanResults = results
                isScanning = false
            }
        }
    }

    private func openInEmaxForge(_ img: ScannedImage) {
        // Set the parent as volume and select the image
        let parentURL = img.url.deletingLastPathComponent()
        let volume = MountedVolume(
            url: parentURL,
            name: parentURL.lastPathComponent,
            isRemovable: false,
            totalSize: 0,
            freeSpace: 0
        )
        appState.selectedVolume = volume
        appState.refreshImages()
        dismiss()
    }
}
