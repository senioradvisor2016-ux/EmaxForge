# standard tools Feature Inventory vs EmaxForge Status

**Source:** industry-standard format Reference Manual (38k+ lines)
**Status Date:** 2026-03-22 00:03 CET (updated)

## Core Operations (Section 3.1 Features)

### ✅ Already Implemented in EmaxForge

1. **Create Disk Images**
   - ✅ compatible sizes (96/239/481/633/962 MB)
   - ✅ Boot disks (HD with OS + INIT BANK)
   - ✅ Data disks (blank formatted)
   - ✅ Multi-disk setup (HD00 boot + HD10/HD20 data)
   - ✅ ZuluSCSI filename convention (HD00.hda, HD10.hda)

2. **Format Operations**
   - ✅ Format suite (HD/SD/Floppy)
   - ✅ Quick format (metadata only)
   - ✅ Full format (zero data area)

3. **View/Browse Operations**
   - ✅ View disk images (HD/SD/Floppy)
   - ✅ Browse bank catalog
   - ✅ Display OS info
   - ✅ Show disk stats (capacity, free space, bank count)

4. **Bank Operations**
   - ✅ Import banks from .EB2 files
   - ✅ Drag-and-drop banks
   - ✅ Delete banks
   - ✅ Export banks (.EB2) — verified
   - ✅ Bulk import banks (entire directory, 18k+ EB2 files)
   - ✅ Move/copy bank between disks (no EB2 intermediate)
   - ✅ Rename bank in-place (EmaxForge exclusive — EMXP cannot do this)
   - ✅ Delete banks

6. **Disk Operations (CLI)**
   - ✅ Clone disk (bit-for-bit copy, SHA1-verified)
   - ✅ Verify/validate disk (boot sig, FAT, BNT, clusters)
   - ✅ Repair disk (free orphan clusters, fix FAT allocation)

### 🔧 Partially Implemented

7. **Sample Operations**
   - ⚠️ Convert WAV → EMAX II (basic implementation)
   - ❌ Convert AIFF → EMAX II
   - ❌ Export samples to WAV
   - ❌ Sample rate conversion
   - ❌ Bit depth conversion (8→16, 16→8)
   - ❌ Looping (set loop points)

8. **Batch Operations**
   - ❌ Batch convert (multiple WAVs at once)
   - ✅ Batch import (bulk-import command — directory or glob)
   - ❌ Batch format (multiple disks)

### ❌ Missing Features (standard tools has, EmaxForge lacks)

9. **Cross-Platform Conversion** (Section 7)
   - ❌ EMAX I ↔ EMAX II
   - ❌ Emulator I/II/III ↔ EMAX II
   - ❌ ESI-32 ↔ EMAX II
   - ❌ SP-12 ↔ EMAX II
   - ❌ Akai S1000 ↔ EMAX II
   - ❌ SoundFont2 ↔ EMAX II

10. **Physical Media Support** (Section 4.5)
    - ❌ Physical floppy disk read/write
    - ❌ Physical SCSI hard disk read/write
    - ❌ HxC floppy emulator support
    - ❌ SCSI2SD card direct access

11. **OS Management** (Section 6.4)
    - ❌ Mass update OS on multiple disks (not needed — OS 2.14 is final)
    - ❌ OS version verification
    - ❌ OS backup/restore
    - ❌ Bootable floppy creation

12. **Advanced Disk Operations** (Section 6.5)
    - ✅ Clone entire disk (bit-for-bit, SHA1-verified)
    - ✅ Disk verification/validation
    - ✅ Orphan cluster repair / FAT fix
    - ❌ Bad sector handling
    - ❌ Partition management (SCSI2SD)

13. **Validation & Repair** (Section 4.8)
    - ✅ Corrupt bank detection (verify-disk reports errors)
    - ✅ FAT repair / orphan recovery
    - ❌ Bank-level recovery (corrupted sample data)
    - ✅ Validation error codes/reports
    - ⚠️ Auto-fix metadata (partial — repair-disk handles FAT/BNT)

14. **MIDI/RS422 Communication**
    - ❌ MIDI SysEx send/receive
    - ❌ RS422 sampler communication
    - ❌ Real-time bank transfer

13. **Preferences/Config** (Section 4.7)
    - ❌ Default folders
    - ❌ Automation level (batch/manual)
    - ❌ Validation rules
    - ❌ File naming conventions

## Priority Ranking (Dev Loop Order)

### Phase 1: Core Polish (Week 1)
1. ✅ Export banks (.EB2) - verify + test
2. ✅ Sample export (WAV) - implement + test
3. ✅ Inspector panel - show bank/sample details
4. ✅ Multi-select - bulk delete/export

### Phase 2: Sample Workflow (Week 2)
5. ⚠️ WAV import improvements - AIFF support, rate conversion
6. ⚠️ Batch convert - drag multiple WAVs
7. ⚠️ Loop editor - set loop start/end
8. ⚠️ Sample trim - remove silence

### Phase 3: Advanced Disk (Week 3)
9. ⚠️ Disk clone - bit-for-bit copy
10. ⚠️ OS mass update - update OS on multiple disks
11. ⚠️ Validation - detect + report corrupt banks
12. ⚠️ Repair - auto-fix metadata issues

### Phase 4: Cross-Platform (Week 4+)
13. ❌ Emulator III support
14. ❌ ESI-32 support
15. ❌ Akai S1000 support
16. ❌ SoundFont2 import

## Notes

- **standard tools Manual Structure:**
  - Section 3: Overview of features
  - Section 4: Basic principles (UI, file/disk mgmt, objects)
  - Section 5: Viewing operations
  - Section 6: Copying operations
  - Section 7: Conversion operations

- **EmaxForge Current State:**
  - Strong foundation: disk creation, formatting, basic bank operations
  - Missing: sample workflow, validation, cross-platform, physical media
  - Ready for iterative feature addition via CLI-Anything loop

- **CLI-Anything Strategy:**
  - Build CLI wrapper for each feature
  - Use CLI to drive UI development
  - Test via CLI + UI screenshot verification
  - Each feature = standalone commit
