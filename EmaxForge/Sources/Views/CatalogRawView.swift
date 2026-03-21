import SwiftUI
import UniformTypeIdentifiers

// MARK: - Catalog Entry

private struct RawCatalogEntry: Identifiable {
    let id: Int  // entry index
    let offset: Int
    let rawBytes: [UInt8]  // 64 bytes

    var name: String {
        let nameBytes = rawBytes.prefix(16).prefix(while: { $0 != 0 })
        return String(bytes: nameBytes, encoding: .ascii) ?? String(bytes: nameBytes, encoding: .isoLatin1) ?? "?"
    }

    var isActive: Bool { rawBytes[0] != 0x00 && rawBytes[0] != 0xFF }

    func hexString(perLine: Int = 16) -> String {
        var lines = [String]()
        for start in stride(from: 0, to: rawBytes.count, by: perLine) {
            let chunk = Array(rawBytes[start..<min(start+perLine, rawBytes.count)])
            let hex = chunk.map { String(format: "%02X", $0) }.joined(separator: " ")
            let ascii = chunk.map { c -> Character in
                (c >= 32 && c < 127) ? Character(UnicodeScalar(c)) : "."
            }
            lines.append(String(format: "%04X: %-47s  %@",
                                start, hex, String(ascii)))
        }
        return lines.joined(separator: "\n")
    }

    func asciiString() -> String {
        rawBytes.map { c -> Character in
            (c >= 32 && c < 127) ? Character(UnicodeScalar(c)) : "."
        }.map(String.init).joined()
    }
}

enum CatalogDisplayMode: String, CaseIterable {
    case hex = "Hex"
    case ascii = "ASCII"
    case both = "Both"
}

// MARK: - Main View

struct CatalogRawView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var selectedImage: URL?
    @State private var entries: [RawCatalogEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var displayMode: CatalogDisplayMode = .both
    @State private var searchText = ""
    @State private var selectedEntry: RawCatalogEntry?

    private var filtered: [RawCatalogEntry] {
        guard !searchText.isEmpty else { return entries }
        let q = searchText.lowercased()
        return entries.filter {
            $0.name.lowercased().contains(q) ||
            String(format: "0x%04X", $0.offset).lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Raw Catalog Viewer",
                subtitle: "Developer tool — hex/ASCII dump of catalog entries",
                icon: "0.square",
                onClose: { dismiss() }
            )

            Divider()

            // Toolbar row
            HStack(spacing: 12) {
                if let url = selectedImage {
                    Image(systemName: "internaldrive").foregroundStyle(Theme.accent)
                    Text(url.lastPathComponent).font(Theme.Typography.body).lineLimit(1)
                    Button("Change…") { pickImage() }.buttonStyle(.bordered)
                } else {
                    Button("Select Disk Image…") { pickImage() }.buttonStyle(.bordered)
                }

                Spacer()

                Picker("Display", selection: $displayMode) {
                    ForEach(CatalogDisplayMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                TextField("Search…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Theme.bgSurface)

            Divider()

            if isLoading {
                loadingView
            } else if entries.isEmpty && selectedImage != nil {
                emptyView
            } else if !entries.isEmpty {
                contentView
            } else {
                placeholderView
            }

            Divider()

            footerButtons
        }
        .frame(width: 800, height: 620)
        .onExitCommand { dismiss() }
    }

    // MARK: - Content

    private var contentView: some View {
        HSplitView {
            // Entry list
            VStack(spacing: 0) {
                HStack {
                    Text("ENTRY").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                    Text("OFFSET").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                        .frame(width: 60)
                    Text("NAME").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.bgSurface)

                Divider()

                List(filtered, selection: Binding(
                    get: { selectedEntry?.id },
                    set: { id in selectedEntry = filtered.first(where: { $0.id == id }) }
                )) { entry in
                    HStack(spacing: 10) {
                        Text("\(entry.id)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .trailing)
                        Text(String(format: "0x%04X", entry.offset))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.cyan)
                            .frame(width: 55)
                        Text(entry.name.isEmpty ? "(empty)" : entry.name)
                            .font(.system(size: 12))
                            .foregroundStyle(entry.isActive ? .primary : .tertiary)
                        Spacer()
                        if entry.isActive {
                            Circle().fill(Theme.success).frame(width: 6, height: 6)
                        }
                    }
                    .padding(.vertical, 2)
                    .tag(entry.id)
                }
                .listStyle(.plain)
            }
            .frame(minWidth: 260, maxWidth: 300)

            // Detail panel
            VStack(spacing: 0) {
                if let entry = selectedEntry {
                    entryDetail(entry)
                } else {
                    Text("Select an entry")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func entryDetail(_ entry: RawCatalogEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Entry \(entry.id)").font(.system(size: 13, weight: .bold))
                    Text(String(format: "Offset: 0x%04X", entry.offset))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Copy") { copyEntry(entry) }
                    .buttonStyle(.bordered)
                    .font(.caption)
            }
            .padding()

            Divider()

            ScrollView {
                Text(displayText(entry))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func displayText(_ entry: RawCatalogEntry) -> String {
        switch displayMode {
        case .hex:   return entry.hexString()
        case .ascii: return entry.asciiString()
        case .both:  return entry.hexString()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.1)
            Text("Reading catalog…").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray").font(.system(size: 32)).foregroundStyle(.tertiary)
            Text("No catalog entries found").font(.headline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "0.square").font(.system(size: 40)).foregroundStyle(.tertiary)
            Text("Select a disk image to view its raw catalog")
                .font(.headline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footerButtons: some View {
        HStack {
            Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            Spacer()
            if !entries.isEmpty {
                Text("\(filtered.count) of \(entries.count) entries")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                Button("Export All…") { exportAll() }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "hda")].compactMap { $0 }
        if panel.runModal() == .OK, let url = panel.url {
            selectedImage = url
            loadCatalog(url: url)
        }
    }

    private func loadCatalog(url: URL) {
        isLoading = true
        errorMessage = nil
        entries = []
        Task {
            do {
                let data = try Data(contentsOf: url)
                // Catalog offset from header field 0x10 (sector number)
                let bntStartSector: Int = data.count >= 0x14
                    ? Int(data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0x10, as: UInt32.self) })
                    : 0x08  // fallback
                let caStartSector: Int = data.count >= 0x24
                    ? Int(data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0x20, as: UInt32.self) })
                    : 0x62
                let catalogOffset = bntStartSector * 512
                let entrySize = 32  // BNT entries are 32 bytes, NOT 64!
                let maxEntries = (caStartSector - bntStartSector) * 512 / entrySize
                var loaded = [RawCatalogEntry]()
                for i in 0..<maxEntries {
                    let off = catalogOffset + i * entrySize
                    guard off + entrySize <= data.count else { break }
                    let bytes = Array(data[off..<(off+entrySize)])
                    loaded.append(RawCatalogEntry(id: i, offset: off, rawBytes: bytes))
                }
                await MainActor.run {
                    entries = loaded
                    isLoading = false
                    selectedEntry = loaded.first(where: { $0.isActive })
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func copyEntry(_ entry: RawCatalogEntry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.hexString(), forType: .string)
    }

    private func exportAll() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "catalog_dump.txt"
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        let text = filtered.map { e in
            "Entry \(e.id) @ 0x\(String(format: "%04X", e.offset)) [\(e.name)]:\n\(e.hexString())"
        }.joined(separator: "\n\n")
        try? text.write(to: dest, atomically: true, encoding: .utf8)
    }
}
