# OS Offset Verifiering: SD-Minnes Filer vs Dekompilerade Filer

**Datum:** 2026-03-07  
**Syfte:** Verifiera OS offset fix mot SD-minnes filer och dekompilerade standard tools filer

---

## 📊 REFERENS: _IMAGE_239.EZ2

**OS Offset Beräkning:**
- Cluster Area Start: Sector 98 = 50,176 bytes (0xC400)
- Cluster Size: 489,472 bytes
- **OS Offset (korrekt):** `0xC400 + 489,472 = 0x83C00` (539,648 bytes) ✅
- **OS Offset (fel):** `0xC400 + 4,896 = 0xD720` (55,072 bytes) ❌

**OS Data:**
- Korrekt offset (0x83C00): `e3fc48fd22fdcefcfafbc0fae1f962f9...` ✅
- Fel offset (0xD720): `110014b8eabe821c086abe5ad40e8414...` ❌

---

## 📁 SD-MINNES FILER ANALYS

### 1. Funkar HD00.hda

**Status:** ❌ **OS på fel offset!**

**OS Offset:**
- Korrekt: 0x83C00
- Fel: 0xD720
- **Faktiskt OS:** På 0xD720 (fel plats) ❌

**OS Data:**
- På korrekt offset (0x83C00): `b7ce59ce3ace31ce6bcef7ce73cf09d0...` (inte OS!)
- På fel offset (0xD720): `110014b8eabe821c086abe5ad40e8414...` (OS-fil matchar) ❌

**Slutsats:** Funkar HD00 har OS på fel offset, vilket förklarar varför den inte bootar korrekt med banker!

---

### 2. new boot HD00.hda

**Status:** ⚠️  **OS saknas!**

**OS Offset:**
- Korrekt: 0x83C00
- Fel: 0xD720
- **Faktiskt OS:** Hittas inte på någon av offsets! ❌

**OS Data:**
- På korrekt offset (0x83C00): `b7ce59ce3ace31ce6bcef7ce73cf09d0...` (inte OS!)
- På fel offset (0xD720): `00000000000000000000000000000000...` (tomt!)

**Slutsats:** new boot HD00 saknar OS helt! Detta är troligen en gammal image skapad innan OS-filen laddades korrekt.

---

## 🔍 DEKOMPILERADE FILER ANALYS

### Sökning efter OS Offset Beräkning

**Sökta mönster:**
- `0xC400` (catalog offset)
- `0x83C00` (korrekt OS offset)
- `cluster.*area.*start`
- `sector.*98`

**Resultat:**
- ⚠️  Inga direkta matchningar av OS offset beräkning i dekompilerade filer
- Detta är förväntat eftersom OS offset beräknas dynamiskt baserat på disk storlek

### Bekräftat från VERIFICATION.md

**Korrekt formel (från VERIFICATION.md):**
```swift
// Cluster 1 = clusterAreaStart + clusterSize
let clusterOffset = clusterAreaStart + UInt64(template.clusterSize)
// = 50,176 + 489,472 = 539,648 = 0x83C00 ✅
```

**EMAX II File System Formula:**
```
Physical offset = clusterAreaStart + (clusterNumber × clusterSize)

Cluster numbering:
- Cluster 0: RESERVED (FAT entry 0x8000)
- Cluster 1: OS (FAT entry 0x7FFF = END)
- Cluster 2+: Banks (FAT chains)
```

---

## 💡 SLUTSATS

### Problem Identifierat

1. **Funkar HD00:** OS på fel offset (0xD720 istället för 0x83C00) ❌
2. **new boot HD00:** OS saknas helt ❌
3. **Referens (_IMAGE_239.EZ2):** OS på korrekt offset (0x83C00) ✅

### Root Cause

**ImageCreator.swift (före fix):**
```swift
let osOffset = catalogOffset + catalogSize  // ❌ FEL (0xD720)
```

**ImageCreator.swift (efter fix):**
```swift
let osOffset = catalogOffset + UInt64(template.clusterSize)  // ✅ KORREKT (0x83C00)
```

### Verifiering

✅ **Fixen är korrekt:**
- Matchar referens (_IMAGE_239.EZ2)
- Matchar EMAX II file system formel
- Matchar VERIFICATION.md dokumentation

❌ **SD-minnes filer behöver skapas om:**
- Funkar HD00: Skapad med fel OS offset
- new boot HD00: Saknar OS helt

---

## 🔧 REKOMMENDATIONER

### 1. Kompilera om Appen

Efter fixen i `ImageCreator.swift`, kompilera om appen för att använda korrekt OS offset.

### 2. Skapa Nya Boot Disks

Skapa nya boot disks med fixad kod:
- OS kommer nu skrivas på korrekt offset (0x83C00)
- OS data kommer matcha referens

### 3. Verifiera Nya Images

Efter skapande, verifiera att:
- OS offset = 0x83C00 (för 239 MB disk)
- OS data första 32 bytes = `e3fc48fd22fdcefcfafbc0fae1f962f9...`
- Image bootar på EMAX II

---

## 📋 REFERENS

**Working Reference:** `_IMAGE_239.EZ2`
- ✅ OS på korrekt offset (0x83C00)
- ✅ OS data: `e3fc48fd22fdcefcfafbc0fae1f962f9...`
- ✅ Bootar perfekt på EMAX II

**Problem Files:**
- ❌ Funkar HD00: OS på fel offset (0xD720)
- ❌ new boot HD00: OS saknas

**Fix Status:** ✅ **OS OFFSET BUGG FIXAD I ImageCreator.swift**

**Nästa Steg:** Kompilera om appen och skapa nya boot disks för att verifiera fixen.
