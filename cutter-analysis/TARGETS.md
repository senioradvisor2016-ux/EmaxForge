# standard tools Reverse Engineering Targets

## Immediate Goals (Next Session)

### Target 1: Boot Signature Writer ⭐ PRIORITY
**Why:** Verify our 0x7882 signature is correct
**How to find:**
1. Strings → Search: "78 82" or "boot"
2. Look for hex comparison: `if (data[0x1FE] == 0x78 && data[0x1FF] == 0x82)`
3. Document exact write sequence

**Expected output:**
```c
// Pseudocode from standard tools
header[0x1FE] = 0x78;
header[0x1FF] = 0x82;
```

**Verify against EmaxForge:**
```swift
// ImageCreator.swift line 193
header[0x1FE] = template.bootSig1  // 0x78
header[0x1FF] = template.bootSig2  // 0x82
```

---

### Target 2: FAT Initialization ⭐ PRIORITY
**Why:** Understand why working disk has 5-cluster INIT BANK
**How to find:**
1. Search WriteFile calls at offset 0x400
2. Look for FAT entry writes
3. Document FAT[0], FAT[1], FAT[2] initialization

**Expected findings:**
- FAT[0] = 0x8000 (reserved)
- FAT[1] = 0x7FFF (OS end marker)
- FAT[2] = ??? (INIT BANK - currently unclear)

**Question to answer:**
- Does standard tools write INIT BANK as 1 cluster or 5 clusters?
- If 5 clusters, why? What's the chain?

---

### Target 3: Cluster Size Calculation
**Why:** Verify our templates match standard tools's algorithm
**How to find:**
1. Search for constant 0x8200 (cluster size we use)
2. OR search for cluster size calculation based on disk size
3. Document formula

**Expected findings:**
```c
// Pseudocode
int clusterSize = calculateClusterSize(diskSizeMB);
// 96 MB → 0x7800
// 239 MB → 0x8200
// etc.
```

**Verify against EmaxForge:**
```swift
// ImageCreator.swift templates
96: clusterSize = 0x7800
239: clusterSize = 0x8200
```

---

## Secondary Targets (This Week)

### Target 4: Disk Size Validation
**Find:** Allowed disk sizes (96, 239, 481, 633, 962 MB)
**Why:** Understand if these are hardcoded or calculated

### Target 5: OS File Loading
**Find:** How standard tools loads "Emax II rev 2.14.EMX"
**Why:** Verify we're writing OS data to correct location

### Target 6: INIT BANK Creation
**Find:** Minimal boot bank generation
**Why:** Understand why boot disk needs INIT BANK

---

## How to Document Findings

For each target, create file: `cutter-analysis/TARGET_NAME.md`

Example: `boot-signature-writer.md`
```markdown
# Boot Signature Writer

## Function Name
`sub_401ABC` (rename to `writeBootSignature`)

## Location
Address: 0x00401ABC
Called from: `createBootDisk` (0x00402DEF)

## Decompiled Code
[paste Cutter pseudocode]

## Algorithm
1. Seek to offset 0x1FE
2. Write 0x78
3. Write 0x82

## EmaxForge Comparison
✅ MATCHES - We write same signature at same offset

## Notes
- Signature is hardcoded (not calculated)
- No validation/checksum
- Always 0x7882 regardless of disk size
```

---

**Start here:** Search for "boot" in Strings window, find first function!
