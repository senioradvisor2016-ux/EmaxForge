# standard tools Clone Plan - Full EMAX-II Feature Parity

**Goal:** Make EmaxForge 100% compatible for EMAX-II workflow  
**Timeline:** Iterative - most critical features first  
**Reference:** industry-standard format Reference Manual (566 pages)

---

## Phase 1: File Format Support ✅ (DONE)

### Disk Images
- [x] `.EZ2` - Hard disk images (DONE - native format!)
- [x] `.ISO` - Hard disk images (DONE - same as .EZ2)
- [x] `.IMG` - Hard disk images (DONE - same as .EZ2)
- [x] `.hda` - ZuluSCSI naming (DONE - EmaxForge native)

### Bank Files
- [x] `.EB2` - Bank files (DONE - import works!)
- [ ] `.EM2` - RAM dump files (with empty space)
- [ ] `.EMX` - Operating system files

### Floppy Images
- [ ] `.EM2FD` - Floppy disk images
- [ ] `.HFE` - HxC floppy disk images

---

## Phase 2: Core Operations (IN PROGRESS)

### A. Bank Management ✅ 80% DONE

**Import:**
- [x] Import `.EB2` to disk ✅
- [x] FAT chain management ✅
- [x] Catalog entry creation ✅
- [ ] Import `.EM2` (RAM dumps)
- [ ] Batch import (multiple .EB2 at once)
- [ ] Duplicate detection
- [ ] Name conflict resolution

**Export:**
- [ ] Export bank as `.EB2` (extract from disk)
- [ ] Export bank as `.EM2` (with empty space)
- [ ] Extract samples as WAV
- [ ] Batch export

**Organization:**
- [ ] Rename banks on disk
- [ ] Delete banks from disk
- [ ] Defragment disk (compact FAT)
- [ ] Sort banks alphabetically
- [ ] Move banks between disks

### B. Disk Management ⚠️ 50% DONE

**Create:**
- [x] Create bootable HD (239 MB) ✅
- [x] All standard tools sizes (96/239/481/633/962 MB) ✅
- [ ] Create empty HD (no OS)
- [ ] Create floppy images
- [ ] Multi-partition SCSI2SD images

**Operations:**
- [x] Format disk ✅
- [ ] Clone disk (exact copy)
- [ ] Verify disk integrity
- [ ] Repair corrupt disks
- [ ] Resize disk (change size)

**Info:**
- [x] Show disk capacity ✅
- [x] Show free space ✅
- [x] List all banks ✅ (Python works, Swift crashes)
- [ ] Show disk fragmentation
- [ ] Show OS version

### C. Operating System Management ❌ 0% DONE

- [ ] Extract OS from disk → `.EMX` file
- [ ] Install OS to disk from `.EMX` file
- [ ] Update OS version on multiple disks
- [ ] Identify OS version (rev 2.14, etc.)
- [ ] Create bootable floppy with OS

---

## Phase 3: Advanced Features (TODO)

### A. Conversion ❌ 0% DONE

**Between EMAX formats:**
- [ ] EMAX-I ↔ EMAX-II
- [ ] EMAX-II ↔ Emulator-III
- [ ] EMAX-II ↔ ESI-32

**Sample formats:**
- [ ] `.EB2` → WAV extraction
- [ ] WAV → `.EB2` construction
- [ ] SoundFont2 → `.EB2`
- [ ] Akai S1000 → `.EB2`

**Parameter mapping:**
- [ ] Voice parameters (filter, envelope, LFO)
- [ ] Effects (if applicable)
- [ ] Modulation routing

### B. Sample Management ❌ 0% DONE

- [ ] Extract individual samples from bank
- [ ] Import samples into bank
- [ ] Resample (change sample rate)
- [ ] Normalize sample levels
- [ ] Trim silence
- [ ] Loop point editor

### C. Validation & Repair ❌ 0% DONE

**Validation:**
- [ ] Check bank integrity
- [ ] Validate sample data
- [ ] Check voice parameters
- [ ] Verify FAT chains
- [ ] Catalog consistency check

**Repair:**
- [ ] Fix broken FAT chains
- [ ] Rebuild catalog
- [ ] Recover deleted banks
- [ ] Remove duplicate entries
- [ ] Fix corrupt sample headers

