# 🔥 GHIDRA FULL DECOMPILATION PLAN
**Goal:** Reverse engineer standard tools completely to make EmaxForge the ultimate Mac replacement  
**Scope:** Not just EMAX II — understand ALL supported devices for future expansion

---

## 🎯 Mission Statement

**EmaxForge = standard tools for Mac + Better UX**

EMAX II support is just the beginning. We want to understand:
- How standard tools handles ESI-32, Emulator III, EMAX I
- Cluster allocation algorithms
- Sample conversion pipelines
- Defragmentation strategies
- Multi-format support (HD/SD/Floppy)

---

## 📋 Analysis Phases

### Phase 1: Setup (Est: 30 min)
- [x] Install Ghidra
- [ ] Create Ghidra project
- [ ] Import standardn.exe
- [ ] Run auto-analysis
- [ ] Map Win32 API imports

### Phase 2: Function Discovery (Est: 2-4h)
- [ ] Identify main disk I/O functions
- [ ] Map catalog builder
- [ ] Map FAT manager
- [ ] Map cluster allocator
- [ ] Map bank importer
- [ ] Map sample converter

### Phase 3: Algorithm Extraction (Est: 10-20h)
- [ ] Decompile WriteCatalogEntry()
- [ ] Decompile AllocateClusters()
- [ ] Decompile WriteBootSector()
- [ ] Decompile WriteFAT()
- [ ] Decompile ImportBank()
- [ ] Decompile ConvertSample()

### Phase 4: Multi-Device Support (Est: 10-20h)
- [ ] Find ESI-32 format logic
- [ ] Find Emulator III format logic
- [ ] Find EMAX I format logic
- [ ] Map device-specific differences
- [ ] Extract format specifications

### Phase 5: Documentation (Est: 4-6h)
- [ ] Write algorithm pseudocode
- [ ] Create format specifications
- [ ] Document cluster allocation strategy
- [ ] Map all constants per device type
- [ ] Create implementation guide for EmaxForge

---

## 🔍 Key Functions to Find

### Disk I/O Layer
```
CreateDiskImage()
FormatDisk()
WriteSector(offset, data)
ReadSector(offset)
```

### Catalog Management
```
CreateCatalog()
AddCatalogEntry(name, cluster, size, flags)
ValidateCatalog()
```

### FAT Management
```
InitFAT(size)
AllocateCluster() -> cluster_id
FreeCluster(cluster_id)
MarkClusterUsed(cluster_id)
GetNextCluster(cluster_id)
```

### Bank/Sample Handling
```
ImportBank(path, target_disk)
ConvertSample(wav_data) -> emax_sample
WriteBank(bank, cluster)
ReadBank(cluster) -> bank
```

### Device-Specific
```
GetDeviceType(image) -> EMAX_II | ESI_32 | EIII | EMAX_I
GetFormatParams(device) -> (cluster_size, catalog_size, ...)
ValidateForDevice(image, device) -> bool
```

---

## 🎯 Priority Targets

### HIGH PRIORITY (Need for EmaxForge v1.0)
1. **Cluster Allocation Algorithm**
   - How does standard tools decide which cluster to use?
   - Is there defragmentation?
   - How are samples split across clusters?

2. **Catalog Builder**
   - How are FLAGS determined?
   - What are bytes 16-31 in catalog entry?
   - Are there device-specific variations?

3. **FAT Structure**
   - What does 0x000F mean exactly?
   - How does FAT chain work?
   - How to mark end-of-file?

4. **Boot Sector Writer**
   - Is there more than just signature?
   - Device-specific boot code?
   - Partition table?

### MEDIUM PRIORITY (EmaxForge v2.0)
1. **Sample Converter**
   - WAV → EMAX format algorithm
   - Bit depth conversion
   - Sample rate conversion
   - Loop point handling

2. **Bank Importer**
   - .EB2 format parser
   - Sample extraction
   - Preset metadata
   - Cluster assignment

3. **Multi-Device Support**
   - ESI-32 differences
   - Emulator III differences
   - EMAX I differences

### LOW PRIORITY (Future)
1. **Defragmentation**
   - Cluster reorganization
   - Free space optimization

2. **Bad Sector Handling**
   - Error recovery
   - Cluster remapping

3. **HxC Floppy Format**
   - Track encoding
   - Sector interleaving

---

## 🛠️ Ghidra Workflow

### Initial Analysis
```bash
1. File → Import File → standardn.exe
2. Analysis → Auto Analyze
   - Enable: Function ID
   - Enable: Stack Analysis
   - Enable: Reference Analysis
   - Enable: Windows x86 PE
3. Wait for analysis (10-30 min for 5MB binary)
```

### Function Identification
```
1. Search → For Strings → "catalog", "signature", "cluster"
2. Right-click string → References → Find references to
3. Follow to function
4. Rename function (right-click → Edit Function Signature)
```

### Decompilation
```
1. Select function in Symbol Tree
2. Window → Decompile
3. Export → C/C++ → Save as .c file
4. Analyze algorithm
5. Write pseudocode for EmaxForge
```

### Cross-Referencing
```
1. Find constant (e.g., 0x7882)
2. Search → For Scalars → 0x7882
3. View all references
4. Map data flow
```

