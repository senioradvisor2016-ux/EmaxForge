# Emax Drive Complete Analysis

**Location:** `~/clawd/Emax Drive/`  
**Analysis Date:** 2026-03-17 07:15 CET  
**Total Size:** ~467 MB

---

## Directory Structure

```
Emax Drive/
├── 1. Blank/                    (1.9 MB)
├── 2. Demo disks/               (11 disks)
├── 3. OS/                       (4.6 MB)
├── 4. Doc/                      (746 KB)
├── 5. Other/                    (467 MB)
│   ├── Baldwin IKE Disks/       (5.3 MB)
│   ├── Downloads/               (361 MB)
│   ├── Emax II Unscrambled/     (4 MB)
│   ├── Factory Images/          (95 MB)
│   └── MIDI+RS-422 Specs/       (1.8 MB)
├── 6. Binary/                   (16 KB)
├── Emu Emax II [Sounds]/        (Library)
├── System Volume Information/
└── ZuluSCSI_EMAX2/
```

---

## File Type Breakdown

| Format | Count | Description |
|--------|-------|-------------|
| `.HFE` | 309 | HxC floppy emulator images (1.9 MB each) |
| `.hfe` | 89 | (lowercase variant) |
| `.EM1` | 61 | EMAX I banks |
| `.EB2` | 34 | **EMAX II banks** ← Main format! |
| `.pdf` | 12 | Documentation |
| `.txt` | 6 | Text files |
| `.zip` | 5 | Compressed archives |
| `.EZ1` | 5 | EMAX I HD images (standard tools format) |
| `.ez2` | 3 | EMAX II HD images (standard tools format, 96 MB each) |
| `.img` | 4 | Raw floppy images (800 KB) |
| `.EMX` | 1 | Operating system file (rev 2.14, 260 KB) |
| `.panel` | 1 | Front panel design |

**Total files:** ~550

---

## 1. Blank Templates

**Location:** `1. Blank/`

- `Blank.HFE` (1.9 MB) — Formatted blank floppy
- `duplicator.bat` (2.2 KB) — DOS batch script

**Use:** Starting point for creating new disks

---

## 2. Demo Disks

**Location:** `2. Demo disks/`  
**Count:** 11 demo banks (HFE format)

**Contents:**
- Jazz Bass (2 disks)
- Prophet T8 Strings (4 disks)
- MAX3_93_D50_SHAKU (2 disks)
- SYN_BASS_2_DX7
- Wurly Electric Piano
- More...

**Format:** `.HFE` floppy images

---

## 3. Operating System

**Location:** `3. OS/`

| File | Size | Description |
|------|------|-------------|
| `Emax II rev 2.14.EMX` | 260 KB | **OS binary** (raw) |
| `Emax II rev 2.14.HFE` | 1.9 MB | OS on floppy (HFE) |
| `Emax II rev 2.14.IMG` | 800 KB | OS floppy (raw IMG) |
| `Universal Sound Test Disk.img` | 800 KB | Diagnostic disk |
| `Universal Sound Test Disk 2.img` | 800 KB | Diagnostic disk v2 |

**Key:** `rev 2.14.EMX` är den OS-fil som EmaxForge använder!

---

## 4. Documentation

**Location:** `4. Doc/`

| File | Size | Description |
|------|------|-------------|
| `Emax II Diagnostics.pdf` | 192 KB | Hardware diagnostics |
| `Emax II Memory Expansion Retrofit.pdf` | 191 KB | RAM upgrade guide |
| `Emax II Stereo Upgrade.pdf` | 195 KB | Stereo output mod |
| `How to convert [Emax II].pdf` | 84 KB | Format conversion guide |
| `Information.pdf` | 84 KB | General info |

**Use:** Reference material för hardware/software specs

---

## 5. Other (Largest section)

### 5a. Baldwin IKE Disks
**Location:** `5. Other/Baldwin IKE Disks [ZD201-10]`  
**Size:** 5.3 MB

Baldwin Piano + EMAX II partnership disks.

---

### 5b. Downloads (361 MB!)

**Location:** `5. Other/Downloads/`

**EMAX II Factory Images:**
- `EmaxII-01.ez2` (96 MB)
- `EmaxII-02.ez2` (96 MB)
- `EmaxII-03.ez2` (96 MB)

**Total:** 288 MB of standard tools-format HD images!

**E-mu SP1200 Factory Set:**
- 23 files (unconfirmed/incomplete)

**FMS - Vol. 1 [EMAX]:**
- 55 files (EMAX I library)

---

### 5c. Factory Images (EMAX I)

**Location:** `5. Other/Emu Emax Bootable HD Factory Images for standard tools`

**EMAX I HD Images:**
- `EMAX1-1.EZ1` (19 MB)
- `EMAX1-2.EZ1` (19 MB)
- `EMAX1-3.EZ1` (19 MB)
- `EMAX1-4.EZ1` (19 MB)
- `EMAX1-5.EZ1` (19 MB)

**Total:** 95 MB

**Use:** EMAX I → EMAX II conversion testing

---

### 5d. Emax II Unscrambled Megs

**Location:** `5. Other/Emax II Unscrambled Megs`  
**Size:** 4 MB

Raw memory dumps (research material).

---

### 5e. MIDI + RS-422 Specs

**Location:** `5. Other/Emax-2-MIDI-and-RS-422-Specs.pdf`  
**Size:** 1.8 MB

Communication protocol documentation (MIDI SysEx, RS-422).

