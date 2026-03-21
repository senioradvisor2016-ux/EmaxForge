# standard tools vs EmaxForge - Full Verification Plan

**Date:** 2026-03-07 18:06  
**Purpose:** Verify EmaxForge boot disk creation against standard tools's decompiled code  
**Status:** FAT structure bug found - need to verify ALL logic paths

## Critical Components to Verify

### 1. FAT Structure ⚠️ HIGH PRIORITY
**EmaxForge:** `ImageCreator.swift` lines 324-362 (writeMinimalBootBank)  
**standard tools:** Search for FAT write operations in decompiled code

**Issues found:**
- ❌ FAT chain not created (should be 2→3→4→5→6)
- ❌ Only 1 cluster allocated instead of 5

**Verification needed:**
- [ ] How does standard tools write FAT entries?
- [ ] What's the exact cluster chain pattern?
- [ ] Are there other FAT operations we're missing?

### 2. Boot Signature
**EmaxForge:** `0x7882` at offset 0x1FE  
**standard tools:** Found at 11 code locations  
**Status:** ✅ VERIFIED (matches)

### 3. Catalog Structure
**EmaxForge:** `ImageCreator.swift` lines 363-380  
**standard tools:** Search for catalog write operations

**To verify:**
- [ ] OS catalog entry (entry 0)
- [ ] INIT BANK catalog entry (entry 1)
- [ ] FLAGS field (0x8100 vs 0x0081)
- [ ] Cluster start field
- [ ] Preset count field

### 4. OS Placement
**EmaxForge:** Cluster 1 at offset `clusterAreaStart + clusterSize`  
**standard tools:** Search for OS write operations

**To verify:**
- [ ] Correct cluster offset calculation
- [ ] OS size handling
- [ ] Cluster size vs disk size

### 5. Header Fields
**EmaxForge:** Uses `ImageTemplate` lookup table  
**standard tools:** Hardcoded or calculated?

**To verify:**
- [ ] bankCount (0x5A for 239MB)
- [ ] clusterSize (0x8200 for 239MB)
- [ ] clusterAreaStartSector (varies by size)
- [ ] Boot signature placement

### 6. HD00/HD10 Mirror
**EmaxForge:** `ImageCreator.swift` line ~298  
**standard tools:** Does standard tools handle this?

**To verify:**
- [ ] Does standard tools create mirrors?
- [ ] Or is this ZuluSCSI-specific?

## Verification Methods

### Method A: Grep Search
```bash
# FAT operations
grep -r "0x8000\|0x7FFF\|0x0003" ~/clawd/standard/decompiled/*.c

# Cluster writes
grep -r "cluster\|Cluster\|CLUSTER" ~/clawd/standard/decompiled/*.c -i

# Catalog writes
grep -r "catalog\|Catalog\|CATALOG" ~/clawd/standard/decompiled/*.c -i

# Boot operations
grep -r "boot\|Boot\|BOOT" ~/clawd/standard/decompiled/*.c -i
```

### Method B: Function Analysis
Decompile and analyze key functions:
- `fcn.0049f610` - Image creator?
- `fcn.0051b270` - Data writer?
- `fcn.0053ec40` - Initialization?

### Method C: Binary Comparison
Compare byte-for-byte:
- Working disk vs EmaxForge disk
- Identify ALL differences
- Map each difference to code location

## Expected Findings

Based on current FAT bug, likely issues:
1. **writeMinimalBootBank()** - Not creating 5-cluster chain
2. **FAT write logic** - Missing cluster chain creation
3. **Catalog entry** - Possibly wrong fields for INIT BANK
4. **Cluster allocation** - May not be allocating enough space

## Success Criteria

✅ EmaxForge creates boot disk that:
1. Has correct FAT structure (5-cluster INIT BANK chain)
2. Has correct catalog entries (OS + INIT BANK)
3. Has correct boot signature (0x7882)
4. Boots on real EMAX II hardware
5. Is byte-for-byte identical to standard tools boot disk (except timestamp/random data)

## Next Steps

1. Search standard tools decompiled code for FAT write patterns
2. Identify exact algorithm standard tools uses
3. Compare with EmaxForge implementation
4. Fix any mismatches
5. Test on hardware
