# standard tools Boot Disk Analysis Summary

## ✅ Findings So Far

### Main Boot Function
**Function:** `fcn.005990d0` (address: 0x59c113)
**String:** "Ready to create a bootable %s"
**Decompiled:** boot-function-decompiled.txt

### Called Functions (from decompiled code)
1. `fcn.0053ec40` - Unknown purpose (init?)
2. `fcn.0049f610` - Unknown purpose (create image?)
3. `fcn.0051b270` - Unknown purpose (write data?)

### Next Steps
1. Find boot signature writer (search for 0x7882 or 0x78 0x82)
2. Find FAT writer (search for 0x8000, 0x7FFF)
3. Find cluster size calculator
4. Decompile each sub-function

---

## 🔍 Search Strategy

Use radare2 to search for hex patterns:
```bash
# Search for boot signature (0x78 0x82)
r2 -q -c '/x 7882' standardn.exe

# Search for FAT entry 0 (0x8000 little-endian = 00 80)
r2 -q -c '/x 0080' standardn.exe

# Search for FAT entry 1 (0x7FFF little-endian = ff 7f)
r2 -q -c '/x ff7f' standardn.exe
```

