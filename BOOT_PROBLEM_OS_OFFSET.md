# Boot Problem: OS Skrivs på Fel Offset

**Datum:** 2026-03-07  
**Problem:** SD-minnet bootar inte med banker  
**Orsak:** OS skrivs på fel offset i image

---

## 🔍 PROBLEM IDENTIFIERAT

### OS Offset Bugg

**Referens (_IMAGE_239.EZ2):**
- OS Offset: **0x83C00** (539,648 bytes)
- Beräkning: `clusterAreaStart * 512 + clusterSize = 98 * 512 + 489472 = 0x83C00`
- OS är på **cluster 1 offset** ✅

**EmaxForge (ImageCreator.swift):**
- OS Offset: **0xD720** (55,072 bytes) ❌
- Beräkning: `catalogOffset + catalogSize = 50176 + 4896 = 0xD720`
- OS skrivs **direkt efter catalog** ❌

**Skillnad:** 484,576 bytes (946.4 sectors) ❌

---

## 📊 ANALYS

### OS Data Jämförelse

**Referens OS Data (0x83C00):**
```
e3fc48fd22fdcefcfafbc0fae1f962f963f97bf9d6f91efa4dfab1fa2efb30fb...
```

**EmaxForge OS Data (0xD720):**
```
110014b8eabe821c086abe5ad40e8414e7de088405eabe171c086abe499cb003...
```

**OS-fil (emax2_os.bin):**
```
110014b8eabe821c086abe5ad40e8414e7de088405eabe171c086abe499cb003...
```

**Slutsats:**
- ✅ OS-filen matchar data efter catalog (0xD720)
- ❌ Men OS ska vara på cluster 1 offset (0x83C00)
- ❌ ImageCreator skriver OS på fel plats!

---

## 💡 ROOT CAUSE

**File:** `ImageCreator.swift`  
**Line:** 254-258

```swift
// 4. Write OS data immediately after catalog (4896 bytes)
// The catalog occupies the start of the cluster area but OS follows at +4896,
// NOT at +clusterSize. Bank clusters (2+) use full clusterSize alignment.
let catalogSize: UInt64 = 4896
let osOffset = catalogOffset + catalogSize  // ❌ FEL!
```

**Problemet:**
- Kommentaren säger "OS follows at +4896" men det är **FEL**!
- OS ska följa på **cluster 1 offset** = `catalogOffset + clusterSize`
- Catalog är INTE en del av cluster 1, catalog är en separat struktur

**Korrekt:**
```swift
// OS ska skrivas på cluster 1 offset
let osOffset = catalogOffset + UInt64(template.clusterSize)  // ✅ KORREKT
```

---

## 🔧 FIX

### Ändring i ImageCreator.swift

**Före (rad 254-258):**
```swift
// 4. Write OS data immediately after catalog (4896 bytes)
// The catalog occupies the start of the cluster area but OS follows at +4896,
// NOT at +clusterSize. Bank clusters (2+) use full clusterSize alignment.
let catalogSize: UInt64 = 4896
let osOffset = catalogOffset + catalogSize
```

**Efter:**
```swift
// 4. Write OS data at cluster 1 offset
// Catalog is at cluster area start (sector 98), OS is at cluster 1
// Cluster 1 = catalogOffset + clusterSize (not +catalogSize!)
let osOffset = catalogOffset + UInt64(template.clusterSize)
```

---

## 📋 VERIFIERING

Efter fix, verifiera att:
1. OS offset = `0x83C00` (539,648 bytes) för 239 MB disk
2. OS data första 32 bytes = `e3fc48fd22fdcefcfafbc0fae1f962f9...`
3. Image bootar på EMAX II

---

## 🎯 SLUTSATS

**Problemet:** ImageCreator skriver OS på fel offset (efter catalog istället för cluster 1).

**Fix:** Ändra OS offset från `catalogOffset + catalogSize` till `catalogOffset + clusterSize`.

**Status:** ⚠️  **KRITISK BUGG - MÅSTE FIXAS!**