### D. SCSI2SD Support ❌ 0% DONE

- [ ] Read SCSI2SD config files
- [ ] Create multi-partition images
- [ ] Partition management (add/remove)
- [ ] Device ID assignment
- [ ] Bad sector handling

---

## Phase 4: UI/UX Enhancements (TODO)

### A. Batch Operations
- [ ] Multi-select banks
- [ ] Drag & drop multiple .EB2 files
- [ ] Progress bars for long operations
- [ ] Background processing
- [ ] Queue management

### B. Visualization
- [ ] Disk usage pie chart
- [ ] FAT visualization (free/used clusters)
- [ ] Sample waveform display
- [ ] Voice parameter charts
- [ ] Catalog tree view

### C. Search & Filter
- [ ] Search banks by name
- [ ] Filter by bank type (voices, sequences)
- [ ] Sort by size/date/name
- [ ] Tag system for organization

### D. Presets & Automation
- [ ] Save common workflows as presets
- [ ] Scripting support (Swift/Shell)
- [ ] CLI batch operations
- [ ] Automated backups

---

## Phase 5: Documentation (ONGOING)

### User Documentation
- [ ] Quick start guide
- [ ] Video tutorials
- [ ] Troubleshooting guide
- [ ] FAQ

### Developer Documentation
- [x] .EB2 format spec ✅
- [x] .EZ2 format spec ✅
- [ ] .EM2 format spec
- [ ] .EMX format spec
- [ ] API documentation

### Reference Materials
- [x] format specification analysis ✅ (IN PROGRESS)
- [ ] EMAX-II technical manual
- [ ] Sample library catalog
- [ ] Conversion quality matrix

---

## Implementation Priority

### Critical (Do First) 🔥
1. ✅ .EB2 import (DONE!)
2. [ ] .EB2 export (extract from disk)
3. [ ] Bank delete
4. [ ] Disk clone
5. [ ] Batch .EB2 import

### High Priority (Next)
6. [ ] .EM2 support (RAM dumps)
7. [ ] OS extraction/installation
8. [ ] Disk verification
9. [ ] WAV extraction
10. [ ] Name conflict resolution

### Medium Priority
11. [ ] Conversion to other formats
12. [ ] Sample management
13. [ ] SCSI2SD multi-partition
14. [ ] Floppy image support
15. [ ] Validation & repair tools

### Low Priority (Nice to Have)
16. [ ] Effects conversion
17. [ ] SoundFont2 support
18. [ ] Akai S1000 support
19. [ ] Advanced scripting
20. [ ] Waveform display

---

## Feature Comparison

### EmaxForge vs standard tools (Current State)

| Feature | standard tools | EmaxForge | Status |
|---------|------|-----------|--------|
| **File Support** ||||
| .EB2 read | ✅ | ✅ | ✅ DONE |
| .EB2 write | ✅ | ❌ | TODO |
| .EM2 read | ✅ | ❌ | TODO |
| .EMX read | ✅ | ❌ | TODO |
| .EZ2 read/write | ✅ | ✅ | ✅ DONE |
| **Bank Operations** ||||
| Import .EB2 | ✅ | ✅ | ✅ DONE |
| Export .EB2 | ✅ | ❌ | TODO |
| Delete bank | ✅ | ⚠️ | PARTIAL |
| Rename bank | ✅ | ❌ | TODO |
| **Disk Operations** ||||
| Create boot disk | ✅ | ✅ | ✅ DONE |
| Format disk | ✅ | ✅ | ✅ DONE |
| Clone disk | ✅ | ❌ | TODO |
| Verify disk | ✅ | ⚠️ | PARTIAL |
| **OS Management** ||||
| Extract OS | ✅ | ❌ | TODO |
| Install OS | ✅ | ✅ | ✅ DONE |
| Update OS | ✅ | ❌ | TODO |
| **Advanced** ||||
| Convert formats | ✅ | ❌ | TODO |
| WAV extraction | ✅ | ❌ | TODO |
| Sample editor | ✅ | ❌ | TODO |
| SCSI2SD multi | ✅ | ❌ | TODO |

