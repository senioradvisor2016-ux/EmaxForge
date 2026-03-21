# SCSI ID Boot Disk Change Verification

**Test Date:** March 8, 2026 09:22 CET  
**Commit:** 403e6555 - "CRITICAL FIX: EMAX II boots from SCSI ID 1, not 0!"

## Test Parameters
- **Wizard Defaults:**
  - SCSI ID: `1` (changed from `0`)
  - Image count: `2` (multi-disk)
  - Size: 239 MB

## Filename Generation Logic

### NEW Behavior (CORRECT ✅)
```swift
let currentScsiID = count > 1 ? (i + 1) : scsiID
// i=0 → currentScsiID = 1 → HD10.hda (BOOT)
// i=1 → currentScsiID = 2 → HD20.hda (DATA)
```

**Output:**
```
[0] HD10.hda → BOOT (SCSI ID 1) ✅ EMAX II will boot!
[1] HD20.hda → DATA (SCSI ID 2)
```

### OLD Behavior (WRONG ❌)
```swift
let currentScsiID = count > 1 ? i : scsiID
// i=0 → currentScsiID = 0 → HD00.hda (BOOT)
// i=1 → currentScsiID = 1 → HD10.hda (DATA)
```

**Output:**
```
[0] HD00.hda → BOOT (SCSI ID 0) ❌ EMAX II won't boot!
[1] HD10.hda → DATA (SCSI ID 1)
```

## Hardware Test Result
**Test:** SD card with ONLY HD10.hda → EMAX II **BOOTED** ✅

## Code Changes

### BootableDiskWizard.swift Line 24
```diff
- @State private var scsiID: Int = 0
+ @State private var scsiID: Int = 1  // EMAX II boots from SCSI ID 1
```

### BootableDiskWizard.swift Line 873
```diff
- // Multi-image logic: HD0 = boot (SCSI 0), HD1+ = data (SCSI 1+)
- let currentScsiID = count > 1 ? i : scsiID
+ // Multi-image logic: HD1 = boot (SCSI 1), HD2+ = data (SCSI 2+)
+ let currentScsiID = count > 1 ? (i + 1) : scsiID
```

### BootableDiskWizard.swift Line 881
```diff
- // Multi-image: HD00.hda, HD10.hda, HD20.hda, etc. (ZuluSCSI format)
+ // Multi-image: HD10.hda, HD20.hda, HD30.hda, etc. (ZuluSCSI format)
```

## Files Changed
- ✅ BootableDiskWizard.swift (13 edits)
- ✅ ImageDetailView.swift (boot badge)
- ✅ ImportBanksView.swift (warning)
- ✅ ConvertSamplesView.swift (warning)
- ✅ FormatDiskSheet.swift (warning)
- ✅ NewImageSheet.swift (help text)
- ✅ WelcomeView.swift (onboarding)
- ✅ ImageListView.swift (no boot warning)
- ✅ KnowledgeBaseView.swift (boot article)
- ✅ FormatPreset.swift (boot preset)
- ✅ MEMORY.md (discovery documented)

## Build Status
```
Build complete! (7.23s)
Warnings: 3 (unused variables, no async)
Errors: 0
```

## Next Steps
1. ✅ Test script validates logic
2. ⏭️ Create real boot disk with EmaxForge UI
3. ⏭️ Test on EMAX II hardware
4. ⏭️ Update EmaxForge version to v0.6 (SCSI ID 1 boot fix)

---
**Conclusion:** All changes correctly implement SCSI ID 1 boot behavior! 🎉
