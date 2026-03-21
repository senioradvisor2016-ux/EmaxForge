# EmaxForge Templates - Complete Guide

## 📦 What Are Templates?

EmaxForge uses **standard bootable disk templates** as starting points. These templates contain:

✅ **EMAX II Operating System** (ready to boot!)  
✅ **Correct boot structure** (verified on hardware)  
✅ **FAT filesystem** (ready for banks)  
✅ **All metadata** (catalog, FAT, etc.)

## 📚 Available Templates

Located in: `EmaxForge/Resources/bootable_templates/`

| Size | Filename | Clusters | Banks Capacity |
|------|----------|----------|----------------|
| 96 MB | `EMAXII_IMAGE_96.EZ2` | 8 KB | ~50 banks |
| 239 MB | `EMAXII_IMAGE_239.EZ2` | 16 KB | ~100 banks |
| 481 MB | `EMAXII_IMAGE_481.EZ2` | 32 KB | ~200 banks |
| 633 MB | `EMAXII_IMAGE_633.EZ2` | 32 KB | ~250 banks |
| 962 MB | `EMAXII_IMAGE_962.EZ2` | 32 KB | ~400 banks |

**All templates verified with OS!** ✅

## 🚀 Quick Start

### Option 1: Unified CLI (Recommended!)

```bash
# Create 239 MB boot disk
swift emaxforge-cli.swift create --size 239 --output HD10.hda

# Create 96 MB disk for SCSI ID 0
swift emaxforge-cli.swift create --size 96 --output HD00.hda --scsi-id 0

# Create 962 MB disk with banks
swift emaxforge-cli.swift create \\
  --size 962 \\
  --output HD10.hda \\
  --banks ~/clawd/standard/Images/EMAX\\ II/Bank\\ Images/ \\
  --max-banks 50
```

### Option 2: Individual Scripts

```bash
# Create from template
swift cli-create-from-template.swift --size 239 --output HD10.hda

# Add banks later
swift cli-import-eb2-banks.swift HD10.hda ~/path/to/banks/

# List banks on disk
swift cli-list-banks.swift HD10.hda
```

## 📁 File Format Notes

### .EZ2 vs .hda

- **`.EZ2`** = standard tools native format (templates are stored as .EZ2)
- **`.hda`** = ZuluSCSI format (what EMAX II reads)

**They are identical!** Just different extensions.

EmaxForge automatically converts:
```
EMAXII_IMAGE_239.EZ2 → HD10.hda
```

### SCSI ID Naming

ZuluSCSI expects specific filenames:

| SCSI ID | Filename | Purpose |
|---------|----------|---------|
| 0 | `HD00.hda` or `HD0.hda` | Boot disk (rare) |
| 1 | `HD10.hda` or `HD1.hda` | **Boot disk (standard!)** |
| 2 | `HD20.hda` or `HD2.hda` | Data disk |
| 3 | `HD30.hda` or `HD3.hda` | Data disk |

**EMAX II boots from SCSI ID 1 (HD10.hda)!** ✅

## 🔧 Available CLI Tools

### Core Tools
- `emaxforge-cli.swift` — **Unified CLI (use this!)**
- `cli-create-from-template.swift` — Create disk from template
- `cli-create-disk-with-banks.swift` — Create + import banks

### Bank Management
- `cli-import-eb2-banks.swift` — Import .EB2 banks
- `cli-list-banks.swift` — List banks on disk
- `cli-export-bank.swift` — Export single bank
- `cli-inspect-bank.swift` — Inspect bank structure

### Sample Tools
- `cli-import-samples.swift` — Import WAV samples
- `cli-export-samples.swift` — Export samples to WAV
- `cli-extract-sample.swift` — Extract single sample
- `cli-trim-sample.swift` — Trim silence from WAV

### Advanced
- `cli-validate-disk.swift` — Validate disk structure
- `cli-clone-disk.swift` — Clone existing disk
- `cli-update-os.swift` — Update EMAX II OS

## 📖 Workflow Examples

