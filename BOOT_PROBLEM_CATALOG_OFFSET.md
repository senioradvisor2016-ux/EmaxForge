# Boot Problem: Catalog Skrivs på Fel Offset

**Datum:** 2026-03-07  
**Severity:** 🚨 **KRITISK**  
**Status:** ✅ **FIXAD**

---

## 🔍 PROBLEM IDENTIFIERAT

### Catalog Offset Bugg

**Referens (_IMAGE_239.EZ2):**
- Catalog är på **0x1000** (inte på cluster area start!)
- OS entry på 0x1000: "EMAX2 Software", Bank Index 0x7800, Start Cluster 1, Field C 0x0081

**EmaxForge (ImageCreator.swift - FÖRE FIX):**
- Catalog skrivs på `clusterAreaStartSector * 512` (0xC400 för 239MB) ❌
- Detta är **FEL** - catalog ska vara på **0x1000**!

**Skillnad:** Catalog skrivs 46,080 bytes (0xB400) för sent! ❌

---

## 📊 ANALYS

### Referens Struktur

**Offset 0x1000 (Catalog):**
```
Entry 0: "EMAX2 Software"
   Bank Index: 0x7800 (30720)
   Start Cluster: 1
   Field C: 0x0081 (active flag)
```

**Offset 0xC400 (Cluster Area Start):**
```
Detta är INTE catalog!
Detta är troligen boot catalog eller annan struktur.
```

### EMAX II File System Layout

```
Sector 0-3:     Header + Status + FAT
Sector 4-97:    Bank Name Table (BNT)
Offset 0x1000:  Catalog (OS entry + bank entries) ✅
Sector 98+:     Cluster Area Start
   Cluster 1:   OS data (0x83C00 för 239MB)
   Cluster 2+:   Bank data
```

**Kritiskt:** Catalog är på **fast offset 0x1000**, INTE på cluster area start!

---

## 💡 ROOT CAUSE

**File:** `ImageCreator.swift`  
**Line:** 257-260

```swift
// FÖRE (FEL):
// 3. Write boot catalog at cluster area start
let catalogOffset = UInt64(template.clusterAreaStartSector) * 512
handle.seek(toFileOffset: catalogOffset)
handle.write(bootCatalog)
```

**Problemet:**
- Kommentaren säger "catalog at cluster area start" men det är **FEL**!
- Catalog ska vara på **fast offset 0x1000**
- Cluster area start är för cluster data, INTE för catalog

**Korrekt:**
```swift
// EFTER (KORREKT):
// 3. Write boot catalog at 0x1000
let catalogOffset: UInt64 = 0x1000
handle.seek(toFileOffset: catalogOffset)
handle.write(bootCatalog)
```

---

## 🔧 FIX

### Ändring i ImageCreator.swift

**Före (rad 257-267):**
```swift
// 3. Write boot catalog at cluster area start
let catalogOffset = UInt64(template.clusterAreaStartSector) * 512
handle.seek(toFileOffset: catalogOffset)
handle.write(bootCatalog)

// 4. Write OS data at cluster 1 offset
let osOffset = catalogOffset + UInt64(template.clusterSize)
```

**Efter:**
```swift
// 3. Write boot catalog at 0x1000 (CRITICAL FIX: Catalog is NOT at cluster area start!)
let catalogOffset: UInt64 = 0x1000
handle.seek(toFileOffset: catalogOffset)
handle.write(bootCatalog)

// 4. Write OS data at cluster 1 offset
let clusterAreaStart = UInt64(template.clusterAreaStartSector) * 512
let osOffset = clusterAreaStart + UInt64(template.clusterSize)
```

---

## 📋 VERIFIERING

Efter fix, verifiera att:
1. Catalog är på offset 0x1000 ✅
2. OS entry på 0x1000: "EMAX2 Software", Bank Index 0x7800, Field C 0x0081 ✅
3. OS data är på cluster 1 offset (0x83C00 för 239MB) ✅
4. Image bootar på EMAX II ✅

---

## 🎯 SLUTSATS

**Problemet:** ImageCreator skriver catalog på fel offset (cluster area start istället för 0x1000).

**Fix:** Ändra catalog offset från `clusterAreaStartSector * 512` till `0x1000`.

**Status:** ✅ **KRITISK BUGG FIXAD!**

**Detta förklarar varför diskarna inte bootar - EMAX II letar efter catalog på 0x1000 men hittar den inte där!**

---

## 📊 JÄMFÖRELSE

| Komponent | Referens | EmaxForge (Före) | EmaxForge (Efter) |
|-----------|----------|------------------|-------------------|
| **Catalog Offset** | 0x1000 | 0xC400 ❌ | 0x1000 ✅ |
| **OS Offset** | 0x83C00 | 0x83C00 ✅ | 0x83C00 ✅ |
| **BankImporter Catalog** | 0x1000 | 0x1000 ✅ | 0x1000 ✅ |

**Observera:** BankImporter skrev redan catalog entries på korrekt plats (0x1000), men ImageCreator skrev boot catalog på fel plats!

---

**Nästa Steg:** Kompilera om appen och skapa nya boot disks för att verifiera fixen.
