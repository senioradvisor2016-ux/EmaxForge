# standard tools Validation Plan for EmaxForge

**Goal:** Make EmaxForge 100% compatible

**Reference:** industry-standard format Reference Manual (442 pages)

---

## Phase 1: Disk Format Validation

### Boot Sector (Sector 0)
- [ ] Boot signature: 0x7882 at offset 0x1FE-0x1FF ✅ (DONE)
- [ ] Sector size: 512 bytes
- [ ] Cluster area start sector (varies by disk size)
- [ ] Bank count field (varies by disk size)
- [ ] Metadata fields validation

### FAT (File Allocation Table)
- [ ] FAT starts at offset 0x0400 ✅ (DONE)
- [ ] FAT entry 0 = 0x000F or 0x8000 ✅ (DONE)
- [ ] FAT entry 1 = 0x0000 (boot disk) or varies (data disk)
- [ ] FAT entry 2+ = 0x8080 (free) or chain pointers
- [ ] End-of-chain marker: 0x7FFF
- [ ] Validate FAT chain integrity

### Catalog (Directory)
- [ ] Catalog starts after FAT
- [ ] Entry size: 64 bytes ✅ (DONE)
- [ ] Entry 0: OS entry on boot disks
- [ ] Entry 1+: Bank entries
- [ ] Bank name: 16 chars, padded with spaces
- [ ] FLAGS field: 0x0081 for all entries ✅ (DONE)
- [ ] Cluster number validation
- [ ] Preset count validation

### Cluster Structure
- [ ] Cluster size in 8KB blocks (offset 0x0C) ✅ (DONE)
- [ ] 96 MB: 8 KB clusters ✅ (DONE)
- [ ] 239 MB: 16 KB clusters ✅ (DONE)
- [ ] 481 MB: 32 KB clusters
- [ ] 633 MB: 32 KB clusters
- [ ] 962 MB: 32 KB clusters ✅ (DONE)

---

## Phase 2: Disk Sizes (standard tools Standard)

Test all 5 disk sizes:

### Size Tests
- [ ] 96 MB (100,663,296 bytes) - 8 KB clusters ✅ (TESTED)
- [ ] 239 MB (250,609,664 bytes) - 16 KB clusters ✅ (TESTED)
- [ ] 481 MB (504,365,056 bytes) - 32 KB clusters
- [ ] 633 MB (663,748,608 bytes) - 32 KB clusters
- [ ] 962 MB (1,009,123,328 bytes) - 32 KB clusters ✅ (TESTED)

### Per Size Validation
- [ ] Correct cluster area start sector
- [ ] Correct bank count field
- [ ] Correct total clusters
- [ ] Correct FAT size
- [ ] Boot disk creation
- [ ] Data disk creation

---

## Phase 3: OS (Operating System) Handling

### OS Files
- [ ] Detect OS file: "Emax II rev 2.14.EMX" or "WORKING.EMX"
- [ ] OS size validation (~260 KB for rev 2.14)
- [ ] OS cluster allocation (cluster 1 only)
- [ ] OS catalog entry creation
- [ ] OS FAT chain (entry 1 = 0x7FFF for single-cluster OS)

### Boot Disk Requirements
- [ ] Boot signature present
- [ ] OS in cluster 1
- [ ] OS catalog entry at slot 0
- [ ] Minimum 1 bank after OS (INIT BANK requirement)
- [ ] SCSI ID 1 for boot disks (HD10.hda naming)

---

## Phase 4: Bank Operations

### Bank Import
- [ ] Single bank import ✅ (TESTED)
- [ ] Multiple banks import ✅ (TESTED - 52 banks)
- [ ] Large bank import (>1 MB)
- [ ] Bank name preservation
- [ ] Preset count validation
- [ ] Sample data integrity
- [ ] FAT chain creation
- [ ] Catalog entry creation

### Bank Export
- [ ] Export single bank
- [ ] Export multiple banks
- [ ] Preserve bank structure
- [ ] Validate exported .EB2 file

### Bank Validation
- [ ] Bank name format (16 chars max)
- [ ] Preset count limits
- [ ] Sample count limits
- [ ] Memory size limits per disk

---

## Phase 5: Multi-Disk Support

### SCSI Configuration
- [ ] HD10.hda = SCSI ID 1 (boot)
- [ ] HD20.hda = SCSI ID 2 (data)
- [ ] HD30.hda = SCSI ID 3 (data)
- [ ] Up to HD70.hda = SCSI ID 7

### Multi-Disk Creation
- [ ] Boot disk (HD10) with OS + INIT BANK
- [ ] Data disk(s) (HD20+) without OS
- [ ] Size configuration: HD10 = user choice, HD20+ = 962 MB
- [ ] ZuluSCSI ini file generation
- [ ] Verify multi-disk setup on SD card

---

## Phase 6: standard tools Cross-Validation

### Round-Trip Tests
- [ ] Create disk with EmaxForge → Read with standard tools
- [ ] Create disk with standard tools → Read with EmaxForge
- [ ] Import bank with EmaxForge → Verify with standard tools
- [ ] Import bank with standard tools → Verify with EmaxForge

### Corruption Detection
- [ ] Invalid boot signature detection
- [ ] Invalid FAT detection
- [ ] Invalid catalog detection
- [ ] Broken FAT chain detection
- [ ] Oversized bank detection

---

## Phase 7: Error Handling (Section 4.8 of Manual)

### EMAX-II Validation Error Codes
From manual section 4.8.3.1:

- [ ] E001: Invalid file size
- [ ] E002: Invalid boot signature
- [ ] E003: Invalid FAT header
- [ ] E004: Invalid catalog entry
- [ ] E005: FAT chain broken
- [ ] E006: Cluster overflow
- [ ] E007: Invalid bank size
- [ ] (+ more from manual)

---

## Phase 8: Performance & Edge Cases

### Stress Tests
- [ ] Max banks per disk
- [ ] Max total sample size
- [ ] Fragmented FAT chains
- [ ] Empty disk operations
- [ ] Full disk operations

### Edge Cases
- [ ] Zero-size banks
- [ ] Single-preset banks
- [ ] Banks with no samples
- [ ] Duplicate bank names
- [ ] Invalid characters in names

---

## Testing Infrastructure

### CLI-Anything Commands
```bash
# Validation
cli-anything-emaxforge verify-disk <file> [--json]

# Disk ops
cli-anything-emaxforge create-disk --size <MB> --scsi-id <N> [--with-os]
cli-anything-emaxforge format-disk <file>

# Bank ops
cli-anything-emaxforge import-bank --disk <file> --bank <.EB2>
cli-anything-emaxforge export-bank --disk <file> --bank <name> --output <.EB2>
cli-anything-emaxforge list-banks <file> [--json]

# Advanced
cli-anything-emaxforge compare-disk <file1> <file2>
cli-anything-emaxforge standard-validate <file>  # Use standard tools rules
```

### Test Data Sources
- standard tools templates (~/Library/.../standard tools/)
- Peter's banks (~/clawd/standard/*.EB2)
- format specification examples
- ZuluSCSI test SD card

---

## Success Criteria

✅ **State of the Art = All phases completed**

Current Status: **Phase 1: 40% complete**

Next: Complete Phase 1, then systematic execution of Phases 2-8