---

## 6. Binary

**Location:** `6. Binary/`

**Firmware/EEPROM dumps:**
- `EMU EMAX2 ic19 AM27C64.zip` (6.9 KB) — ROM chip dump
- `Emax 2 93c06 standard memory.zip` (194 B) — EEPROM config
- `Emu Emax II serial EEPROM (93C06N, from 8 MB EMAX II).zip` (244 B)

**Use:** Low-level hardware analysis, ROM reverse engineering

---

## 7. Emu Emax II [Sounds] — Main Library!

**Location:** `Emu Emax II [Sounds]/Sounds/`

### 7a. Alan Wilder - Depeche Mode [Emax II]

**Files:** 165 total
- **34 × .EB2 banks** (EMAX II native format)
- **131 × .HFE floppies** (multi-disk spanning)

**Example Banks:**
- `SOMEBODY.EB2` (1 MB) — "Personal Jesus"
- `EVERYTHING.EB2` (588 KB) — "Enjoy the Silence"
- `NOTHING.EB2` (458 KB) — "Nothing" samples
- `SACRED.EB2` — "Sacred" samples
- `CONDEM GUIDE.EB2` (7.5 MB) — Large multi-sample bank
- `FLYS ALAN.EB2` (5.6 MB)
- `EVERY A 93.EB2` (3 MB)

**Discovery:** All .EB2 files end with **0x81AD** magic bytes!

---

### 7b. E-mu Emax Universe of Sounds

**Location:** `Emu Emax II [Sounds]/Sounds/E-mu Emax Universe of Sounds [HFE format; SE11 OS]`

Factory sound library (HFE floppy format).

---

### 7c. [Emulator I disks]

**Location:** `Emu Emax II [Sounds]/Sounds/[Emulator I disks]`

Legacy Emulator I sample library (for conversion testing).

---

## Key Discoveries

### 1. .EB2 Format Analysis

**Signature:** All .EB2 banks end with `0x81AD` magic bytes  
**Header Structure:**
```
[counter][0x81AD]

Examples:
- 0x842081AD (SOMEBODY.EB2)
- 0x832081AD (BEHIND THE.EB2)
- 0x81AD81AD (EVERY A 93.EB2)
```

**First 2 bytes:** Likely sample/voice count

---

### 2. Multi-Disk Sets

Many banks span multiple floppies:
- `CONDEM GUIDE_1.HFE` through `CONDEM GUIDE_13.HFE` (13 disks!)
- `MERCY ALAN_14.HFE`, `MERCY ALAN_15.HFE`, `MERCY ALAN_16.HFE`

**Insight:** Large sample libraries need spanning support.

---

### 3. standard tools Format Presence

**3 × .ez2 HD images** (96 MB each) in Downloads — standard tools-native format!

**Use for EmaxForge:**
- Import/export testing
- Format validation reference
- Cross-compatibility verification

---

## EmaxForge Test Strategy

### Phase 1: .EB2 Bank Parsing ✅
- [x] Hex dump analysis (cli-inspect-bank.swift)
- [x] 0x81AD signature detection
- [ ] Full bank structure parser

### Phase 2: Sample Extraction
- [ ] Extract WAV from .EB2
- [ ] Multi-sample banks
- [ ] Loop point preservation

### Phase 3: Multi-Disk Support
- [ ] Spanning detection (CONDEM GUIDE_1..13)
- [ ] Merge multi-disk banks
- [ ] Split large banks for floppy export

### Phase 4: standard tools Integration
- [ ] Import .ez2 HD images
- [ ] Export to standard tools format
- [ ] Validate against factory images

### Phase 5: Cross-Platform Conversion
- [ ] EMAX I → EMAX II (5 × .EZ1 images)
- [ ] Emulator I → EMAX II
- [ ] SP-1200 → EMAX II (if format documented)

---

## Reference Materials Available

**Documentation:**
- Diagnostics manual ✅
- Memory expansion guide ✅
- Stereo upgrade guide ✅
- Conversion guide ✅

**Firmware:**
- ROM dumps ✅
- EEPROM configs ✅

**Protocols:**
- MIDI SysEx spec ✅
- RS-422 spec ✅

**Sample Libraries:**
- 34 × .EB2 banks (Alan Wilder) ✅
- 309 × .HFE floppies ✅
- 61 × .EM1 banks (EMAX I) ✅
- 3 × .ez2 HD images (96 MB) ✅
- 5 × .EZ1 HD images (19 MB) ✅

---

## Next Steps for EmaxForge

1. **Parse .EB2 structure** (sample data, voice assignments, zones)
2. **Extract samples to WAV** (test with SOMEBODY.EB2)
3. **Handle multi-disk banks** (merge CONDEM GUIDE_1..13)
4. **Import standard tools .ez2** (factory images as reference)
5. **EMAX I conversion** (use .EZ1 images)

**Test Data Priority:**
1. Alan Wilder banks (34 × .EB2) — Real-world complexity
2. Demo disks (11 × HFE) — Simple test cases
3. Factory images (3 × .ez2) — Reference implementation

---

## Conclusion

**Emax Drive = Complete EMAX II Development Kit!**

- ✅ OS files
- ✅ Factory images
- ✅ Real-world sample libraries
- ✅ Multi-disk spanning examples
- ✅ Cross-platform conversion sources
- ✅ Hardware documentation
- ✅ Protocol specs

**Total value:** Priceless for EmaxForge development! 🎹🔥
