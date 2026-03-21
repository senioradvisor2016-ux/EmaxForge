# standard tools EMAX-II Specification
## Extracted from industry-standard format Reference Manual

**Source:** standard toolsv311_referencemanual.txt (493 pages)  
**Purpose:** Complete EMAX-II disk format specification for EmaxForge validation  
**Date:** 2026-03-16

---

## 1. SUPPORTED DISK SIZES (Page 31, 62-68)

standard tools supports exactly **5 EMAX-II disk sizes:**

| Size (MB) | Bytes | Description |
|-----------|-------|-------------|
| 96 | 100,663,296 | Smallest |
| 239 | 250,609,664 | Default |
| 481 | 504,365,056 | Medium |
| 633 | 663,748,608 | Large |
| 962 | 1,008,730,112 | Maximum |

**Critical:** These are the ONLY valid sizes. standard tools will reject any other size.

---

## 2. FILE EXTENSIONS (Page 62, Table 4.5.1)

### EMAX-II Bank Files
- `.EB2` - Bank file (sound banks only, no OS)

### EMAX-II Disk Images
- `.EM2` - EMX file (may contain OS + banks, can be multi-part)
- `.EM2FD` - Floppy disk image (800KB, DSDD)
- `.EZ2` - Hard disk image (**preferred for HD images**)
- `.ISO` - Generic hard disk image (optional, enabled by default)
- `.IMG` - Generic hard disk image (optional, disabled by default)

### EMAX-II Operating System
- `.EMX` - Operating system file (e.g. "Emax II rev 2.14.EMX")

**Factory Default Folder:** `\Images` (for all EMAX-II files except OS)  
**OS Folder:** `\Os`

---

## 3. DISK STRUCTURE OVERVIEW

### 3.1 Boot Sector (Sector 0, Offset 0x000-0x1FF)

**Critical fields (from standard tools source analysis + manual):**

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0x00 | 4 bytes | Cluster Size | **Little-endian** UInt32 |
| 0x04 | 4 bytes | Cluster Area Start Sector | **Little-endian** UInt32 |
| 0x14 | 4 bytes | Bank Count | **Little-endian** UInt32 |
| 0x1FE | 1 byte | Boot Signature Byte 1 | **0x78** |
| 0x1FF | 1 byte | Boot Signature Byte 2 | **0x82** |

**Boot Signature:** `0x78 0x82` (NOT `0x55 0xAA` like PC boot sectors!)

---

### 3.2 FAT (File Allocation Table)

**Location:** Sector 1 (offset 0x200)  
**Size:** 512 bytes (1 sector)  
**Entry Size:** 2 bytes (16-bit little-endian)

**Standard FAT entries (from MEMORY.md + manual validation):**

| Entry # | Offset | Value | Meaning |
|---------|--------|-------|---------|
| 0 | 0x200 | **0x000F** | FAT header (NOT 0x8000!) |
| 1 | 0x202 | **0x0000** | Reserved |
| 2 | 0x204 | **0x7FFF** | INIT BANK end marker |
| 3+ | 0x206+ | **0x8080** | Free clusters (fill rest of FAT) |

**Critical:** FAT entry 0 = `0x000F` (was wrongly documented as `0x8000` in early analysis)

---

### 3.3 Catalog (Bank Directory)

**Location:** Sector 2 (offset 0x400)  
**Size:** Multiple sectors (depends on disk size)  
**Entry Size:** 32 bytes

**Catalog Entry Structure:**

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0x00 | 16 bytes | Bank Name | ASCII, space-padded |
| 0x10 | 4 bytes | Cluster Number | Little-endian UInt32 |
| 0x1A | 2 bytes | FLAGS | **0x0081** (little-endian) = **0x81 0x00** |

**Standard Catalog Entries:**

**Entry 0: Operating System (if present)**
```
Offset 0x400: "EMAX2 Software  " (16 bytes, space-padded)
Offset 0x410: 0x01 0x00 0x00 0x00 (cluster 1, little-endian)
Offset 0x41A: 0x81 0x00 (FLAGS = 0x0081, little-endian)
```

**Entry 1: INIT BANK (mandatory for boot disks)**
```
Offset 0x420: "INIT BANK       " (16 bytes, space-padded)
Offset 0x430: 0x02 0x00 0x00 0x00 (cluster 2, little-endian)
Offset 0x43A: 0x81 0x00 (FLAGS = 0x0081, little-endian)
```