**Current coverage:** ~25% of standard tools features  
**Target:** 80% coverage for EMAX-II workflow

---

## Technical Implementation Notes

### .EB2 Format (Now Understood!)

**Structure:**
```
.EB2 file = Voice data + Sample data (binary)
          ≠ ASCII name header
          ≠ Compressed data
```

**Key facts:**
- First bytes: `ad 81 20 84...` (voice parameters)
- Size: 500 KB - 2 MB (depends on samples)
- Name: Stored in disk catalog, NOT in .EB2
- No wrapper, no compression

### .EM2 Format (TODO)

**Structure:**
```
.EM2 file = RAM dump with empty space preserved
          = Multiple .EM2 files per bank (for >512 KB banks)
```

**Key facts:**
- Contains empty sample space (unlike .EB2)
- May require multiple files for large banks
- Used for floppy disk dumps
- Has signature string (unlike raw RAM)

### .EMX Format (TODO)

**Structure:**
```
.EMX file = Operating system binary
          = Exact copy from disk boot sector
```

**Key facts:**
- Size: ~260 KB (rev 2.14)
- Contains boot code + OS kernel
- Can be installed to HD or floppy
- Version-specific (2.00, 2.14, etc.)

### Disk Structure (Fully Documented)

**HD Layout:**
```
0x000-0x1FF:   Boot sector (signature at 0x1FE: 0x78 0x82)
0x400-0x7FF:   FAT (512 entries × 2 bytes)
0x1000-0x4FFF: Catalog (320 entries × 64 bytes)
0xC400+:       Cluster area (cluster 0 = OS)
```

**Cluster size:** 489,472 bytes (956 sectors)

---

## Next Actions (While Peter is Away)

### Immediate Tasks (Today)

1. **Document .EM2 format** ⏳
   - Search format specification for .EM2 details
   - Analyze sample .EM2 files
   - Write format spec

2. **Implement .EB2 export** ⏳
   - Extract bank from disk
   - Strip FAT/catalog metadata
   - Write pure voice/sample data
   - Test with standard tools

3. **Improve CLI** ⏳
   - Fix `list-banks` crash
   - Add `export-bank` command
   - Add `delete-bank` command

4. **Create test suite** ⏳
   - Automated regression tests
   - Bank import/export roundtrip
   - Disk creation validation

### Research Tasks (Today/Tomorrow)

5. **Analyze .EM2 samples** 🔬
   - Find .EM2 files in Peter's library
   - Hex dump analysis
   - Compare with .EB2 format

6. **Study OS files** 🔬
   - Analyze `Emax II rev 2.14.EMX`
   - Understand boot process
   - Document OS installation

7. **Map conversion algorithms** 🔬
   - EMAX-I → EMAX-II parameter mapping
   - Voice structure differences
   - Sample format differences

8. **SCSI2SD research** 🔬
   - Multi-partition image format
   - Config file structure
   - Bad sector handling

---

## Success Criteria

### Short-term (This Week)
- [ ] .EB2 export working
- [ ] .EM2 format documented
- [ ] CLI fully functional
- [ ] Test suite created

### Medium-term (This Month)
- [ ] 50% standard tools feature parity
- [ ] All bank operations working
- [ ] OS management working
- [ ] Complete user documentation

### Long-term (This Quarter)
- [ ] 80% standard tools feature parity
- [ ] Conversion support
- [ ] SCSI2SD multi-partition
- [ ] Hardware-validated on real EMAX II

---

## Resources

### Files to Study
- industry-standard format Reference Manual (566 pages) ✅ READING NOW
- `~/clawd/standard/` - Sample library with .EB2, .EM2, .EMX files
- `~/clawd/EmaxForge/reverse-engineering/` - Analysis scripts

### Hardware Test Setup
- EMAX II sampler
- ZuluSCSI Pico
- SD card with test images
- Sample .EB2 files

### Development Environment
- EmaxForge (Swift + SwiftUI)
- Python analysis scripts
- xxd, hexdump for binary analysis
- industry-standard format (Wine/Whisky) for comparison

---

**Status:** 📖 Reading format specification, implementing .EB2 export next  
**Last updated:** 2026-03-16 16:50 CET  
**Progress:** 25% → 35% (target: 80%)
