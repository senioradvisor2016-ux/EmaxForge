# 🔥 Ghidra Deep Dive - Session Log
**Start:** March 5, 2026 04:49 AM  
**Goal:** Full reverse engineering of standard tools to make EmaxForge the ultimate Mac replacement

---

## ✅ Phase 1: Setup (COMPLETE)

### Installed Tools
- ✅ **Ghidra 12.0.4** (801 MB)
  - Location: `/opt/homebrew/Cellar/ghidra/12.0.4/`
  - Dependencies: OpenJDK 21, HarfBuzz, ICU4C, FreeType
  - Headless analysis tool: `analyzeHeadless`

- ✅ **radare2 6.1.0** (37 MB)
  - Used for initial reconnaissance
  - Identified 300+ error strings
  - Mapped binary structure

### Workspace Created
```
~/clawd/EmaxForge/ghidra/
├── EmaxProject.gpr           # Ghidra project (created)
├── EmaxProject.rep/          # Project repository
├── decompiled/               # Exported C code (empty)
├── algorithms/               # Pseudocode docs (empty)
├── formats/                  # Format specs (empty)
├── notes/                    # Analysis notes
│   └── target_functions.md  # Function mapping guide
├── auto_analyze.py           # Automated analysis script
├── QUICKSTART.md             # Quick reference guide
└── ghidra_analysis.log       # Current analysis log
```

### Documentation Created
- ✅ `GHIDRA_ANALYSIS_PLAN.md` (9 KB) - Complete roadmap
- ✅ `QUICKSTART.md` (6 KB) - Fast-track guide
- ✅ `target_functions.md` (8 KB) - Function hunting guide
- ✅ `auto_analyze.py` (6 KB) - Automation script

---

## 🔄 Phase 2: Initial Analysis (IN PROGRESS)

### Headless Analysis Started
```bash
Command: analyzeHeadless . EmaxProject \
    -import ~/clawd/standard/standardn.exe \
    -analysisTimeoutPerFile 300 \
    -log ghidra_analysis.log

Status: RUNNING (started 04:50 AM)
Expected duration: 10-30 minutes
```

**Analysis tasks:**
- [ ] Import PE binary (standardn.exe, 5.2 MB)
- [ ] Auto-analyze (all analyzers enabled)
- [ ] Function discovery
- [ ] String identification
- [ ] Cross-reference mapping
- [ ] Data structure inference

---

## 🎯 Target Discoveries (From Pre-Analysis)

### Critical Constants Found

| Constant | Value | Occurrences | Purpose |
|----------|-------|-------------|---------|
| Boot signature | `0x7882` | 10 | Mandatory boot marker |
| FLAGS | `0x8100` | 10+ | Catalog entry flags |
| FAT header | `0x000F` | 10+ | FAT structure marker |
| Free cluster | `0x8080` | 10+ | Unused cluster marker |
| Boot offset | `0x01FE` | Multiple | Signature position |
| FAT offset | `0x0200` | Multiple | FAT start position |
| Catalog offset | `0x1000` | Multiple | Catalog start position |

### Error Messages Mapped (300+)

**Top priority:**
```
"Signature area %s %s %s can not be read"
"The HD catalog of %s %s is invalid"
"Cluster map area %s %s %s can not be read"
"The sector size of %s %s is not supported"
"Not enough empty clusters %s %s"
```

### Win32 API Calls Identified

**File I/O:**
- `CreateFileA`, `CreateFileW`
- `ReadFile`, `WriteFile`
- `SetFilePointer`, `SetFilePointerEx`
- `GetFileSize`, `GetFileSizeEx`
- `CloseHandle`

**Disk Operations:**
- `GetDiskFreeSpaceA`, `GetDiskFreeSpaceExA`

---

## 📋 Next Steps (After Analysis Completes)

### Phase 3: Function Discovery (Est: 2-4h)

1. **Find Boot Signature Writer**
   - Search for string "Signature area"
   - Follow references to function
   - Decompile and export to C
   - Document algorithm

2. **Find Catalog Writer**
   - Search for string "The HD catalog"
   - Follow references to function
   - Map CatalogEntry structure
   - Export decompiled code

3. **Find FAT Manager**
   - Search for string "Cluster map"
   - Identify InitFAT(), AllocateCluster()
   - Document FAT chain format
   - Export decompiled code

4. **Find Cluster Allocator**
   - Search for "Not enough empty clusters"
   - Map allocation algorithm
   - Document free space tracking

5. **Rename All Functions**
   - Use meaningful names
   - Add function signatures
   - Document parameters/returns

---

### Phase 4: Algorithm Extraction (Est: 10-20h)

For each critical function:

1. **Decompile to C**
   - Window → Decompile
   - Export → C/C++
   - Save to `decompiled/`

2. **Write Pseudocode**
   - Simplify Ghidra output
   - Document in `algorithms/`
   - Add comments

3. **Map Data Structures**
   - Define structs
   - Document field meanings
   - Create Swift equivalents

4. **Create Implementation Plan**
   - Write Swift stub
   - Plan unit tests
   - Identify edge cases

---

### Phase 5: Multi-Device Support (Est: 10-20h)

