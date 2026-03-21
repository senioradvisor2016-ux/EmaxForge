# EmaxForge HIGH Priority Feature Roadmap

**Target:** v1.0 Feature Complete
**Total Effort:** 44-60 hours
**Timeline:** Flexible (your pace)

---

## Implementation Order (Dependency-Based)

### Phase 1: Foundation (Week 1)
**Feature:** Disk Verification (10-15h)
**Why first:** Catches errors early, builds confidence for other features

### Phase 2: Data Access (Week 2)
**Feature:** Sample Extraction (8-12h)
**Why second:** Needs verified disk structure, enables other features

### Phase 3: Browsing UI (Week 3)
**Features:** Show Samples + Show Presets (14-18h combined)
**Why third:** Builds on extraction/parsing logic

### Phase 4: Inspector (Week 4)
**Feature:** Show Bank Details (10-15h)
**Why last:** Culmination of all data access patterns

---

## Feature 1: Disk Verification ✅

**Goal:** Validate disk image integrity before ZuluSCSI write

**Checks to implement:**
1. ✅ Boot signature (0x7882 at 0x1FE) - DONE!
2. FAT structure validation
3. Catalog entry validation
4. Bank file integrity
5. Cross-reference checks (FAT ↔ Catalog ↔ Files)

**UI Design:**
- "Verify Disk" button in toolbar
- Progress sheet with live checks
- Results list with ✅/❌ indicators
- Error messages with fix suggestions
- "Verify before write" preference option

**Implementation:**

```swift
// Sources/Utilities/DiskVerifier.swift
struct DiskVerifier {
    struct ValidationResult {
        enum Status { case pass, warning, error }
        let check: String
        let status: Status
        let message: String
        let fixSuggestion: String?
    }
    
    func verify(image: DiskImage) async -> [ValidationResult] {
        var results: [ValidationResult] = []
        
        // 1. Boot signature
        results.append(verifyBootSignature(image))
        
        // 2. FAT structure
        results.append(verifyFAT(image))
        
        // 3. Catalog
        results.append(verifyCatalog(image))
        
        // 4. Banks
        results.append(contentsOf: verifyBanks(image))
        
        // 5. Cross-references
        results.append(contentsOf: verifyCrossReferences(image))
        
        return results
    }
    
    private func verifyBootSignature(_ image: DiskImage) -> ValidationResult {
        // Read bytes at 0x1FE-0x1FF
        // Check for 0x78 0x82
    }
    
    private func verifyFAT(_ image: DiskImage) -> ValidationResult {
        // Check FAT[0] = 0x8000
        // Check FAT[1] = 0x7FFF (if OS present)
        // Validate cluster chains
    }
    
    // ... etc
}
```

**View:**
```swift
// Sources/Views/VerifyDiskSheet.swift
struct VerifyDiskSheet: View {
    @State private var results: [DiskVerifier.ValidationResult] = []
    @State private var isVerifying = false
    
    var body: some View {
        VStack {
            if isVerifying {
                ProgressView("Verifying disk...")
            } else {
                List(results) { result in
                    HStack {
                        Image(systemName: result.icon)
                            .foregroundColor(result.color)
                        VStack(alignment: .leading) {
                            Text(result.check)
                            Text(result.message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .task {
            await runVerification()
        }
    }
}
```

**Time estimate:** 10-15 hours
- Core logic: 6-8h
- UI: 2-3h
- Testing: 2-4h

---

## Feature 2: Sample Extraction ✅

**Goal:** Export all samples from a bank to individual WAV files

**What to extract:**
1. Raw sample data (8-bit/12-bit/16-bit)
2. Sample rate (EMX2 standard or custom)
3. Loop points (if present)
4. Sample name
5. Format metadata

**UI Design:**
- "Extract Samples" button in bank context menu
- Sheet: Choose destination folder
- Progress bar with current sample name
- Success message: "Extracted 23 samples to ~/Desktop/Bank1"

**Implementation:**

