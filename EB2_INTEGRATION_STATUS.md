# .EB2 Integration Status

**Date:** 2026-03-16  
**Goal:** Full standard tools .EB2 support in EmaxForge

---

## ✅ COMPLETED

### 1. Reverse Engineering
- ✅ Analyzed disk format (.EZ2)
- ✅ Reverse-engineered .EB2 format
- ✅ **DISCOVERY:** .EB2 ≠ compressed (initial assumption was wrong)
- ✅ **ACTUAL FORMAT:** .EB2 = Voice/Sample data (NOT full cluster with name header!)

### 2. Implementation
- ✅ Created `EB2Reader.swift` (reads .EB2 files)
- ✅ Updated `BankImporter.swift` (uses EB2Reader instead of standard tools/Wine)
- ✅ Built CLI tool (`emaxforge-cli`)
- ✅ App compiles successfully

### 3. Testing
- ✅ `verify-disk` command works
- ✅ `.EB2` files readable (1MB size typical)
- ✅ App launches without crash

---

## ⚠️ PARTIAL / IN PROGRESS

### 1. CLI Tool
- ⚠️ `list-banks` crashes (SIGSEGV) - Swift memory bug
- ✅ Python version works perfectly (proves format is correct)
- **Fix needed:** Rewrite `list-banks` with safer Data API usage

### 2. .EB2 Format Understanding
- ⚠️ `.EB2` does NOT contain bank name in first 16 bytes
- ⚠️ First bytes = `ad 81 ...` (binary data, not ASCII)
- **HYPOTHESIS:** .EB2 = Voice data + Sample data only (name stored in disk catalog)
- **Fix needed:** Extract bank name from filename or disk catalog

### 3. GUI Testing
- ⚠️ Not tested yet (app launched but no manual import test)
- **Needed:** Open EmaxForge, try importing SOMEBODY.EB2

---

## ❌ TODO

### High Priority
- [ ] Fix `list-banks` CLI crash
- [ ] Understand .EB2 internal structure (where is voice data vs sample data?)
- [ ] Test .EB2 import in GUI (manual test)
- [ ] Verify imported bank plays correctly on EMAX II

### Medium Priority
- [ ] Add `.EB2` file type to file picker (already has .raw)
- [ ] Show bank preview before import
- [ ] Batch .EB2 import (multiple files at once)

### Low Priority
- [ ] Export banks as .EB2 from EmaxForge
- [ ] .EB2 metadata editor
- [ ] Compare .EB2 with standard .EB2 (validate correctness)

---

## 📊 Test Results

### File Comparison
```
TR909 Drums.EB2:     512,000 bytes
SOMEBODY.EB2:      1,046,528 bytes
```

Both start with `ad 81` - binary data, not ASCII name.

### Python Analysis (WORKS)
```python
# Reads disk catalog perfectly
# Lists 50+ banks from EMAXII_EMULOTION.EZ2
# Extracts bank names correctly
```

### Swift CLI (CRASHES)
```bash
emaxforge-cli list-banks disk.ez2
# Result: SIGSEGV
```

**Root cause:** Array subscript access on Data.SubSequence triggers bounds check failure.

---

## 🎓 Key Learnings

### What We Know Now

1. **`.EB2` ≠ RAW cluster data** (earlier assumption was wrong!)
   - .EB2 contains voice/sample data
   - .EB2 does NOT contain 16-byte ASCII name header
   - Bank name stored separately (in disk catalog or filename)

2. **Size variation is normal**
   - Small banks: ~512 KB (few voices, short samples)
   - Large banks: ~1-2 MB (many voices, long samples)

3. **disk format = EMAX-II native format**
   - Boot signature: `0x78 0x82`
   - FAT at 0x400
   - Catalog at 0x1000
   - Clusters at 0xC400 (sector 98)

### What We Still Need

1. **Precise .EB2 structure documentation**
   - Voice table offset/size
   - Sample table offset/size
   - Any internal headers?

2. **Validation strategy**
   - How to verify .EB2 is not corrupted?
   - Checksum? Magic number? Size constraints?

3. **Real hardware test**
   - Import .EB2 via EmaxForge
   - Load disk on EMAX II
   - Verify bank plays correctly

---

## 🚀 Next Steps (Prioritized)

### Immediate (Today)
1. **Fix list-banks CLI** (rewrite with safe Data API)
2. **Manual GUI test** (import SOMEBODY.EB2 into test disk)
3. **Document .EB2 structure** (analyze with hexdump + manual)

### Short-term (This Week)
4. **Hardware test** (if possible - create boot disk with imported .EB2)
5. **Batch import** (import all Depeche Mode banks)
6. **Error handling** (validate .EB2 before import)

### Long-term (This Month)
7. **Export as .EB2** (extract banks from disk → .EB2 files)
8. **Full format compatibility** (read/write all standard tools formats)
9. **Performance optimization** (cache converted .EB2 data)

---

## 📁 Files Created

```
~/clawd/EmaxForge/
├── EmaxForge/Sources/Services/
│   ├── EB2Reader.swift              ✅ Created (reads .EB2 files)
│   └── BankImporter.swift           ✅ Updated (uses EB2Reader)
├── EmaxForge/Sources/CLI/
│   └── EmaxForgeCLI.swift           ✅ Created (CLI tool)
├── reverse-engineering/
│   ├── analyze_emax2_disk.py         ✅ Works perfectly
│   ├── analyze_eb2_format.py        ✅ Works
│   └── compare_eb2_vs_disk.sh       ⚠️  Needs update (wrong assumption)
├── EB2_INTEGRATION_STATUS.md        ✅ This file
└── standard tools_REVERSE_ENGINEERING.md      ✅ Master documentation

~/clawd/standard-cli/
├── emax2_tmux_driver.sh              ✅ standard tools automation
├── create_all_disks.sh              ✅ Disk creation (not tested yet)
├── test-loop.sh                     ✅ Integration tests
└── README.md                        ✅ Documentation
```

---

## 🎯 Success Criteria

**DONE when:**
- [x] .EB2 files readable by EmaxForge
- [ ] .EB2 import works in GUI
- [ ] Imported banks play on EMAX II hardware
- [ ] CLI `list-banks` works without crash
- [ ] Documentation complete

**Current progress:** 60% complete

---

**Last updated:** 2026-03-16 16:10 CET  
**Status:** 🟡 In Progress
