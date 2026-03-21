import SwiftUI
import UniformTypeIdentifiers

// MARK: - HFE Metadata Model

struct HFEMetadata {
    let tracks: Int
    let sides: Int
    let formatName: String
    let bitRate: Int
    let floppyRPM: Int
    let encodingMode: Int
    let fileSizeBytes: Int
}

// MARK: - HFE Parser

private enum HFEParser {
    // HFEv1 header is 512 bytes at offset 0
    static func parseMetadata(url: URL) throws -> HFEMetadata {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count >= 512 else {
            throw NSError(domain: "HFE", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "File too small to be a valid HFE image"])
        }
        // HEADERSIGNATURE: "HXCPICFE" at offset 0
        let sig = String(bytes: data[0..<8], encoding: .ascii) ?? ""
        guard sig.hasPrefix("HXC") else {
            throw NSError(domain: "HFE", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Not a valid HFE file (bad signature: \(sig))"])
        }
        let tracks     = Int(data[9])
        let sides      = Int(data[10])
        let encoding   = Int(data[11])
        let bitRate     = Int(data[13]) | (Int(data[14]) << 8)
        let rpm        = Int(data[15]) | (Int(data[16]) << 8)

        let formatNames: [Int: String] = [
            0x00: "ISOIBM_MFM",
            0x01: "AMIGA_MFM",
            0x02: "ISOIBM_FM",
            0x03: "EMU_FM",
            0x04: "Unknown",
            0xFF: "DISABLE_FLOPPYMODE"
        ]
        let formatName = formatNames[encoding] ?? "Unknown (\(encoding))"

        return HFEMetadata(
            tracks: tracks,
            sides: sides,
            formatName: formatName,
            bitRate: bitRate,
            floppyRPM: rpm,
            encodingMode: encoding,
            fileSizeBytes: data.count
        )
    }

    /// Extract raw track data and write flat IMG
    static func convert(source: URL, destination: URL) async throws {
        let data = try Data(contentsOf: source, options: .mappedIfSafe)
        guard data.count >= 512 else {
            throw NSError(domain: "HFE", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "File too small"])
        }
        // Try CLI first
        let cliOutput = try? await callCLI(command: "convert-hfe",
                                            args: [source.path, "--output", destination.path])
        if cliOutput != nil { return }

        // Fallback: basic raw extraction (HFEv1 interleaved track data)
        let tracks = Int(data[9])
        let sides  = Int(data[10])
        guard tracks > 0, sides > 0 else {
            throw NSError(domain: "HFE", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid track/side count"])
        }

        // Track lookup table at offset 0x200 (256 * 4 bytes each)
        var rawTracks = [Data]()
        for t in 0..<tracks {
            let lutOffset = 0x200 + t * 4
            guard lutOffset + 4 <= data.count else { break }
            let trackOffset = (Int(data[lutOffset]) | (Int(data[lutOffset+1]) << 8)) * 512
            let trackLen    = (Int(data[lutOffset+2]) | (Int(data[lutOffset+3]) << 8))
            guard trackOffset + trackLen <= data.count else { break }
            rawTracks.append(data[trackOffset..<(trackOffset+trackLen)])
        }

        var output = Data()
        for track in rawTracks { output.append(track) }
        try output.write(to: destination)
    }
}

// MARK: - CLI helper

private func callCLI(command: String, args: [String]) async throws -> String {
    let paths = [
        "/usr/local/bin/cli-anything-emaxforge",
        "\(NSHomeDirectory())/bin/cli-anything-emaxforge",
        "\(NSHomeDirectory())/.local/bin/cli-anything-emaxforge"
    ]
    guard let cliPath = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
        throw NSError(domain: "CLI", code: 1, userInfo: [NSLocalizedDescriptionKey: "CLI not found"])
    }
    return try await withCheckedThrowingContinuation { cont in
        DispatchQueue.global().async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            process.arguments = [command] + args
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    cont.resume(returning: out)
                } else {
                    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "CLI error"
                    cont.resume(throwing: NSError(domain: "CLI", code: Int(process.terminationStatus),
                                                   userInfo: [NSLocalizedDescriptionKey: err]))
                }
            } catch {
                cont.resume(throwing: error)
            }
        }
    }
}

// MARK: - Main View

struct HFEConverterSheet: View {
    @Environment(\.dismiss) var dismiss

