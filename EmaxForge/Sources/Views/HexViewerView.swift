import SwiftUI

/// Dedicated hex viewer for disk image inspection
struct HexViewerView: View {
    @EnvironmentObject var appState: AppState
    let image: DiskImage

    @State private var hexDump = ""
    @State private var offset: Int = 0
    @State private var isLoading = false
    private let bytesPerPage = 512 * 16  // 8KB per page

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hex Viewer")
                        .font(.headline)
                    Text(image.filename)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Offset controls
                HStack(spacing: 8) {
                    Button {
                        offset = max(0, offset - bytesPerPage)
                        loadHex()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(offset == 0)
                    .buttonStyle(.bordered)

                    Text("Offset \(String(format: "0x%X", offset))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Button {
                        offset += bytesPerPage
                        loadHex()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(hexDump, forType: .string)
                    appState.addActivity("Hex dump copied to clipboard", type: .info)
                } label: {
                    Label("Copy", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)

            Divider()

            // Hex content
            if isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if hexDump.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("Cannot read file")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.horizontal, .vertical]) {
                    Text(hexDump)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(16)
                }
                .background(Color.black.opacity(0.25))
            }
        }
        .onAppear { loadHex() }
    }

    private func loadHex() {
        isLoading = true
        let url = image.url
        let pageOffset = offset
        let pageSize = bytesPerPage

        Task.detached(priority: .userInitiated) {
            let result = await Task.detached {
                guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
                defer { handle.closeFile() }
                handle.seek(toFileOffset: UInt64(pageOffset))
                let data = handle.readData(ofLength: pageSize)
                return formatHexDump(data, startOffset: pageOffset)
            }.value

            await MainActor.run {
                hexDump = result
                isLoading = false
            }
        }
    }

    private func formatHexDump(_ data: Data, startOffset: Int) -> String {
        var lines: [String] = []
        let bpl = 16
        for i in stride(from: 0, to: data.count, by: bpl) {
            let end = min(i + bpl, data.count)
            let chunk = data[i..<end]
            let addr = String(format: "%08X", startOffset + i)
            let hex = chunk.map { String(format: "%02X", $0) }.joined(separator: " ")
            let ascii = chunk.map { (0x20...0x7E).contains($0) ? String(UnicodeScalar($0)) : "." }.joined()
            let padded = hex.padding(toLength: bpl * 3 - 1, withPad: " ", startingAt: 0)
            lines.append("\(addr)  \(padded)  |\(ascii)|")
        }
        return lines.joined(separator: "\n")
    }
}