---

## 📊 Expected Discoveries

### Catalog Entry Structure (32 bytes)
```c
struct CatalogEntry {
    char name[16];           // 0x00: Bank/OS name
    uint16_t bank_id;        // 0x10: Sequential ID
    uint16_t start_cluster;  // 0x12: First cluster
    uint16_t sector_count;   // 0x14: Size in sectors?
    uint16_t sample_offset;  // 0x16: Offset within cluster?
    uint16_t cluster_count;  // 0x18: Number of clusters?
    uint16_t flags;          // 0x1A: 0x8100 always?
    uint32_t reserved;       // 0x1C: Always 0?
};
```

### FAT Structure
```c
struct FAT {
    uint16_t header;         // 0x000F (purpose unknown)
    uint16_t reserved;       // 0x0000
    uint16_t entries[...];   // Cluster chain
                             // 0x8080 = free/end?
                             // Other values = next cluster?
};
```

### Boot Sector
```c
struct BootSector {
    uint8_t boot_code[510];  // 0x000: Device-specific?
    uint16_t signature;      // 0x1FE: 0x7882
};
```

---

## 🔬 Reverse Engineering Strategy

### Bottom-Up Approach
1. Start with **known outputs** (our valid images)
2. Find **functions that write those bytes**
3. Trace **backwards to input parameters**
4. Map **complete data flow**

### Top-Down Approach
1. Find **main()** entry point
2. Follow **user command flow** (e.g., "Create HD image")
3. Map **function call tree**
4. Identify **high-level architecture**

### Hybrid (Best)
1. Use bottom-up for **critical structures** (catalog, FAT, boot)
2. Use top-down for **program flow** (menu system, command dispatch)
3. Cross-reference to **validate findings**

---

## 📝 Documentation Output

For each discovered algorithm, create:

### 1. Pseudocode
```
function WriteCatalogEntry(entry):
    seek(0x1000 + entry.index * 32)
    write(entry.name, 16)
    write_u16_le(entry.bank_id)
    write_u16_le(entry.start_cluster)
    write_u16_le(entry.sector_count)
    write_u16_le(entry.sample_offset)
    write_u16_le(entry.cluster_count)
    write_u16_le(0x8100)  // FLAGS constant
    write_u32_le(0x00000000)  // Reserved
```

### 2. Swift Implementation Plan
```swift
struct CatalogEntry {
    let name: String
    let bankID: UInt16
    let startCluster: UInt16
    // ... (matching standard tools structure)
    
    func write(to handle: FileHandle, at index: Int) {
        let offset = 0x1000 + index * 32
        // ... (implement from pseudocode)
    }
}
```

### 3. Test Case
```swift
func testCatalogWrite() {
    let entry = CatalogEntry(name: "EMAX2 Software", ...)
    // Write to test image
    // Compare hex dump with standard tools output
    XCTAssertEqual(...)
}
```

---

## 🎯 Success Metrics

### Phase 1 Complete When:
- [ ] All major functions identified
- [ ] Catalog/FAT/Boot sector writers located
- [ ] Device detection logic found

### Phase 2 Complete When:
- [ ] Cluster allocation algorithm understood
- [ ] Catalog entry structure 100% mapped
- [ ] FAT format fully documented

### Phase 3 Complete When:
- [ ] All EMAX II algorithms implemented in EmaxForge
- [ ] ESI-32 format documented
- [ ] Emulator III format documented

### Ultimate Success:
- [ ] EmaxForge can create **any** image standard tools can create
- [ ] EmaxForge can import **any** bank standard tools can import
- [ ] EmaxForge supports **all** devices standard tools supports
- [ ] EmaxForge has **better UX** than standard tools

---

## 🔮 Vision: EmaxForge 2.0

Once we understand standard tools completely, EmaxForge can become:

### Native Mac Experience
- ✅ Native SwiftUI (no Wine/Whisky needed)
- ✅ Drag-and-drop from Finder
- ✅ macOS Shortcuts integration
- ✅ iCloud sync support

### Beyond standard tools Features
- 🆕 Visual waveform editor
- 🆕 Real-time preview
- 🆕 Cloud preset library
- 🆕 Auto-backup to Time Machine
- 🆕 Multi-disk batch operations
- 🆕 Smart defragmentation
- 🆕 Preset tagging/search

### Multi-Platform
- 🆕 iOS companion app (preview banks on iPhone)
- 🆕 Web version (cloud-based editing)
- 🆕 API for automation

---

## 📂 Workspace Structure

```
~/clawd/EmaxForge/ghidra/
├── standardn.exe.gzf          # Ghidra project file
├── decompiled/            # Exported C code
│   ├── catalog.c
│   ├── fat.c
│   ├── cluster.c
│   └── device.c
├── algorithms/            # Pseudocode
│   ├── WriteCatalog.md
│   ├── AllocateCluster.md
│   └── ConvertSample.md
├── formats/               # Format specs
│   ├── EMAX_II.md
│   ├── ESI_32.md
│   └── EIII.md
└── notes/                 # Analysis notes
    ├── constants.md
    ├── structs.md
    └── questions.md
```

---

**Let's do this!** 🔥

Ready to make EmaxForge the best vintage sampler tool ever made.
