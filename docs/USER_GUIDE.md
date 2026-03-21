# EmaxForge v0.5 Beta - User Guide

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Creating Boot Disks](#creating-boot-disks)
5. [Managing Banks](#managing-banks)
6. [Floppy Support](#floppy-support)
7. [CLI Reference](#cli-reference)
8. [Troubleshooting](#troubleshooting)

---

## Introduction

EmaxForge is a modern macOS application for managing E-mu EMAX II disk images for use with ZuluSCSI hardware. It replaces standard tools (Windows-only) with a native Mac experience plus powerful CLI tools.

### What EmaxForge Does

- Creates bootable EMAX II hard disk images
- Manages sample banks (.EB2 files)
- Creates floppy images for Gotek/HxC emulators
- Generates ZuluSCSI configuration files
- 100% compatible with industry-standard format

### What You Need

- Mac running macOS 14.0 (Sonoma) or later
- EMAX II synthesizer
- ZuluSCSI Pico (or compatible SCSI storage emulator)
- SD card (FAT32 or exFAT formatted)

---

## Installation

### GUI App

1. Download `EmaxForge.app.zip` from releases
2. Unzip the file
3. Drag `EmaxForge.app` to Applications folder
4. First launch: Right-click → Open (to bypass Gatekeeper)

### CLI Tools (Optional)

```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/EmaxForge.git
cd EmaxForge/agent-harness

# Install CLI
pip install -e .

# Verify installation
cli-anything-emaxforge --help
```

---

## Quick Start

### Create Your First Boot Disk

**GUI Method:**
1. Launch EmaxForge
2. Click **"Create Boot Disk"** in toolbar
3. Select disk size: **239 MB** (recommended)
4. SCSI ID: **1** (default)
5. Click **Create**
6. Save as `HD10.hda`

**CLI Method:**
```bash
cli-anything-emaxforge create-boot-disk \
  --size 239 \
  --output ~/Desktop/HD10.hda
```

### Prepare SD Card

1. Format SD card (FAT32 for <32GB, exFAT for larger)
2. Copy `HD10.hda` to SD card root
3. Create `zuluscsi.ini`:
```ini
[SCSI]
EnableParity = 1

[SCSI1]
Type = 0
BlockSize = 512
```
4. Eject SD card safely

### Boot EMAX II

1. Insert SD card into ZuluSCSI Pico
2. Connect ZuluSCSI to EMAX II SCSI port
3. Power on EMAX II
4. You should see "EMAX II" splash screen
5. Main menu appears after boot

---

## Creating Boot Disks

### Disk Sizes

EmaxForge supports 5 standard tools-standard disk sizes:

| Size | Use Case |
|------|----------|
| 96 MB | Minimal (OS + few banks) |
| **239 MB** | **Recommended** (good balance) |
| 481 MB | Large library |
| 633 MB | Very large library |
| 962 MB | Maximum capacity |

### SCSI IDs Explained

EMAX II boots from **SCSI ID 1** (not 0):
- **HD10.hda** = SCSI ID 1 (boot disk - contains OS)
- **HD20.hda** = SCSI ID 2 (data disk - samples only)
- **HD30.hda** = SCSI ID 3 (data disk - samples only)

### Multi-Disk Setup

**Example: Boot + 2 Data Disks**

1. Create boot disk (239 MB):
```bash
cli-anything-emaxforge create-boot-disk \
  --size 239 \
  --output HD10.hda
```

2. Create data disks (481 MB each):
```bash
cli-anything-emaxforge create-disk \
  --size 481 \
  --output HD20.hda

cli-anything-emaxforge create-disk \
  --size 481 \
  --output HD30.hda
```

3. Update `zuluscsi.ini`:
```ini
[SCSI]
EnableParity = 1

[SCSI1]
Type = 0
BlockSize = 512

[SCSI2]
Type = 0
BlockSize = 512

[SCSI3]
Type = 0
BlockSize = 512
```

---

## Managing Banks

### Import Banks

**GUI:**
1. Open existing disk image
2. Click **"Import Banks"**
3. Select `.EB2` files
4. Choose target disk (HD20, HD30, etc.)
5. Click **Import**

**CLI:**
```bash
cli-anything-emaxforge import-bank \
  --image HD20.hda \
  --bank "Path/To/MyBank.eb2"
```

### Export Banks

**CLI:**
```bash
cli-anything-emaxforge export-bank \
  --image HD20.hda \
  --bank-name "STEEL DRUMS" \
  --output "Exported_Bank.eb2"
```

### List Banks

**CLI:**
```bash
cli-anything-emaxforge list-banks HD20.hda

# JSON output
cli-anything-emaxforge list-banks HD20.hda --json
```

---

## Floppy Support

### Create Gotek/HxC Floppy

EMAX II uses 800KB floppies (non-standard):

**GUI:**
1. Click **"Create Floppy"**
2. Select size: **800 KB**
3. Format: **HFE v3**
4. Save as `FD00.hfe`

**CLI:**
```bash
cli-anything-emaxforge create-floppy \
  --size 800 \
  --format hfe \
  --output FD00.hfe
```

### Standard Floppy Sizes

| Size | Type | Use Case |
|------|------|----------|
| 720 KB | DD | Standard PC floppy |
| **800 KB** | **EMAX II** | **Native EMAX II format** |
| 1.44 MB | HD | High-density PC floppy |

---

## CLI Reference

### Common Commands

```bash
# Create boot disk
cli-anything-emaxforge create-boot-disk --size 239 --output boot.hda

# Create blank disk
cli-anything-emaxforge create-disk --size 481 --output data.hda

# Create floppy
cli-anything-emaxforge create-floppy --size 800 --output floppy.hfe

# Import bank
cli-anything-emaxforge import-bank --image data.hda --bank mybank.eb2

# List images
cli-anything-emaxforge list-images ~/Desktop/

# Verify boot disk
cli-anything-emaxforge verify-boot boot.hda

# Interactive mode (REPL)
cli-anything-emaxforge repl
```

### All Commands

```bash
cli-anything-emaxforge --help
```

Shows all 24 available commands.

---

## Troubleshooting

### EMAX II Won't Boot

**Check 1: SCSI ID**
- Boot disk MUST be SCSI ID 1
- Filename MUST be `HD10.hda` (two digits)
- Not `HD0.hda` or `HD1.hda`

**Check 2: SD Card Format**
- Use FAT32 (for SD <32GB)
- Use exFAT (for SD ≥32GB)
- Avoid NTFS or HFS+

**Check 3: Boot Signature**
```bash
cli-anything-emaxforge verify-boot HD10.hda
```
Should show all checks passing.

**Check 4: zuluscsi.ini**
- Must have `[SCSI1]` section
- `BlockSize = 512` required
- Check spelling and syntax

### "SCSI Not Found" Error

- Check ZuluSCSI connections
- Verify SD card inserted properly
- Try different SD card
- Check `zuluscsi.ini` syntax

### Disk Shows Empty in EMAX II

- Wrong SCSI ID (use HD10 for boot, HD20+ for data)
- Corrupted image (verify with `verify-boot`)
- Missing FAT entries (rebuild with EmaxForge)

### CLI Command Not Found

```bash
# Reinstall CLI
cd EmaxForge/agent-harness
pip install -e . --force-reinstall
```

### GUI Won't Launch

- macOS 14.0+ required
- Right-click → Open (first time)
- Check Console.app for errors

---

## Advanced Topics

### Custom OS Versions

Place EMAX II OS files in:
```
~/Library/Application Support/EmaxForge/OS/
```

### Batch Operations

```bash
# Create 10 data disks
for i in {2..11}; do
    cli-anything-emaxforge create-disk \
        --size 481 \
        --output "HD${i}0.hda"
done
```

### Automation

Use AppleScript to drive the GUI:
```applescript
tell application "EmaxForge"
    activate
    -- your automation here
end tell
```

---

## Support

- **Issues:** [GitHub Issues](https://github.com/YOUR_USERNAME/EmaxForge/issues)
- **Discussions:** [GitHub Discussions](https://github.com/YOUR_USERNAME/EmaxForge/discussions)

---

## Appendix: Spec Compliance

EmaxForge is **100% compliant** with:
- industry-standard format disk format specification
- ZuluSCSI file naming conventions
- E-mu EMAX II filesystem structure

See [COMPLIANCE_REPORT.md](../COMPLIANCE_REPORT.md) for details.

---

**Version:** 0.5 Beta
**Last Updated:** 2026-03-18
