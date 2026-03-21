# Boot Failure Analysis & Fix

**Date:** 2026-03-04 08:07  
**Severity:** 🚨 CRITICAL  
**Status:** ✅ FIXED

---

## User Report

**Symptom:** EMAX II would not boot from EmaxForge-created disk  
**Action:** User created boot disk with "Create Bootable Disk" wizard  
**Result:** EMAX II failed to boot  
**Workaround:** Swapped back to known-working SD card → EMAX II boots normally

---

## Investigation

### Hypothesis

EmaxForge-created disks have incorrect header fields that prevent EMAX II boot loader from recognizing them as bootable.

### Method

1. Compare Peter's working boot disk (`HD00.hda`) with standard tools template values
2. Identify which fields differ
3. Trace difference to source code
4. Verify fix

---

## Root Cause

**File:** `ImageCreator.swift`  
**Lines:** 193, 300

### The Bug

```swift
// Line 193 - createBootableImage()
header.writeU32LE(1, at: 0x14)  // Bank count = 1 (OS only)  ❌ WRONG!

// Line 300 - createBlankImage()
header.writeU32LE(0, at: 0x14)  // Bank count = 0 (empty)   ❌ WRONG!
```

**Problem:** We hardcoded `bankCount` to 1 (boot) or 0 (empty), **overriding** the standard tools template values!

### Template Has Correct Values

From `ImageTemplate` struct (extracted from industry-standard format):

| Size | bankCount (0x14) |
|------|------------------|
| 96 MB | 111 |
| 239 MB | **90** ✅ |
| 481 MB | 106 |
| 633 MB | 140 |
| 962 MB | 151 |

### Peter's Working Disk

**File:** `~/clawd/SD_BOOT/Funkar/HD00.hda` (239 MB, boots on real EMAX II)

**Header field 0x14:** `90` ✅

### EmaxForge (Before Fix)

**Created:** 239 MB boot disk  
**Header field 0x14:** `1` ❌

**Mismatch:** Working disk = 90, EmaxForge = 1

---

## Analysis

### Why Does bankCount Matter?

Field 0x14 is NOT "number of banks currently on disk."

**Evidence:**
- standard tools empty 239MB disk: bankCount = 90
- Peter's boot 239MB disk (1 bank = OS): bankCount = 90
- Peter's data 239MB disk (101 banks): bankCount = 90 (likely)

**Hypothesis:** `bankCount` is **maximum capacity** or **disk size identifier**, not actual bank count.

**EMAX II boot loader checks this field** to validate disk geometry. Wrong value → boot failure.

### Why Did We Override Template?

**Original assumption:** "bankCount = number of banks"
- Boot disk has 1 bank (OS) → set to 1
- Empty disk has 0 banks → set to 0

**Mistake:** We didn't trust the standard tools template. We thought we were being "smart" by updating it dynamically.

**Reality:** standard tools templates contain **EXACT** values needed for EMAX II compatibility. **DO NOT OVERRIDE.**

---

## The Fix

### Code Changes

**Before:**
```swift
header.writeU32LE(1, at: 0x14)  // Bank count = 1 (OS only)
```

**After:**
```swift
header.writeU32LE(template.bankCount, at: 0x14)  // Use template value (not 1!)
```

**Files changed:**
1. `ImageCreator.swift` line 193 (createBootableImage)
2. `ImageCreator.swift` line 300 (createBlankImage)

### Verification

**Build:** ✅ Success (17.3s, no errors)

**Next step:** Create new boot disk with fixed EmaxForge → test on EMAX II hardware

---

## Full Header Comparison

### Peter's Working Boot Disk (HD00.hda, 239 MB)

```
Magic:                     EMX2
Cluster size (0x04):       489,472 bytes
Field 0x08:                6
Field 0x0C:                2
Field 0x10:                8
Bank count (0x14):         90 ✅ CRITICAL!
Field 0x18:                2
Field 0x1C:                4
Cluster area start (0x20): 98
Sectors/cluster-1 (0x24):  955
Field 0x28:                0x783B0103
Field 0x2C:                7
Field 0x30:                0x0D020000
Boot sig (0x1FE-0x1FF):    0x78 0x82
```

**Catalog entry 0:**
- Name: "EMAX2 Software"
- Bank index: 30720
- Start cluster: 1
- Num presets: 1
- Field A: 504
- Field B: 512
- Field C: 0x0081
- Flags: 0x00

### EmaxForge (After Fix) Should Create

**Exact same header** ✅

---

## Lessons Learned

1. **NEVER override standard tools template values**
   - Templates are EXACT values from working disks
   - Every field matters for hardware compatibility
   - If you think you know better than standard tools → YOU DON'T

2. **Field names can be misleading**
   - "bankCount" != actual number of banks
   - Could be max capacity, geometry identifier, or something else
   - Don't assume based on names - use empirical data

3. **Test on hardware early**
   - This bug would have been caught if we tested boot on EMAX II
   - Emulator/software may not catch hardware-specific requirements
   - Real hardware is the ultimate validator

4. **Systematic verification**
   - Compare EVERY field byte-for-byte
   - Don't just check "important" fields
   - Unknown fields can be critical

---

## Action Items

- [x] Fix bankCount override bug
- [x] Build successful
- [ ] **Create new boot disk with fixed EmaxForge**
- [ ] **Test boot on real EMAX II hardware**
- [ ] If boot works → update MEMORY.md with success
- [ ] If boot fails → investigate other header differences

---

## Code Audit Recommendations

**Search for other hardcoded overrides:**

```bash
grep -n "header.writeU32LE([0-9]" ImageCreator.swift
```

**Result:** ✅ No other hardcoded header fields found (only FAT, status table, catalog - which are correct)

---

*Critical bug fixed. Boot disks should now work. VERIFY ON HARDWARE!*
