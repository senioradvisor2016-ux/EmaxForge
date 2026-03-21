# standard tools & Translator Analysis - Key Findings for EmaxForge

**Analyzed:** industry-standard format Reference Manual (1.8 MB) + Translator 6 Manual
**Date:** March 8, 2026

## 🔥 Critical Discoveries

### 1. SCSI2SD Support (standard tools has this, EmaxForge needs it!)

**standard tools SCSI2SD Features (pages 103-810):**
- **Multi-partition support** - treats each partition as separate device
- **Backup/restore** - entire SD card OR individual partitions
- **Partition detection** - auto-detects EMAX I/II, EIII, ESI partitions
- **Configuration export** - generates SCSI2SD.xml config
- **Validation** - checks bad sectors, partition table health
- **ISO image support** - can work with .img files (not just physical SD)

**ZuluSCSI Equivalent for EmaxForge:**
- Multi-image support already implemented (HD10, HD20, HD30)
- Config generator exists (zuluscsi.ini)
- Need: Partition detection (for multi-sampler SD cards)
- Need: Health check/validation tool

### 2. Validation Rules (Critical for Bank Import!)

**Error Codes (pages 140-153):**

**EMAX II Bank Validation:**
```
E2-001: Invalid bank size
E2-002: Invalid preset count (must be 1-100)
E2-003: Invalid voice count
E2-004: Corrupt voice data
E2-005: Invalid sample references
E2-006: Sample out of bounds
E2-007: Corrupt sample header
E2-008: Invalid loop points
E2-009: Missing required data
E2-010: Checksum mismatch (standard tools validates!)
```

**EmaxForge Should Add:**
- Pre-import validation (warn before corrupt banks crash EMAX II)
- Checksum verification (standard tools does this!)
- Auto-repair for common issues (loop points, voice counts)
- Detailed error messages (not just "import failed")

### 3. Disk Format Details

**Hard Disk Structure (EMAX II):**
```
Boot sector:
  - Magic: "EMX2"
  - Cluster size varies by disk size
  - Boot signature: 0x78 0x82

Status Table:
  - Bank allocation status
  - Free/used cluster markers
  - Corruption flags

FAT (File Allocation Table):
  - Entry 0: 0x8000 (reserved)
  - Entry 1: 0x7FFF (OS end marker)
  - Chain format: cluster → next_cluster
  - End marker: 0x7FFF

Catalog:
  - 32-byte entries (NOT ASCII names!)
  - Binary field codes
  - Bank metadata (start cluster, preset count, etc.)
```

**CONFIRMED by working disk analysis!**

### 4. Translator 6 Format Support

**Formats Supported:**
- EMAX I/II (.E01, .E02, .EB2)
- Emulator I/II/III (.E16, .E32, .EOS)
- ESI-32/4000 (.ESP)
- Akai S1000/3000 (.AKP, .AKM)
- SoundFont 2 (.SF2)
- WAV (multiple sample rates)
- **Proprietary Floppy Support** (Translator can read exotic formats!)

**Key Feature:**
- **Batch Conversion** - mass convert between formats
- **Virtual Drives** - mount disk images as drives
- **Auto-mapping** - intelligent keyzone assignment
- **Beat Detection** - auto-slice loops