**FLAGS Byte Order:**
- In memory/file: `0x0081` (little-endian 16-bit value)
- As bytes: `[0x81, 0x00]`
- **NOT** `[0x00, 0x81]`!

---

### 3.4 Cluster Area (Sample Data + Banks)

**Start:** Varies by disk size (see cluster_area_start_sector)  
**Cluster Numbering:** Cluster 1 = first cluster (NOT cluster 0)

**Cluster 1: Operating System (if present)**
- Contains OS binary data (e.g. "Emax II rev 2.14.EMX" content)
- Size: ~260KB for rev 2.14

**Cluster 2: INIT BANK**
- Minimal bank structure
- Marks disk as bootable
- Mandatory for boot disks (EMAX-II won't boot without it!)

---

## 4. DISK SIZE TEMPLATES (from MEMORY.md validation)

### 4.1 Template: 96 MB

```
Size:               96 MB (100,663,296 bytes)
Cluster Size:       262,144 bytes
Cluster Area Start: Sector 98
Boot Signature:     0x78 0x82
Bank Count:         111
```

### 4.2 Template: 239 MB (Default)

```
Size:               239 MB (250,609,664 bytes)
Cluster Size:       524,288 bytes
Cluster Area Start: Sector 98
Boot Signature:     0x78 0x82
Bank Count:         90
```

### 4.3 Template: 481 MB

```
Size:               481 MB (504,365,056 bytes)
Cluster Size:       524,288 bytes
Cluster Area Start: Sector 194
Boot Signature:     0x78 0x82
Bank Count:         182
```

### 4.4 Template: 633 MB

```
Size:               633 MB (663,748,608 bytes)
Cluster Size:       524,288 bytes
Cluster Area Start: Sector 258
Boot Signature:     0x78 0x82
Bank Count:         239
```

### 4.5 Template: 962 MB

```
Size:               962 MB (1,008,730,112 bytes)
Cluster Size:       524,288 bytes
Cluster Area Start: Sector 386
Boot Signature:     0x78 0x82
Bank Count:         363
```

---

## 5. OPERATING SYSTEM FILES

### 5.1 Supported OS Versions (Page 221-234)

**EMAX-II Operating Systems:**
- **"Emax II rev 2.14.EMX"** - Standard OS (260KB)
- **"EMAX2 OS PLUS 1.0"** - OS Plus variant

**Location on Disk:**
- Cluster 1 (first cluster in cluster area)
- NOT at sector offset! (Common mistake)

**Calculation:**
```
OS_offset = cluster_area_start_sector × 512
```

**Example (239 MB disk):**
```
Cluster area start: sector 98
OS offset: 98 × 512 = 50,176 bytes

Cluster 1 offset: 50,176 + 0 = 50,176 bytes (NOT 50,176 + 524,288!)
```

---

## 6. BANK NAMING CONVENTIONS (Page 699-721)

### 6.1 Character Set

**Valid Characters:**
- A-Z (uppercase)
- 0-9 (digits)
- Space (0x20)
- Special: `! " # $ % & ' ( ) * + , - . / : ; < = > ? @ [ \ ] ^ _ { | } ~`

**Invalid Characters:**
- Lowercase letters (a-z) - **will be auto-converted to uppercase**
- Control characters (0x00-0x1F, 0x7F-0xFF)

### 6.2 Bank Name Rules

**Length:** Exactly 16 characters (space-padded if shorter)

**Standard Bank Names:**
- `"EMAX2 Software  "` - Operating System
- `"INIT BANK       "` - Initial empty bank

**User Bank Names:**
- Any valid 16-char string
- Auto-padded with spaces if < 16 chars
- Spaces are allowed and preserved

---

## 7. SCSI2SD SUPPORT (Page 65-68, 103-114, 776-810)

### 7.1 SCSI2SD Partitions (Devices)

**Support:** Up to 7 partitions per SD card  
**File Extensions:**
- `.ISO` - SCSI2SD image (enabled by default)
- `.IMG` - SCSI2SD image (enabled by default)

**NOT supported:**
- `.EZ2` extension for SCSI2SD images

### 7.2 Device Naming

**Format:** `HD{ID}.hda` or `HD{ID}0.hda`

**Examples:**
- `HD0.hda` or `HD00.hda` - SCSI ID 0
- `HD1.hda` or `HD10.hda` - SCSI ID 1 (**boot disk!**)
- `HD2.hda` or `HD20.hda` - SCSI ID 2

**Critical Discovery (MEMORY.md):**
EMAX-II boots from SCSI ID **1** (HD10.hda), NOT SCSI ID 0!

---

## 8. VALIDATION RULES (Page 140-153)

### 8.1 Boot Disk Validation

**Mandatory for bootable disk:**
1. ✅ Boot signature = `0x78 0x82`
2. ✅ FAT entry 0 = `0x000F`
3. ✅ FAT entry 1 = `0x0000`
4. ✅ FAT entry 2 = `0x7FFF` (INIT BANK end marker)
5. ✅ Catalog entry 0 = OS ("EMAX2 Software")
6. ✅ Catalog entry 1 = INIT BANK
7. ✅ OS data present in cluster 1
8. ✅ INIT BANK data present in cluster 2

### 8.2 Error Codes (EMAX-I/II, Page 143-145)

**Boot-related errors:**
- `E001` - Invalid boot signature
- `E002` - Invalid sector size
- `E003` - Invalid cluster size
- `E004` - Invalid FAT structure
- `E005` - Missing or corrupt catalog
- `E006` - Invalid bank count

**Bank-related errors:**
- `E010` - Invalid bank name
- `E011` - Invalid cluster pointer
- `E012` - Invalid FLAGS value
- `E013` - Missing sample data

---

## 9. FILE FORMATS

### 9.1 EMX Files (.EM2)

**Structure:**
- May contain OS + banks
- Can be multi-part (Part #1, Part #2, ...)
- Used for floppy disk storage (800KB DSDD)

**Multi-part naming:**
```
BANKNAME.EM2        - Part 1
BANKNAME Part #2.EM2 - Part 2
BANKNAME Part #3.EM2 - Part 3
```

### 9.2 Bank Files (.EB2)

**Structure:**
- Sound banks ONLY (no OS)
- Single file per bank
- Preferred format for libraries

**Advantages over .EM2:**
- No OS overhead
- Single-file per bank
- Faster to process

### 9.3 Hard Disk Images (.EZ2)

**Structure:**
- Raw disk image (byte-for-byte clone)
- Contains header, FAT, catalog, clusters
- Can contain multiple banks + OS

**File Size = Disk Size:**
- 96 MB image = 100,663,296 bytes
- 239 MB image = 250,609,664 bytes
- etc.

---

## 10. CONVERSION CONSTRAINTS (Page 397-409)

### 10.1 Sample Rate

**EMAX-II Native:**
- 44.1 kHz (CD quality)
- 22.05 kHz (half-rate)

**Conversion:**
- Can resample from any source rate
- Quality loss when downsampling
- Preserves loops during conversion

### 10.2 Memory Size

**EMAX-II Memory:**
- Standard: 2 MB, 4 MB, 8 MB
- Turbo: 4 MB, 8 MB, 16 MB

**Bank Size Limits:**
- Must fit in available sampler RAM
- standard tools can split banks if needed

### 10.3 Stereo Handling

**Options:**
- Convert stereo → dual mono (2 presets)
- Convert stereo → single mono (mix down)
- Preserve stereo as linked samples

---

## 11. COPY FLOWS (Page 35-37)

### 11.1 Supported Copy Operations

**EMAX-II → EMAX-II:**
```
.EM2 file → .EM2 file
.EM2 file → Hard disk
.EB2 file → .EB2 file
.EB2 file → Hard disk
Hard disk → .EB2 file
Hard disk → .EZ2 image
.EZ2 image → .EZ2 image
.EZ2 image → Hard disk
Floppy disk → Floppy disk image
Floppy disk image → Floppy disk
```

**OS Copying:**
```
OS file (.EMX) → Floppy disk
OS file (.EMX) → Hard disk
OS file (.EMX) → Disk image
Disk → OS file
Disk image → OS file
```

---

## 12. CRITICAL IMPLEMENTATION NOTES

### 12.1 Common Mistakes (from MEMORY.md bug fixes)

**❌ WRONG:**
```swift
// Boot signature (PC-style)
data[0x1FE] = 0x55
data[0x1FF] = 0xAA

// FAT entry 0 (wrong value)
writeU16LE(0x8000, at: 0x200)

// FLAGS (wrong byte order)
writeU16LE(0x8100, at: catalogOffset + 26)

// OS location (wrong calculation)
let osOffset = clusterAreaStart + clusterSize // Cluster 2!
```

**✅ CORRECT:**
```swift
// Boot signature (EMAX-II specific)
data[0x1FE] = 0x78
data[0x1FF] = 0x82

// FAT entry 0 (correct value)
writeU16LE(0x000F, at: 0x200)

// FLAGS (correct byte order)
writeU16LE(0x0081, at: catalogOffset + 26)

// OS location (correct calculation)
let osOffset = clusterAreaStart // Cluster 1!
```

### 12.2 Validation Checklist

**Before releasing any disk:**
1. ✅ Verify boot signature = `0x78 0x82`
2. ✅ Verify FAT entry 0 = `0x000F`
3. ✅ Verify FAT entry 1 = `0x0000`
4. ✅ Verify FAT entry 2 = `0x7FFF`
5. ✅ Verify FLAGS = `0x0081` (bytes: `0x81 0x00`)
6. ✅ Verify OS at cluster 1 (NOT cluster 2)
7. ✅ Verify INIT BANK at cluster 2
8. ✅ Test boot on real EMAX-II hardware

---

## 13. standard tools VALIDATION LOGIC (Reverse-engineered)

### 13.1 Disk Recognition Algorithm

```
1. Read boot sector (offset 0x000-0x1FF)
2. Check boot signature (0x1FE-0x1FF) == 0x78 0x82
3. Read cluster size (offset 0x00)
4. Read cluster area start (offset 0x04)
5. Read bank count (offset 0x14)
6. Validate against known templates (96/239/481/633/962 MB)
7. Read FAT (offset 0x200)
8. Validate FAT entry 0 == 0x000F
9. Read catalog (offset 0x400+)
10. Validate catalog entries (bank names, FLAGS, cluster pointers)
```

### 13.2 Boot Disk Validation

```
1. Run disk recognition (above)
2. Check catalog entry 0 name == "EMAX2 Software"
3. Check catalog entry 0 cluster == 1
4. Check catalog entry 1 name == "INIT BANK"
5. Check catalog entry 1 cluster == 2
6. Verify OS data present at cluster 1
7. Verify FAT entry 2 == 0x7FFF (INIT BANK end marker)
```

---

## 14. REFERENCES

### 14.1 Source Documents

1. **industry-standard format Reference Manual** (493 pages)
   - Path: `~/clawd/standard toolsv311_referencemanual.txt`
   - Sections: 1-13 (all)

2. **MEMORY.md - EmaxForge Boot Bug Fixes**
   - Path: `~/clawd/MEMORY.md`
   - Dates: Mar 3-8, 2026
   - Critical discoveries re: boot structure

3. **standard tools Binary Analysis**
   - Ghidra decompilation (3395 functions)
   - Hexdump validation (byte-for-byte)
   - Reports: `standard tools_VALIDATION_REPORT.md`, `BOOT_SECTOR_ANALYSIS.md`

### 14.2 Test Hardware

**Known working EMAX-II configurations:**
- EMAX-II Turbo Rack 4MB (type 2213) running OS 2.14
- EMAX-II Turbo Keyboard 4MB (type 2212) running OS 2.14
- EMAX-II Turbo Keyboard 8MB (type 2205) running OS 2.14

**Tested Storage:**
- IOMEGA 250M ZIP drive SCSI
- IOMEGA 100M ZIP drive SCSI
- SD HxC hardware floppy emulator
- SCSI2SD version 5 board

---

## 15. VERSION HISTORY

- **v1.0** (2026-03-16) - Initial extraction from industry-standard format manual
- **v1.1** (2026-03-16) - Added MEMORY.md bug fix corrections
- **v1.2** (2026-03-16) - Added SCSI2SD boot discovery (HD10.hda)

---

**END OF SPECIFICATION**

**Next Steps:**
1. Validate EmaxForge against this spec (byte-for-byte)
2. Create automated test suite (all 5 sizes × 2 OS variants)
3. Run comparison against standard tools CLI output
4. Document any deviations found
5. Update ImageCreator.swift if needed