```swift
// Sources/Utilities/SampleExtractor.swift
struct SampleExtractor {
    func extractAllSamples(
        from bank: BankFile,
        to destinationURL: URL,
        progress: (String) -> Void
    ) async throws {
        let samples = parseSamples(from: bank)
        
        for (index, sample) in samples.enumerated() {
            progress("Extracting \(sample.name) (\(index+1)/\(samples.count))")
            
            let wavData = convertToWAV(sample)
            let filename = sanitize(sample.name) + ".wav"
            let fileURL = destinationURL.appendingPathComponent(filename)
            
            try wavData.write(to: fileURL)
        }
    }
    
    private func parseSamples(from bank: BankFile) -> [Sample] {
        // Parse EB2 structure
        // Extract sample definitions
        // Return array of Sample objects
    }
    
    private func convertToWAV(_ sample: Sample) -> Data {
        // Create WAV header
        // Add sample data
        // Include loop points as cue markers
        // Return WAV file data
    }
}

struct Sample {
    let name: String
    let data: Data
    let sampleRate: Int
    let bitDepth: Int
    let loopStart: Int?
    let loopEnd: Int?
}
```

**View:**
```swift
// Sources/Views/ExtractSamplesSheet.swift
struct ExtractSamplesSheet: View {
    let bank: BankFile
    @State private var destinationURL: URL?
    @State private var isExtracting = false
    @State private var currentSample = ""
    @State private var progress: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Extract Samples from \(bank.name)")
                .font(.headline)
            
            Button("Choose Destination") {
                // Open folder picker
            }
            
            if let url = destinationURL {
                Text(url.path).font(.caption)
            }
            
            if isExtracting {
                ProgressView(currentSample, value: progress)
            }
            
            HStack {
                Button("Cancel") { /* dismiss */ }
                Button("Extract") {
                    Task { await extractSamples() }
                }
                .disabled(destinationURL == nil)
            }
        }
        .padding()
    }
}
```

**Time estimate:** 8-12 hours
- EB2 parsing: 4-6h
- WAV generation: 2-3h
- UI: 1-2h
- Testing: 1-2h

---

## Feature 3: Show Samples View ✅

**Goal:** Sample-centric browser showing all samples on disk

**Data to display:**
- Sample name
- Size (KB)
- Bit depth (8/12/16-bit)
- Sample rate
- Used by (preset names)
- Orphan status (unused samples)

**UI Design:**
- New tab: "Samples" (next to Banks)
- Table view with columns:
  - Name | Size | Format | Sample Rate | Used By | Status
- Sort by any column
- Search/filter
- Context menu: Preview, Extract, Delete
- Bottom status: "23 samples, 4.2 MB, 2 orphaned"

**Implementation:**

```swift
// Sources/Models/SampleInfo.swift
struct SampleInfo: Identifiable {
    let id = UUID()
    let name: String
    let size: Int
    let bitDepth: Int
    let sampleRate: Int
    let usedByPresets: [String]
    var isOrphan: Bool { usedByPresets.isEmpty }
}

// Sources/Utilities/SampleAnalyzer.swift
class SampleAnalyzer {
    func analyzeSamples(in image: DiskImage) -> [SampleInfo] {
        var samples: [SampleInfo] = []
        
        // Parse all banks
        for bank in image.banks {
            let bankSamples = extractSamples(from: bank)
            samples.append(contentsOf: bankSamples)
        }
        
        // Cross-reference with presets
        for sample in samples {
            sample.usedByPresets = findPresetsUsing(sample)
        }
        
        return samples
    }
}

// Sources/Views/SampleBrowserView.swift
struct SampleBrowserView: View {
    let image: DiskImage
    @State private var samples: [SampleInfo] = []
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .name
    
    var filteredSamples: [SampleInfo] {
        samples
            .filter { searchText.isEmpty || $0.name.contains(searchText) }
            .sorted(by: sortOrder)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search samples", text: $searchText)
            }
            .padding()
            
            // Sample table
            Table(filteredSamples) {
                TableColumn("Name", value: \.name)
                TableColumn("Size") { sample in
                    Text("\(sample.size / 1024) KB")
                }
                TableColumn("Format") { sample in
                    Text("\(sample.bitDepth)-bit")
                }
                TableColumn("Rate") { sample in
                    Text("\(sample.sampleRate) Hz")
                }
                TableColumn("Used By") { sample in
                    Text(sample.usedByPresets.joined(separator: ", "))
                }
                TableColumn("Status") { sample in
                    if sample.isOrphan {
                        Label("Orphan", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                    } else {
                        Label("OK", systemImage: "checkmark.circle")
                            .foregroundColor(.green)
                    }
                }
            }
            .contextMenu(forSelectionType: SampleInfo.ID.self) { selection in
                Button("Preview") { /* ... */ }
                Button("Extract...") { /* ... */ }
                Divider()
                Button("Delete", role: .destructive) { /* ... */ }
            }
            
            // Status bar
            HStack {
                Text("\(samples.count) samples")
                Text("•")
                Text(formatSize(totalSize))
                if orphanCount > 0 {
                    Text("•")
                    Text("\(orphanCount) orphaned")
                        .foregroundColor(.orange)
                }
                Spacer()
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
        }
        .task {
            samples = SampleAnalyzer().analyzeSamples(in: image)
        }
    }
}
```

