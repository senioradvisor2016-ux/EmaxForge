# Hardware Test - EmaxForge Boot Disk

**Datum:** 8 mars 2026 13:06
**Version:** Post catalog/OS offset fix

## Test Setup

### Files to Copy to SD Card:
```
~/Desktop/HD10.hda  → Boot disk (SCSI ID 1, with OS)
~/Desktop/HD20.hda  → Data disk (SCSI ID 2, empty)
```

### ZuluSCSI Config:
Create `zuluscsi.ini` on SD card:
```ini
; ZuluSCSI config for EMAX II
[SCSI]
EnableParity = 1

[SCSI1]
```

## Test Procedure

1. **Prepare SD Card:**
   - Format SD card (FAT32)
   - Copy HD10.hda to SD root
   - Copy HD20.hda to SD root (optional)
   - Create zuluscsi.ini

2. **Insert in EMAX II:**
   - Power off EMAX II
   - Insert SD card in ZuluSCSI
   - Power on

3. **Expected Result:**
   - ✅ EMAX II boots
   - ✅ Shows OS version on screen
   - ✅ Can access menus

4. **If it doesn't boot:**
   - Check ZuluSCSI LED (blinking = reading)
   - Try only HD10.hda (remove HD20)
   - Check zuluscsi.ini location (must be in SD root)

## Verification Commands (before test)

```bash
# Check file sizes
ls -lh ~/Desktop/HD*.hda

# Verify boot signature
xxd -s 0x1FE -l 2 ~/Desktop/HD10.hda
# Expected: 7882

# Verify OS exists
xxd -s 0xD720 -l 16 ~/Desktop/HD10.hda
# Expected: b7ce 59ce 3ace 31ce 6bce f7ce 73cf 09d0

# Compare with working disk
cmp ~/clawd/SD_BOOT/Funkar/HD10.hda ~/Desktop/HD10.hda
# Will differ (standard tools has sample banks, EmaxForge is OS-only)
```

## What's Different from standard tools Disk?

| Feature | standard tools (Funkar) | EmaxForge (New) | Impact |
|---------|---------------|-----------------|--------|
| Boot signature | ✅ 0x7882 | ✅ 0x7882 | Same |
| Catalog offset | ✅ 0xC400 | ✅ 0xC400 | Same |
| OS offset | ✅ 0xD720 | ✅ 0xD720 | Same |
| OS data | Old version | FUNKAR.EMX | Different but both bootable |
| Sample banks | Yes (many) | No (OS only) | standard tools has data, EmaxForge is empty |
| Status table | Filled | Minimal | Expected difference |

## Expected Outcome

**SHOULD BOOT** because:
1. ✅ Boot signature correct (0x7882)
2. ✅ Catalog at correct offset (0xC400)
3. ✅ OS at correct offset (0xD720)
4. ✅ OS from verified bootable FUNKAR.EMX
5. ✅ SCSI ID 1 (confirmed working)

**Known differences:**
- EmaxForge disk has NO sample banks (empty after OS)
- Status table different (less data)
- This is EXPECTED and should still boot!

## If Boot Fails

Check these in order:
1. Boot signature (xxd -s 0x1FE -l 2)
2. Catalog entry (xxd -s 0xC400 -l 32)
3. OS data (xxd -s 0xD720 -l 64)
4. FAT entries (xxd -s 0x400 -l 32)

## Success Criteria

- [ ] EMAX II powers on
- [ ] Display shows bootup sequence
- [ ] Can navigate menus
- [ ] No "SCSI not found" errors
- [ ] Can save/load presets

---

**Next Step:** Copy HD10.hda to SD card and test! 🚀