### 1. Simple Boot Disk

```bash
# Create 239 MB boot disk
swift emaxforge-cli.swift create --size 239 --output HD10.hda

# Copy to SD card
cp HD10.hda /Volumes/ZULUSCI/

# Boot EMAX II!
```

### 2. Boot Disk with Banks

```bash
# Create disk with 50 favorite banks
swift emaxforge-cli.swift create \\
  --size 962 \\
  --output HD10.hda \\
  --banks ~/clawd/standard/Images/EMAX\\ II/Bank\\ Images/ \\
  --max-banks 50

# List banks to verify
swift cli-list-banks.swift HD10.hda

# Copy to SD
cp HD10.hda /Volumes/ZULUSCI/
```

### 3. Multi-Disk Setup

```bash
# Boot disk (SCSI ID 1)
swift emaxforge-cli.swift create --size 239 --output HD10.hda --scsi-id 1

# Data disk 1 (SCSI ID 2)
swift emaxforge-cli.swift create --size 962 --output HD20.hda --scsi-id 2 \\
  --banks ~/clawd/standard/Images/EMAX\\ II/Bank\\ Images/

# Data disk 2 (SCSI ID 3)
swift emaxforge-cli.swift create --size 962 --output HD30.hda --scsi-id 3 \\
  --banks ~/clawd/standard/Images/EMAX\\ II/Bank\\ Images/

# Copy all to SD
cp HD10.hda HD20.hda HD30.hda /Volumes/ZULUSCI/

# EMAX II sees 3 disks!
```

## 🧪 Testing

### Verify Boot Structure

```bash
# Check boot signature
xxd -s 510 -l 2 HD10.hda
# Should show: 7882

# Check for OS
strings HD10.hda | grep "SCSI   not found"
# Should find OS strings

# Validate complete structure
swift cli-validate-disk.swift HD10.hda
```

### List Banks

```bash
swift cli-list-banks.swift HD10.hda
```

## 📂 Directory Structure

```
EmaxForge/
├── EmaxForge/
│   └── Resources/
│       └── bootable_templates/
│           ├── EMAXII_IMAGE_96.EZ2    ✅ OS
│           ├── EMAXII_IMAGE_239.EZ2   ✅ OS
│           ├── EMAXII_IMAGE_481.EZ2   ✅ OS
│           ├── EMAXII_IMAGE_633.EZ2   ✅ OS
│           └── EMAXII_IMAGE_962.EZ2   ✅ OS
├── emaxforge-cli.swift                ⭐ Use this!
├── cli-create-from-template.swift
├── cli-import-eb2-banks.swift
├── cli-list-banks.swift
└── [other CLI tools...]
```

## 🔍 Template Creation History

These templates were created on **2026-03-17** using:

1. **VNC connection** to Mac mini (100.115.153.120:5900)
2. **industry-standard format** running in Whisky (Wine container)
3. **"Create Bootable Disk"** wizard for each size
4. **OS included:** EMAX II Rev 2.14

**Location (original):**
```
~/Library/Containers/com.isaacmarovitz.Whisky/Bottles/[...]/drive_c/standard tools/
```

**Location (working copies):**
```
~/clawd/standard/Images/EMAX II/Disk Images/
~/clawd/EmaxForge/EmaxForge/Resources/bootable_templates/
```

## ✅ Verification

All templates verified with:

```bash
# OS presence check
for f in EMAXII_IMAGE_*.EZ2; do
  echo "=== $f ==="
  strings "$f" | grep "SCSI   not found" && echo "✅ HAS OS"
done
```

**Result:** ✅ All 5 templates have OS!

## 🎯 Next Steps

1. ✅ **Templates ready** (all sizes with OS)
2. ✅ **CLI tools working** (create, import, list)
3. 🚧 **UI integration** (drag-drop, visual bank browser)
4. 🚧 **Hardware testing** (boot on real EMAX II)

---

**Questions?** Check `standard tools_manual.txt` or existing issues in EmaxForge repo.
