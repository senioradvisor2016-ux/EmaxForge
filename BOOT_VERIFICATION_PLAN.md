# Boot Disk Verification Plan

## Status
✅ EmaxForge now creates HD00/HD10 mirrors (identical checksums)
⏳ Need to verify 100% format compatibility

## Method 1: Binary Comparison (15 min)
```bash
# Create identical disk in standard tools
# Windows: standard tools → Create Boot Disk → 239 MB → Save as standard tools_BOOT.EZ2

# Compare with EmaxForge output
hexdump -C ~/clawd/BOOTY/Test\ bugfix/HD00.hda > emaxforge.hex
hexdump -C ~/path/to/standard tools_BOOT.EZ2 > standard.hex
diff emaxforge.hex standard.hex

# Expected differences:
# - Timestamps (ignore)
# - OS version (if different .EMX file used)
# - Everything else should be IDENTICAL
```

## Method 2: Dynamic Analysis (2-3 hours)
### Setup Wine + x64dbg
```bash
brew install wine-stable
# Download x64dbg: https://x64dbg.com
cd ~/clawd/standard
wine x64dbg.exe
```

### Breakpoints to set:
1. **WriteFile** - Log all disk writes
2. **SetFilePointer** - Track seek operations
3. **CreateFile** - See when .EZ2 is opened

### What to capture:
- Boot signature write (offset 0x1FE)
- FAT writes (offset 0x400)
- OS data write (offset 0x83C00)
- Catalog writes (offset 0x1000)

### Output:
→ Complete log of standard tools's disk creation sequence
→ Compare with EmaxForge's sequence

## Method 3: Hardware Test (30 min)
**The ultimate test:**
1. Copy EmaxForge boot disk to ZuluSCSI SD card
2. Boot EMAX II
3. If it works → ✅ 100% compatible!

## Next Step
**Today:** Hardware test with current EmaxForge output
**If fails:** Run dynamic analysis to find differences