**EmaxForge Could Add:**
- Import from Akai/SoundFont (via Translator-like conversion)
- Auto-keyzone mapping (Translator's algorithm)
- Beat slicer (for modern workflows)

### 5. SCSI2SD Configuration (standard tools pages 776-810)

**standard tools generates SCSI2SD.xml with:**
```xml
<SCSITarget id="0">
  <enabled>true</enabled>
  <scsiId>0</scsiId>
  <deviceType>0</deviceType> <!-- Hard disk -->
  <sectorsPerTrack>63</sectorsPerTrack>
  <headsPerCylinder>255</headsPerCylinder>
  <bytesPerSector>512</bytesPerSector>
  <quirks>Apple</quirks> <!-- EMU compatibility! -->
  <vendor>SEAGATE</vendor>
  <productId>ST1200N</productId>
  <revision>1.00</revision>
</SCSITarget>
```

**Critical for ZuluSCSI:**
- Quirks mode needed? (standard tools uses "Apple")
- Vendor string affects boot (SEAGATE known working)
- Device type must be 0 (hard disk, not removable)

### 6. Corrupt Bank Handling

**standard tools Strategy (pages 140-142):**
1. **Validate before write** - prevents disk corruption
2. **Auto-repair** - fix common issues (e.g., invalid loop points → set to 0)
3. **Warn user** - show validation errors in red
4. **Skip on batch** - continue with next bank if one fails
5. **Detailed log** - save error report to file

**EmaxForge Should Copy This!**

### 7. Disk Creation Workflow (standard tools)

**Steps from manual (pages 80-86):**
1. Select disk size (96/239/481/633/962 MB)
2. **Format disk** (write boot sector, FAT, status table, catalog)
3. **Install OS** (write to cluster 1)
4. **Add INIT BANK** (minimal bank for boot validation)
5. **Import user banks** (batch or manual)
6. **Generate config** (SCSI2SD.xml or zuluscsi.ini)
7. **Verify** (checksum, boot test)

**EmaxForge Already Does Most of This!** ✅

## 🚀 Features EmaxForge Should Add

### High Priority:
1. **Pre-import validation** (standard tools error codes E2-001 to E2-010)
2. **Checksum verification** (standard tools validates, we don't!)
3. **Auto-repair** (fix loop points, voice counts, etc.)
4. **SCSI2SD.xml export** (for users with SCSI2SD hardware)
5. **Health check tool** (validate disk integrity, bad sector scan)

### Medium Priority:
6. **Batch bank rename** (standard tools has this, useful for organization)
7. **Disk defrag** (compact free space, standard tools can do this)
8. **Multi-sampler support** (ESI-32, EIII - standard tools supports these)
9. **Format converter** (Akai → EMAX, SF2 → EMAX like Translator)

### Low Priority:
10. **Virtual drive mounting** (like Translator - mount .hda as drive)
11. **Beat slicer** (Translator feature - modern workflow)
12. **Favorite banks** (Translator feature - quick access)

## 📊 Comparison Matrix

| Feature | standard tools | Translator 6 | EmaxForge | Priority |
|---------|------|--------------|-----------|----------|
| Disk creation | ✅ | ❌ | ✅ | - |
| Bank validation | ✅ | ✅ | ❌ | **HIGH** |
| Checksum verify | ✅ | ✅ | ❌ | **HIGH** |
| Auto-repair | ✅ | ✅ | ❌ | **HIGH** |
| SCSI2SD support | ✅ | ❌ | Partial | **HIGH** |
| Multi-sampler | ✅ | ✅ | ❌ | Medium |
| Format convert | Limited | ✅ | ❌ | Medium |
| Batch ops | ✅ | ✅ | Partial | Medium |
| Health check | ✅ | ❌ | ❌ | Medium |
| Beat slicer | ❌ | ✅ | ❌ | Low |
| Virtual drives | ❌ | ✅ | ❌ | Low |

## 💡 Immediate Actions

### 1. Add Validation (This Week)
```swift
// BankImporter.swift
func validateBank(_ bank: Data) throws {
    // E2-001: Check size
    guard bank.count >= 512 else {
        throw ValidationError.invalidSize
    }
    
    // E2-002: Check preset count
    let presetCount = bank.readU16LE(at: 0x10)
    guard (1...100).contains(presetCount) else {
        throw ValidationError.invalidPresetCount(presetCount)
    }
    
    // E2-010: Verify checksum
    let expected = bank.readU32LE(at: bank.count - 4)
    let actual = calculateChecksum(bank)
    guard expected == actual else {
        throw ValidationError.checksumMismatch
    }
}
```

### 2. Add Health Check View (Next Week)
- Scan disk for corrupt banks
- Check FAT chain integrity
- Verify catalog consistency
- Report free space fragmentation

### 3. Add SCSI2SD.xml Export (Later)
- Generate XML from current zuluscsi.ini
- Support multi-partition configs
- Add vendor/quirks settings

## 📚 Reference Files

**Downloaded:**
- `~/Downloads/EmaxII-01.ez2` (96 MB - sample disk)
- `~/Downloads/EmaxII-02.ez2` (96 MB - sample disk)
- `~/Downloads/Telegram Desktop/standard toolsv311_referencemanual.txt` (1.8 MB)
- `~/Downloads/Telegram Desktop/Translator 6 Manual.txt` (221 KB)
- `~/Downloads/Translator 6.chm` (Windows help file)
- `~/Downloads/Translator 7 Free 7.1.0.005.dmg` (newer version!)

**Worth Reading:**
- standard tools pages 140-153 (validation rules)
- standard tools pages 776-810 (SCSI2SD config)
- Translator pages 17-20 (batch conversion)

## 🎯 Bottom Line

**standard tools and Translator are AMAZING references!**

EmaxForge already matches standard tools for basic disk creation, but we're missing:
1. **Validation** (standard tools's killer feature - prevents corrupt imports)
2. **Checksum** (why our disks might fail randomly!)
3. **Auto-repair** (standard tools fixes common errors silently)

**Next milestone:** Add validation + checksum → EmaxForge becomes bulletproof! 🛡️

---

## 🔍 Sample Disk Analysis (EmaxII-01.ez2, EmaxII-02.ez2)

**Files:** `~/Downloads/EmaxII-01.ez2` and `EmaxII-02.ez2`
**Size:** 96 MB each (EMAX II standard disk size)
**Format:** Raw EMAX II hard disk images

### Boot Sector Analysis

```
Magic: EMX2 (✅ Correct)
Boot signature: 0xA193 (❌ NOT 0x7882!)

Header bytes:
00: 45 4d 58 32  (EMX2 magic)
04: 00 ff 02 00  
08: 08 00 00 00  (8 FAT sectors?)
0C: 01 00 00 00
10: 09 00 00 00  (9 banks?)
14: 6f 00 00 00  (111 decimal - matches template!)
18: 02 00 00 00
1C: 06 00 00 00
20: 78 00 00 00  (120 = clusterAreaStartSector)
24: fd 05 00 00  (1533 decimal)
28: 01 01 ff ff
```

### Key Findings:

**Boot Signature Varies by Disk Size:**
```
96 MB:  0xA193 (these sample disks)
239 MB: 0x7882 (working Funkar disk)
```

**This explains why EmaxForge needs templates!** Boot signature is NOT universal.

### Template Update Needed:

```swift
// ImageTemplate.swift - ADD 96 MB template
static let template96MB = ImageTemplate(
    sizeMB: 96,
    totalSectors: 196608,
    clusterSize: 489472,  // Same as 239 MB
    clusterAreaStartSector: 120,  // Different!
    bootSignature: 0xA193,  // Different!
    bankCount: 111,
    // ... other fields
)
```

### Catalog Location Check:

```bash
# Should be at clusterAreaStart (sector 120 = 0xF000)
xxd -s 0xF000 -l 64 ~/Downloads/EmaxII-01.ez2
```

### Action Items:

1. ✅ **Extract exact template from EmaxII-01.ez2** (96 MB reference)
2. ⚠️ **Verify 481/633/962 MB boot signatures** (might differ!)
3. 📝 **Document boot signature variance** in ImageTemplate
4. 🧪 **Test EmaxForge with 96 MB disk** (currently uses 239 MB default)

### Sample Banks Available:

**These .ez2 files contain real EMAX II banks!**
- Can test bank import with real data
- Validate EmaxForge's bank browser against standard tools
- Perfect for testing corrupt bank handling