**Time estimate:** 6-8 hours
- Sample parsing: 3-4h
- UI: 2-3h
- Testing: 1h

---

## Feature 4: Show Presets View ✅

**Goal:** Preset-centric browser showing all presets with details

**Data to display:**
- Preset name
- Bank name
- Voices count
- Samples used
- Key range
- Velocity layers

**UI Design:**
- New tab: "Presets" (next to Samples)
- Tree view or table
- Expandable: Preset → Voices → Samples
- Search/filter by preset name
- Double-click to jump to bank

**Implementation:**

```swift
// Sources/Models/PresetInfo.swift
struct PresetInfo: Identifiable {
    let id = UUID()
    let name: String
    let bankName: String
    let voiceCount: Int
    let samples: [String]
    let keyRange: ClosedRange<Int>
    let velocityLayers: Int
}

// Sources/Views/PresetBrowserView.swift
struct PresetBrowserView: View {
    let image: DiskImage
    @State private var presets: [PresetInfo] = []
    @State private var searchText = ""
    @State private var selectedPreset: PresetInfo?
    
    var body: some View {
        HSplitView {
            // Left: Preset list
            List(filteredPresets, selection: $selectedPreset) { preset in
                VStack(alignment: .leading) {
                    Text(preset.name).font(.headline)
                    Text(preset.bankName).font(.caption).foregroundColor(.secondary)
                }
            }
            .searchable(text: $searchText)
            
            // Right: Preset details
            if let preset = selectedPreset {
                PresetDetailView(preset: preset)
            } else {
                Text("Select a preset").foregroundColor(.secondary)
            }
        }
    }
}

struct PresetDetailView: View {
    let preset: PresetInfo
    
    var body: some View {
        Form {
            Section("Info") {
                LabeledContent("Name", value: preset.name)
                LabeledContent("Bank", value: preset.bankName)
                LabeledContent("Voices", value: "\(preset.voiceCount)")
            }
            
            Section("Keyboard") {
                LabeledContent("Range", value: "\(preset.keyRange.lowerBound)-\(preset.keyRange.upperBound)")
                LabeledContent("Layers", value: "\(preset.velocityLayers)")
            }
            
            Section("Samples") {
                List(preset.samples, id: \.self) { sample in
                    Text(sample)
                }
            }
        }
    }
}
```

**Time estimate:** 8-10 hours
- Preset parsing: 4-5h
- UI: 3-4h
- Testing: 1h

---

## Feature 5: Show Bank Details (Inspector) ✅

**Goal:** Deep inspector panel showing complete bank structure

**Data to display:**
- Bank header info
- Preset list with offsets
- Voice configurations
- Zone mappings
- Sample memory map
- Hex view (advanced mode)

**UI Design:**
- Inspector panel (right sidebar)
- Toggle with toolbar button
- Tabs: Overview | Presets | Voices | Samples | Memory | Raw
- Tree view for hierarchical data
- Hex editor for raw data