    @State private var sourceURL: URL?
    @State private var outputURL: URL?
    @State private var metadata: HFEMetadata?
    @State private var isConverting = false
    @State private var convertDone = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "HFE → IMG Converter",
                subtitle: "Convert HFE floppy images to raw IMG format",
                icon: "opticaldiscdrive",
                onClose: { dismiss() }
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sourceSection
                    outputSection
                    if let meta = metadata { metadataSection(meta) }
                    if let err = errorMessage { errorBanner(err) }
                    if convertDone { successBanner }
                }
                .padding()
            }

            Divider()

            footerButtons
        }
        .frame(width: 600, height: 500)
        .onExitCommand { dismiss() }
    }

    // MARK: - Sections

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("SOURCE HFE FILE")
            if let url = sourceURL {
                HStack(spacing: 10) {
                    Image(systemName: "opticaldiscdrive").foregroundStyle(Theme.accent)
                    Text(url.lastPathComponent).font(Theme.Typography.body).lineLimit(1)
                    Spacer()
                    Button("Change…") { pickSource() }.buttonStyle(.bordered)
                }
                .padding(12)
                .background(Theme.bgCard)
                .cornerRadius(8)
            } else {
                Button { pickSource() } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Select .hfe File…")
                    }
                    .frame(maxWidth: .infinity).padding(12)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("OUTPUT IMG FILE")
            if let url = outputURL {
                HStack(spacing: 10) {
                    Image(systemName: "doc").foregroundStyle(.secondary)
                    Text(url.lastPathComponent).font(Theme.Typography.body).lineLimit(1)
                    Spacer()
                    Button("Change…") { pickOutput() }.buttonStyle(.bordered)
                }
                .padding(12)
                .background(Theme.bgCard)
                .cornerRadius(8)
            } else {
                Button { pickOutput() } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Choose Output Location…")
                    }
                    .frame(maxWidth: .infinity).padding(12)
                }
                .buttonStyle(.bordered)
                .disabled(sourceURL == nil)
            }
        }
    }

    private func metadataSection(_ meta: HFEMetadata) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("HFE METADATA")
            VStack(spacing: 0) {
                metaRow("Tracks", "\(meta.tracks)")
                Divider()
                metaRow("Sides", "\(meta.sides)")
                Divider()
                metaRow("Format", meta.formatName)
                Divider()
                metaRow("Bit Rate", "\(meta.bitRate) kbps")
                Divider()
                metaRow("RPM", "\(meta.floppyRPM)")
                Divider()
                metaRow("File Size", ByteCountFormatter.string(fromByteCount: Int64(meta.fileSizeBytes), countStyle: .file))
            }
            .background(Theme.bgCard)
            .cornerRadius(8)
        }
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(Theme.Typography.body).foregroundStyle(.secondary).frame(width: 120, alignment: .leading)
            Text(value).font(Theme.Typography.body)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.danger)
            Text(msg).font(Theme.Typography.body).foregroundStyle(Theme.danger)
        }
        .padding(12)
        .background(Theme.danger.opacity(0.1))
        .cornerRadius(8)
    }

    private var successBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
            Text("Conversion complete! IMG file saved.").font(Theme.Typography.body)
        }
        .padding(12)
        .background(Theme.success.opacity(0.1))
        .cornerRadius(8)
    }

    private var footerButtons: some View {
        HStack(spacing: 12) {
            Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            Spacer()
            if isConverting {
                ProgressView().scaleEffect(0.7)
                Text("Converting…").font(Theme.Typography.body).foregroundStyle(.secondary)
            }
            Button("Convert") { performConversion() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(sourceURL == nil || outputURL == nil || isConverting)
                .keyboardShortcut(.defaultAction)
        }
        .padding()
    }

    // MARK: - Helpers

    private func sectionLabel(_ t: String) -> some View {
        Text(t).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).tracking(1)
    }

    private func pickSource() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "hfe")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            sourceURL = url
            errorMessage = nil
            convertDone = false
            // Auto-suggest output
            if outputURL == nil {
                let suggested = url.deletingPathExtension().appendingPathExtension("img")
                outputURL = suggested
            }
            // Parse metadata
            Task {
                if let meta = try? HFEParser.parseMetadata(url: url) {
                    await MainActor.run { metadata = meta }
                }
            }
        }
    }

    private func pickOutput() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "img")].compactMap { $0 }
        if let src = sourceURL {
            panel.nameFieldStringValue = src.deletingPathExtension().lastPathComponent + ".img"
        }
        if panel.runModal() == .OK { outputURL = panel.url }
    }

    private func performConversion() {
        guard let src = sourceURL, let dst = outputURL else { return }
        isConverting = true
        errorMessage = nil
        convertDone = false
        Task {
            do {
                try await HFEParser.convert(source: src, destination: dst)
                await MainActor.run {
                    isConverting = false
                    convertDone = true
                }
            } catch {
                await MainActor.run {
                    isConverting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
