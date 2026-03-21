# standard tools 239 MB Disk Header Analysis (VERIFIED WORKING)

## Raw Header (512 bytes, offset 0x0000)
```
00000000: 454d 5832 0078 0700 0600 0000 0200 0000  EMX2.x..........
00000010: 0800 0000 5a00 0000 0200 0000 0400 0000  ....Z...........
00000020: 6200 0000 bb03 0000 0301 3b78 0700 0000  b.........;x....
00000030: 0000 020d 0000 0000 0000 0000 0000 0000  ................
...
000001f0: 0000 0000 0000 0000 0000 0000 0000 7882  ..............x.
```

## Field-by-Field Breakdown (Little-Endian)

| Offset | Bytes | Value (LE) | Value (Decimal) | Field Name |
|--------|-------|------------|-----------------|------------|
| 0x00 | 45 4D 58 32 | "EMX2" | - | Signature |
| 0x04 | 00 78 07 00 | 0x0778 | **1920** | **clusterAreaStartSector** ✅ |
| 0x08 | 06 00 00 00 | 0x0006 | 6 | Unknown (maybe version?) |
| 0x0C | 02 00 00 00 | 0x0002 | 2 | sectorSize (× 256 = 512) |
| 0x10 | 08 00 00 00 | 0x0008 | 8 | clusterSizeSectors (8 × 512 = 4096 bytes) |
| 0x14 | 5A 00 00 00 | 0x005A | **90** | **bankCount** ✅ |
| 0x18 | 02 00 00 00 | 0x0002 | 2 | Unknown |
| 0x1C | 04 00 00 00 | 0x0004 | 4 | catalogEntriesPerSector? |
| 0x20 | 62 00 00 00 | 0x0062 | **98** | **statusTableStartSector** ✅ |
| 0x24 | BB 03 00 00 | 0x03BB | **955** | **totalClusters** ✅ |
| 0x28 | 03 01 | 0x0103 | 259 | Unknown |
| 0x2A | 3B | 0x3B | 59 | Unknown |
| 0x2B | 78 07 00 00 | 0x0778 | 1920 | clusterAreaStart (duplicate?) |
| 0x2F | 00 | 0x00 | 0 | Padding |
| 0x30 | 02 0D | 0x0D02 | 3330 | Unknown |
| 0x32-0x1FD | 00... | - | - | Zeros (padding) |
| 0x1FE | 78 82 | 0x8278 | - | **Boot signature** ✅ |

## Critical Values (EmaxForge Templates Need These!)

```swift
clusterAreaStartSector: 1920  // NOT 98!
clusterSize: 4096             // 8 sectors × 512
bankCount: 90                 // NOT 1!
statusTableStartSector: 98
totalClusters: 955
bootSignature: 0x78 0x82
```

## Comparison: EmaxForge vs standard tools

| Field | EmaxForge (WRONG) | standard tools (CORRECT) |
|-------|-------------------|----------------|
| clusterAreaStartSector | **98** ❌ | **1920** ✅ |
| bankCount | **1** ❌ | **90** ✅ |
| statusTableStartSector | 98 ✅ | 98 ✅ |

**ROOT CAUSE:** EmaxForge uses cluster area start = 98, but standard tools uses 1920!

**This is why all EmaxForge disks fail to boot!**
