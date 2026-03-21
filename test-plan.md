# EmaxForge v0.5 Beta - Hardware Test Plan

## Pre-Test: Create Fresh Boot Disk

**Via CLI:**
```bash
cli-anything-emaxforge create-boot-disk \
  --size 239 \
  --output ~/Desktop/EMAXFORGE_TEST_BOOT.hda \
  --scsi-id 1
```

**Via GUI:**
1. Launch EmaxForge.app
2. Click "Create Boot Disk" in toolbar
3. Select 239 MB
4. Include OS: YES
5. SCSI ID: 1 (default)
6. Create → Save to Desktop as EMAXFORGE_TEST_BOOT.hda

## Test 1: Boot Disk Structure (Pre-Hardware)

```bash
# Verify boot signature
xxd -s 0x1FE -l 2 ~/Desktop/EMAXFORGE_TEST_BOOT.hda
# Expected: 0000 01fe: 7882  x.
# (0x78 0x82 for 239 MB)

# Verify FAT entry 0
xxd -s 0x400 -l 2 ~/Desktop/EMAXFORGE_TEST_BOOT.hda
# Expected: 0000 0400: 0f00  ..
# (0x000F little-endian)

# Verify OS at cluster 0 (offset 0xC400)
xxd -s 0xC400 -l 16 ~/Desktop/EMAXFORGE_TEST_BOOT.hda
# Expected: Non-zero OS data
```

## Test 2: ZuluSCSI SD Card Setup

1. Format SD card (FAT32 or exFAT)
2. Copy EMAXFORGE_TEST_BOOT.hda → HD10.hda
3. Create zuluscsi.ini:
```ini
[SCSI]
EnableParity = 1

[SCSI1]
Type = 0
BlockSize = 512
```

## Test 3: EMAX II Boot Test

**Insert SD card → Power on EMAX II**

✅ **SUCCESS indicators:**
- EMAX II displays "EMAX II" splash screen
- OS loads without errors
- Main menu appears
- Can navigate menus

❌ **FAILURE indicators:**
- Blank screen / no boot
- "SCSI not found" error
- Freeze at splash screen

## Test 4: Multi-Disk + Banks (If Boot Works)

**Create data disk with samples:**
```bash
cli-anything-emaxforge create-disk \
  --size 239 \
  --output ~/Desktop/EMAXFORGE_DATA.hda

cli-anything-emaxforge import-bank \
  --image ~/Desktop/EMAXFORGE_DATA.hda \
  --bank path/to/sample.eb2
```

**SD card layout:**
```
/SD_CARD/
  HD10.hda     # Boot disk (OS only)
  HD20.hda     # Data disk (samples)
  zuluscsi.ini
```

**Test on EMAX II:**
- Boot from HD10
- Load banks from HD20
- Verify samples play correctly

## Test 5: Floppy Emulation (Gotek)

**Create floppy:**
```bash
cli-anything-emaxforge create-floppy \
  --size 800 \
  --output ~/Desktop/EMAXFORGE_FLOPPY.hfe
```

**Test on Gotek/HxC:**
- Load HFE on Gotek USB
- EMAX II recognizes floppy drive
- Can read/write banks to floppy

---

## Expected Results:

| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| Boot structure | 0x78 0x82 signature | | |
| FAT entry 0 | 0x000F | | |
| EMAX II boot | OS loads | | |
| Multi-disk | Both disks visible | | |
| Floppy | Gotek recognized | | |

---

**Next:** Execute tests and document results!
