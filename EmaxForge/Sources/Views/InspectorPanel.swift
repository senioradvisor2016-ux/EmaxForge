import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Deep inspector panel for bank analysis
struct InspectorPanel: View {
    let bank: BankCatalogEntry
    let imageURL: URL
    
    @State private var selectedTab: Tab = .overview
    @State private var bankData: Data?
    @State private var parsedBank: EmaxIIBankData?
    @State private var sampleData: BankSampleData?
    @State private var isLoading = true
    
    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case structure = "Structure"
        case samples = "Samples"
        case memory = "Memory"
        case raw = "Raw"
        
        var icon: String {
            switch self {
            case .overview: return "info.circle"
            case .structure: return "list.bullet.rectangle"
            case .samples: return "waveform"
            case .memory: return "chart.pie"
            case .raw: return "0.square"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("View", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            // Content
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading bank...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    switch selectedTab {
                    case .overview:
                        OverviewTab(bank: bank, parsed: parsedBank, samples: sampleData)
                    case .structure:
                        StructureTab(bank: bank, parsed: parsedBank, samples: sampleData)
                    case .samples:
                        SamplesTab(samples: sampleData, bank: bank, imageURL: imageURL)
                    case .memory:
                        MemoryTab(bank: bank, bankData: bankData)
                    case .raw:
                        RawDataTab(bankData: bankData)
                    }
                }
            }
        }
        .frame(width: 350)
        .task {
            await loadBankData()
        }
    }
    
    // MARK: - Loading
    
    private func loadBankData() async {
        isLoading = true
        
        do {
            // Parse file system
            let fs = try EmaxIIParser.parseHDImage(at: imageURL)
            
            // Read bank data
            let imageData = try Data(contentsOf: imageURL)
            let clusterSize = fs.clusterSize
            let clusterAreaOffset = Int(fs.clusterAreaStartOffset)
            var data = Data()
            
            for cluster in bank.clusterChain {
                let offset = clusterAreaOffset + (cluster - 1) * clusterSize
                guard offset + clusterSize <= imageData.count else { break }
                data.append(imageData[offset..<offset + clusterSize])
            }
            
            self.bankData = data
            self.parsedBank = EmaxIIParser.parseBankData(data)
            self.sampleData = EmaxIIParser.extractSampleData(from: data)
            
        } catch {
            print("Failed to load bank: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Overview Tab

struct OverviewTab: View {
    let bank: BankCatalogEntry
    let parsed: EmaxIIBankData?
    let samples: BankSampleData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Bank info
            SectionHeader("Bank Information")
            
            InfoCard {
                InfoItem("Name", bank.name)
                InfoItem("Catalog Index", "\(bank.catalogIndex)")
                InfoItem("Start Cluster", "\(bank.startCluster)")
                InfoItem("Size", bank.formattedSize)
                InfoItem("Cluster Chain", "\(bank.clusterChain.count) clusters")
            }
            
            // Preset info
            if let parsed = parsed {
                SectionHeader("Content")
                
                InfoCard {
                    InfoItem("Presets", "\(parsed.numPresets)")
                    InfoItem("Samples", "\(parsed.numSamples)")
                    InfoItem("Sample Data", formatBytes(parsed.sampleDataSize))
                    if let samples = samples {
                        InfoItem("Duration", String(format: "%.1f s", samples.duration))
                    }
                }
            }
            
            // Flags
            if bank.flags != 0 {
                SectionHeader("Flags")
                
                InfoCard {
                    InfoItem("Raw Value", String(format: "0x%02X", bank.flags))
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Structure Tab

struct StructureTab: View {
    let bank: BankCatalogEntry
    let parsed: EmaxIIBankData?
    let samples: BankSampleData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Bank Structure")
            
            // Memory layout
            InfoCard {
                MemoryRegion("Header", offset: 0x0, size: 0x200, color: .blue)
                MemoryRegion("Preset Area", offset: 0x200, size: 0x10000, color: .purple)
                MemoryRegion("Sample Params", offset: 0x10200, size: 0x10000, color: .orange)
                
                if let parsed = parsed {
                    MemoryRegion("Sample Data", offset: 0x20000, size: parsed.sampleDataSize, color: .green)
                }
            }
            
            // Cluster chain
            SectionHeader("Cluster Chain")
            
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(Array(bank.clusterChain.enumerated()), id: \.offset) { index, cluster in
                        VStack(spacing: 2) {
                            Text("\(cluster)")
                                .font(.caption2.monospacedDigit())
                                .fontWeight(.medium)
                            Rectangle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 30, height: 20)
                        }
                    }
                }
                .padding(8)
            }
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Samples Tab

struct SamplesTab: View {
    let samples: BankSampleData?
    var bank: BankCatalogEntry? = nil
    var imageURL: URL? = nil

    @State private var extractingIndex: Int? = nil
    @State private var extractSuccess: Bool = false
    @State private var extractError: String? = nil
    @State private var trimmingIndex: Int? = nil
    @State private var trimResult: String? = nil
    @State private var renamingIndex: Int? = nil
    @State private var renameText: String = ""
    @State private var renameError: String? = nil

    @StateObject private var samplePlayer = SamplePlayer()

    private let extractor = SampleExtractorService()
    private let trimmer = SampleTrimmerService()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Samples")
            
            if let samples = samples {
                ForEach(samples.samples) { sample in
                    VStack(alignment: .leading, spacing: 8) {
                        // Sample info
                        HStack {
                            Text(sample.name)
                                .font(.headline)
                            Spacer()
                            Text("#\(sample.index + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label("\(sample.sampleRate) Hz", systemImage: "waveform")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.2f s", sample.duration))
                                .font(.caption.monospacedDigit())
                        }
                        
                        HStack {
                            Text("\(sample.pcmData.count / 1024) KB")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            if sample.loopStart != nil {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Divider()
                        
                        // Action buttons
                        HStack(spacing: 8) {
                            Button {
                                extractSample(sample)
                            } label: {
                                Label("Extract", systemImage: "arrow.down.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .disabled(extractingIndex == sample.index)

                            Button {
                                playSample(sample)
                            } label: {
                                let isThis = samplePlayer.isPlaying
                                Label(isThis ? "Stop" : "Play",
                                      systemImage: isThis ? "stop.fill" : "play.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .tint(samplePlayer.isPlaying ? .red : nil)

                            Button {
                                trimSample(sample)
                            } label: {
                                Label("Trim", systemImage: "scissors")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .disabled(trimmingIndex == sample.index)

                            if bank != nil && imageURL != nil {
                                Button {
                                    renamingIndex = sample.index
                                    renameText = sample.name
                                    renameError = nil
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        // Inline rename UI
                        if renamingIndex == sample.index, let bank, let imageURL {
                            HStack(spacing: 6) {
                                TextField("New name (max 15 chars)", text: $renameText)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.caption)
                                    .frame(maxWidth: 160)
                                    .onSubmit { commitRename(sample: sample, bank: bank, imageURL: imageURL) }
                                Button("Save") { commitRename(sample: sample, bank: bank, imageURL: imageURL) }
                                    .font(.caption)
                                    .buttonStyle(.borderedProminent)
                                Button("Cancel") { renamingIndex = nil }
                                    .font(.caption)
                                    .buttonStyle(.borderless)
                            }
                            if let err = renameError {
                                Text(err).font(.caption2).foregroundStyle(.red)
                            }
                        }
                        
                        // Status
                        if extractingIndex == sample.index {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text("Extracting...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if trimmingIndex == sample.index {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text("Trimming...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if extractSuccess && extractingIndex == sample.index {
                            Label("Extracted successfully!", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        if let result = trimResult, trimmingIndex == nil {
                            Label(result, systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        if let error = extractError, extractingIndex == sample.index {
                            Label(error, systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(8)
                }
            } else {
                Text("No sample data")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func extractSample(_ sample: BankSampleData.SampleEntry) {
        extractingIndex = sample.index
        extractSuccess = false
        extractError = nil
        
        Task {
            do {
                // Show save panel
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.wav]
                savePanel.nameFieldStringValue = "\(sample.name).wav"
                savePanel.message = "Export sample as WAV"
                
                guard await savePanel.begin() == .OK,
                      let outputURL = savePanel.url else {
                    await MainActor.run {
                        extractingIndex = nil
                    }
                    return
                }
                
                // Extract sample
                _ = try await extractor.extractSample(sample, to: outputURL)
                
                await MainActor.run {
                    extractSuccess = true
                    extractError = nil
                    extractingIndex = nil
                }
                
                // Clear success message after 3s
                try await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    extractSuccess = false
                }
            } catch {
                await MainActor.run {
                    extractError = error.localizedDescription
                    extractingIndex = nil
                }
            }
        }
    }
    
    private func playSample(_ sample: BankSampleData.SampleEntry) {
        samplePlayer.togglePlayback(pcmData: sample.pcmData, sampleRate: Double(sample.sampleRate))
    }
    
    private func trimSample(_ sample: BankSampleData.SampleEntry) {
        trimmingIndex = sample.index
        trimResult = nil
        
        Task {
            do {
                // First, extract to temp file
                let tempInput = FileManager.default.temporaryDirectory
                    .appendingPathComponent("trim_input_\(sample.name).wav")
                
                _ = try await extractor.extractSample(sample, to: tempInput)
                
                // Show save panel
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.wav]
                savePanel.nameFieldStringValue = "\(sample.name)_trimmed.wav"
                savePanel.message = "Save trimmed sample"
                
                guard await savePanel.begin() == .OK,
                      let outputURL = savePanel.url else {
                    await MainActor.run {
                        trimmingIndex = nil
                    }
                    return
                }
                
                // Trim
                let result = try await trimmer.trimSample(
                    input: tempInput,
                    output: outputURL,
                    threshold: 10
                )
                
                await MainActor.run {
                    trimResult = result.summary
                    trimmingIndex = nil
                }
                
                // Clear message after 3s
                try await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    trimResult = nil
                }
                
                // Clean up temp
                try? FileManager.default.removeItem(at: tempInput)
            } catch {
                await MainActor.run {
                    trimResult = "Trim failed: \(error.localizedDescription)"
                    trimmingIndex = nil
                }
            }
        }
    }

    private func commitRename(sample: BankSampleData.SampleEntry,
                               bank: BankCatalogEntry,
                               imageURL: URL) {
        let trimmed = String(renameText.prefix(15)).trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            renameError = "Name cannot be empty"
            return
        }
        Task {
            do {
                try SampleParamWriteService.renameSample(
                    at: sample.index,
                    newName: trimmed,
                    in: bank,
                    imageURL: imageURL
                )
                await MainActor.run {
                    renamingIndex = nil
                    renameError = nil
                }
            } catch {
                await MainActor.run {
                    renameError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Memory Tab

struct MemoryTab: View {
    let bank: BankCatalogEntry
    let bankData: Data?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Memory Usage")
            
            if let data = bankData {
                // Pie chart representation
                VStack(spacing: 12) {
                    HStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                        Text("Header: \(formatBytes(0x200))")
                            .font(.caption)
                        Spacer()
                        Text("\(100 * 0x200 / data.count)%")
                            .font(.caption.monospacedDigit())
                    }
                    
                    HStack {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 12, height: 12)
                        Text("Presets: \(formatBytes(0x10000))")
                            .font(.caption)
                        Spacer()
                        Text("\(100 * 0x10000 / data.count)%")
                            .font(.caption.monospacedDigit())
                    }
                    
                    HStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 12, height: 12)
                        Text("Sample Params: \(formatBytes(0x10000))")
                            .font(.caption)
                        Spacer()
                        Text("\(100 * 0x10000 / data.count)%")
                            .font(.caption.monospacedDigit())
                    }
                    
                    if data.count > 0x20000 {
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 12, height: 12)
                            Text("Sample Data: \(formatBytes(data.count - 0x20000))")
                                .font(.caption)
                            Spacer()
                            Text("\(100 * (data.count - 0x20000) / data.count)%")
                                .font(.caption.monospacedDigit())
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                // Total
                SectionHeader("Total")
                InfoCard {
                    InfoItem("Bank Size", formatBytes(data.count))
                    InfoItem("Clusters Used", "\(bank.clusterChain.count)")
                    InfoItem("Efficiency", String(format: "%.1f%%", Double(data.count) / Double(bank.clusterChain.count * 6144) * 100))
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Raw Data Tab

struct RawDataTab: View {
    let bankData: Data?
    
    @State private var hexOffset = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Raw Data (Hex)")
            
            if let data = bankData {
                Text("Size: \(formatBytes(data.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Hex dump (first 512 bytes)
                Text(hexDump(data, offset: hexOffset, length: 512))
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.green)
                    .cornerRadius(8)
                
                HStack {
                    Button("Header") { hexOffset = 0 }
                    Button("Presets") { hexOffset = 0x200 }
                    Button("Samples") { hexOffset = 0x10200 }
                    Button("Data") { hexOffset = 0x20000 }
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func hexDump(_ data: Data, offset: Int, length: Int) -> String {
        let endOffset = min(offset + length, data.count)
        var result = ""
        
        for i in stride(from: offset, to: endOffset, by: 16) {
            result += String(format: "%08X: ", i)
            
            for j in 0..<16 {
                if i + j < endOffset {
                    result += String(format: "%02X ", data[i + j])
                } else {
                    result += "   "
                }
            }
            
            result += " "
            
            for j in 0..<16 {
                if i + j < endOffset {
                    let byte = data[i + j]
                    let char = (byte >= 32 && byte < 127) ? String(UnicodeScalar(byte)) : "."
                    result += char
                }
            }
            
            result += "\n"
        }
        
        return result
    }
}

// MARK: - Helper Views

struct SectionHeader: View {
    let title: String
    
    init(_ title: String) {
        self.title = title
    }
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
    }
}

struct InfoCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

struct InfoItem: View {
    let label: String
    let value: String
    
    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct MemoryRegion: View {
    let name: String
    let offset: Int
    let size: Int
    let color: Color
    
    init(_ name: String, offset: Int, size: Int, color: Color) {
        self.name = name
        self.offset = offset
        self.size = size
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(color.opacity(0.3))
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(String(format: "0x%X - %@", offset, formatBytes(size)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Helpers

private func formatBytes(_ bytes: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
}

// MARK: - Preview (commented out)
// #Preview {
//     InspectorPanel(bank: ..., imageURL: ...)
// }