**Implementation:**

```swift
// Sources/Views/InspectorPanel.swift
struct InspectorPanel: View {
    let bank: BankFile
    @State private var selectedTab: Tab = .overview
    
    enum Tab {
        case overview, presets, voices, samples, memory, raw
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("View", selection: $selectedTab) {
                Text("Overview").tag(Tab.overview)
                Text("Presets").tag(Tab.presets)
                Text("Voices").tag(Tab.voices)
                Text("Samples").tag(Tab.samples)
                Text("Memory").tag(Tab.memory)
                Text("Raw").tag(Tab.raw)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            switch selectedTab {
            case .overview:
                BankOverviewView(bank: bank)
            case .presets:
                PresetTreeView(bank: bank)
            case .voices:
                VoiceListView(bank: bank)
            case .samples:
                SampleMapView(bank: bank)
            case .memory:
                MemoryMapView(bank: bank)
            case .raw:
                HexEditorView(data: bank.data)
            }
        }
        .frame(width: 300)
    }
}

struct BankOverviewView: View {
    let bank: BankFile
    
    var body: some View {
        Form {
            Section("File") {
                LabeledContent("Name", value: bank.name)
                LabeledContent("Size", value: formatSize(bank.size))
                LabeledContent("Type", value: "EB2")
            }
            
            Section("Structure") {
                LabeledContent("Presets", value: "\(bank.presetCount)")
                LabeledContent("Voices", value: "\(bank.voiceCount)")
                LabeledContent("Samples", value: "\(bank.sampleCount)")
            }
            
            Section("Memory") {
                LabeledContent("Sample Data", value: formatSize(bank.sampleDataSize))
                LabeledContent("Header", value: formatSize(bank.headerSize))
                LabeledContent("Total", value: formatSize(bank.totalSize))
            }
        }
    }
}
```

**Time estimate:** 10-15 hours
- Data structures: 4-6h
- UI components: 4-6h
- Hex editor: 2-3h
- Testing: 1-2h

---

## Testing Strategy

**For each feature:**
1. Unit tests for parsers/validators
2. Manual testing with real EB2 files
3. Edge cases (empty banks, corrupted data)
4. Performance testing (large disks)

**Test files needed:**
- Valid boot disk (with OS)
- Valid data disk (banks only)
- Corrupted boot signature
- Invalid FAT
- Orphaned samples
- Complex multi-preset banks

---

## Progress Tracking

Create checklist in GitHub Issues or Linear:

- [ ] Feature 1: Disk Verification (10-15h)
  - [ ] Boot signature check
  - [ ] FAT validation
  - [ ] Catalog validation
  - [ ] Bank integrity
  - [ ] UI sheet
  - [ ] Testing
  
- [ ] Feature 2: Sample Extraction (8-12h)
  - [ ] EB2 sample parser
  - [ ] WAV generator
  - [ ] Loop point support
  - [ ] UI sheet
  - [ ] Testing
  
- [ ] Feature 3: Show Samples (6-8h)
  - [ ] Sample analyzer
  - [ ] Table view
  - [ ] Search/filter
  - [ ] Orphan detection
  - [ ] Testing
  
- [ ] Feature 4: Show Presets (8-10h)
  - [ ] Preset parser
  - [ ] Tree/list view
  - [ ] Detail panel
  - [ ] Testing
  
- [ ] Feature 5: Bank Inspector (10-15h)
  - [ ] Overview tab
  - [ ] Preset/voice/sample tabs
  - [ ] Memory map
  - [ ] Hex editor
  - [ ] Testing

---

## Success Criteria

**v1.0 is ready when:**
- ✅ All 5 HIGH features implemented
- ✅ All features tested with real EMAX-II files
- ✅ No known critical bugs
- ✅ Documentation updated
- ✅ Ready for hardware testing

---

## Next Steps

1. **Start with Feature 1 (Disk Verification)**
2. Build incrementally, test each feature
3. Commit after each feature completion
4. Update this roadmap as you progress

**Ready to start?** Let me know which feature you want to tackle first, or if you want me to help with implementation! 🚀