1. **Find Device Detection Logic**
   - Search for "EMAX", "ESI", "Emulator"
   - Map device type enum
   - Document detection algorithm

2. **Map Format Differences**
   - ESI-32 vs EMAX II
   - Emulator III vs EMAX II
   - EMAX I vs EMAX II

3. **Document Each Format**
   - Create `formats/ESI_32.md`
   - Create `formats/EIII.md`
   - Create `formats/EMAX_I.md`

4. **Extract Constants**
   - Per-device boot signatures
   - Per-device catalog layouts
   - Per-device cluster sizes

---

## 🔬 Analysis Strategy

### Bottom-Up (Start Here)
1. Find known outputs (0x7882, 0x8100, etc.)
2. Trace backwards to functions that write them
3. Map complete data flow

### Top-Down (Parallel)
1. Find main() entry point
2. Follow menu system
3. Map user command flow
4. Identify high-level architecture

### Validation (Continuous)
1. Compare findings with hex dumps
2. Test hypotheses with EmaxForge
3. Create test images
4. Verify on real hardware

---

## 💡 Expected Breakthroughs

### Cluster Allocation Algorithm
**Question:** How does standard tools decide which cluster to use?

**Hypothesis:**
- Linear scan of FAT for first free (0x8080)?
- Best-fit algorithm?
- First-fit?
- Defragmentation logic?

**Method:** Decompile AllocateCluster() to find out

---

### Catalog Entry Structure
**Question:** What are bytes 16-31 exactly?

**Current knowledge:**
```
0x10-0x11: Bank ID (sequential?)
0x12-0x13: Start cluster
0x14-0x15: Sector count OR cluster count?
0x16-0x17: Sample offset OR file size?
0x18-0x19: Cluster count OR reserved?
0x1A-0x1B: FLAGS (always 0x8100)
0x1C-0x1F: Reserved (always 0x00000000)
```

**Method:** Find WriteCatalogEntry() and trace all writes

---

### FAT Chain Format
**Question:** How do FAT entries link clusters?

**Hypothesis:**
- 0x000F = FAT header / magic number
- 0x0000 = Reserved entry
- 0x8080 = Free OR end-of-chain
- 0x0001-0x7FFF = Next cluster number?

**Method:** Decompile GetNextCluster() and MarkClusterUsed()

---

### Sample Conversion
**Question:** How are WAV samples converted to EMAX format?

**Need to find:**
- Bit depth conversion algorithm
- Sample rate conversion (resampling)
- Loop point handling
- Envelope processing

**Method:** Find ConvertSample() or ProcessWAV()

---

## 📊 Success Metrics

### Analysis Complete When:
- [ ] All 25+ major functions identified
- [ ] All functions renamed with meaningful names
- [ ] All critical constants documented
- [ ] All data structures mapped

### Algorithms Understood When:
- [ ] Boot sector writer algorithm documented
- [ ] Catalog writer algorithm documented
- [ ] FAT manager algorithm documented
- [ ] Cluster allocator algorithm documented
- [ ] Sample converter algorithm documented

### EmaxForge Ready When:
- [ ] All EMAX II algorithms implemented in Swift
- [ ] ESI-32 format documented
- [ ] Emulator III format documented
- [ ] Test suite passes 100%
- [ ] Output matches standard tools byte-for-byte

---

## 🎯 Vision: EmaxForge 2.0

Once we understand standard tools completely:

### Core Features (Match standard tools)
- ✅ EMAX II support (already working!)
- 🔜 ESI-32 support
- 🔜 Emulator III support
- 🔜 EMAX I support
- 🔜 All image formats (HD/SD/Floppy/HxC)

### Beyond standard tools
- 🆕 Native Mac app (no Wine!)
- 🆕 Modern SwiftUI interface
- 🆕 Drag-and-drop everything
- 🆕 Real-time waveform preview
- 🆕 Cloud preset library
- 🆕 iCloud sync
- 🆕 iOS companion app
- 🆕 Batch operations
- 🆕 Smart defragmentation
- 🆕 Auto-backup

---

## ⏰ Time Estimates

### Total Project Timeline

| Phase | Description | Time | Status |
|-------|-------------|------|--------|
| 1 | Setup + Tools | 2h | ✅ DONE |
| 2 | Initial Analysis | 1-2h | 🔄 IN PROGRESS |
| 3 | Function Discovery | 2-4h | ⏳ PENDING |
| 4 | Algorithm Extraction | 10-20h | ⏳ PENDING |
| 5 | Multi-Device Support | 10-20h | ⏳ PENDING |
| 6 | Swift Implementation | 20-40h | ⏳ PENDING |
| 7 | Testing | 10-20h | ⏳ PENDING |

**Total:** 55-108 hours (7-14 days full-time)

---

## 🚨 Current Status

**Time:** March 5, 2026 04:51 AM  
**Phase:** 2 (Initial Analysis)  
**Task:** Ghidra headless analysis of standardn.exe  
**Progress:** Running (10-30 min remaining)

**Next immediate action:**
1. Wait for analysis to complete
2. Check `ghidra_analysis.log` for results
3. Open Ghidra GUI to view decompiled code
4. Begin Phase 3 (Function Discovery)

---

**Session will resume when analysis completes...**

🔥 Let's make EmaxForge legendary!
