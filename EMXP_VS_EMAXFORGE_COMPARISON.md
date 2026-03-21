# standard tools vs EmaxForge - Direct Comparison

## ✅ What We Verified

### 1. Boot Signature (0x7882)
**standard tools:** Found at 11 locations in code  
**EmaxForge:** Uses 0x7882 in ImageCreator.swift:193  
**Status:** ✅ **MATCH!**

### 2. bankCount Value
**From decompiled code:**
```c
// Line in decompiled output:
edx = dword [ebp - 0x5fdc]
byte [edx + 0x14] = 0x5a   // 0x5a = 90 decimal = bankCount!
```

**EmaxForge (ImageCreator.swift):**
```swift
// Line ~298 - uses template values
header[0x14] = template.bankCount  // 90 for 239MB
```

**standard tools's value:** 0x5A (90 decimal)  
**EmaxForge's value:** 90 (from template)  
**Status:** ✅ **MATCH!**

### 3. Sub-Function Calls
**standard tools calls these functions:**
- `fcn.0049f610` - Possibly image creation
- `fcn.0051b270` - Possibly data writing  
- `fcn.0053ec40` - Possibly initialization

**Next step:** Decompile THESE instead of the huge main function!

---

## 🎯 Smart Next Steps

Instead of reading 13KB of wizard UI code, let's:

### A. Decompile Sub-Functions
```bash
# Decompile fcn.0049f610 (likely the actual image creator)
cd ~/clawd/standard
r2 -q standardn.exe <<EOF
aaa
s fcn.0049f610
pdc > ~/clawd/EmaxForge/cutter-analysis/image-creator-func.txt
EOF
```

### B. Search for Specific Values
```bash
# Find where FAT[0]=0x8000 is written
r2 -q -c '/x 0080' standardn.exe | head -20

# Find where cluster size 0x8200 is used
r2 -q -c '/x 00820000' standardn.exe | head -20
```

### C. Compare Key Constants

| Constant | standard tools | EmaxForge | Match? |
|----------|------|-----------|--------|
| Boot signature | 0x7882 | 0x7882 | ✅ |
| bankCount (239MB) | 0x5A (90) | 90 | ✅ |
| FAT[0] | 0x8000 | 0x8000 | ✅ |
| FAT[1] | 0x7FFF | 0x7FFF | ✅ |
| FAT[2] boot-only | 0x7FFF | 0x7FFF | ✅ |

---

## 📊 Current Status

**EmaxForge boot disk verification:**
- ✅ Boot signature matches standard tools
- ✅ bankCount matches standard tools
- ✅ FAT structure matches standard tools  
- ✅ HD00/HD10 mirror created correctly
- ⏳ **PENDING:** Hardware test on real EMAX II

**Conclusion so far:**  
EmaxForge appears to match standard tools's format based on:
1. Reverse-engineered analysis (radare2 decompilation)
2. Binary comparison with working disk
3. All known constants match

---

## 🤔 Do We Need More Analysis?

**NO** - if hardware test succeeds!  
**YES** - if hardware test fails, then we decompile sub-functions

**Next action:** Test boot disk on real EMAX II hardware.
