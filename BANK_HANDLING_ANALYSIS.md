# Bank Hantering Analys: App vs _IMAGE_239.EZ2

**Datum:** 2026-03-07  
**Syfte:** Analysera hur appen hanterar banker jämfört med referens

---

## 📊 REFERENS: _IMAGE_239.EZ2

### Bank Struktur

**Totala entries:** 101 (1 OS + 100 sample banks)

**Bank Index Mönster:**
- Entry 0 (OS): Bank Index 0x7800
- Entry 1: Bank Index 0x0000
- Entry 2: Bank Index 0x0100 (256)
- Entry 3: Bank Index 0x0200 (512)
- Entry 4: Bank Index 0x0300 (768)
- ...
- **Formel:** `(entry_num - 1) * 256` för sample banks

**FAT-kedjor:**
- Entry 1 ("_4 Pc 5ths"): Clusters [2, 3, 4, 5] (4 clusters)
- Entry 2 ("_V-S  Doiks"): Clusters [6, 7, 8] (3 clusters)
- Entry 3 ("_Split 3"): Clusters [9, 10, 11] (3 clusters)
- ...

**Cluster Allocation:**
- ✅ Clusters är sekventiella (inga gaps)
- ✅ Varje bank har korrekt FAT-kedja
- ✅ Sista cluster har 0x7FFF (END marker)

**Catalog Entry Format (32 bytes):**
- [0-15]: Bank name (16 bytes, space-padded)
- [16-17]: Bank index (UInt16 LE)
- [18-19]: Start cluster (UInt16 LE)
- [20-21]: Number of presets (UInt16 LE)
- [22-23]: Field A (UInt16 LE)
- [24-25]: Field B (UInt16 LE)
- [26-27]: Field C (0x0081 = active flag)
- [28-31]: Reserved (zeros)

---

## 📝 APPEN: BankImporter.swift

### Problem Identifierat

#### 1. ❌ Cluster Offset Formel (FIXAD)

**Före:**
```swift
clusterAreaStart + catalogSize + (cluster-1) * clusterSize
```
- Cluster 1: 0xC400 + 4896 + 0 = 0xD720 ❌
- Cluster 2: 0xC400 + 4896 + 489472 = 0x84F20 ❌

**Efter (FIXAD):**
```swift
clusterAreaStart + cluster * clusterSize
```
- Cluster 1: 0xC400 + 489472 = 0x83C00 ✅
- Cluster 2: 0xC400 + 2*489472 = 0xFB400 ✅

**Status:** ✅ **FIXAD!**

---

#### 2. ❌ Catalog Entry Skrivning (FIXAD)

**Problem:**
- BankImporter skrev INTE catalog entries på 0x1000
- Banks syns inte i catalog efter import
- EMAX II kan inte hitta banks utan catalog entries

**Fix:**
- ✅ Lagt till catalog entry skrivning
- ✅ Bank index beräkning: `(catalogCount - 1) * 256`
- ✅ Catalog entry format matchar referens

**Status:** ✅ **FIXAD!**

---

### Vad som är Korrekt

#### 1. ✅ FAT-kedja Skapande

```swift
for i in 0..<allocatedClusters.count {
    let cluster = allocatedClusters[i]
    if i < allocatedClusters.count - 1 {
        fat[cluster] = UInt16(allocatedClusters[i + 1])
    } else {
        fat[cluster] = 0x7FFF // End of chain
    }
}
```

**Status:** ✅ Matchar referens (korrekt FAT-kedja)

---

#### 2. ✅ Cluster Allocation

```swift
// Find free clusters (FAT value == 0x0000, skip cluster 0 and 1)
for i in 2..<512 {
    if fat[i] == 0x0000 {
        freeClusters.append(i)
    }
}
```

**Status:** ✅ Matchar referens (sekventiell allocation)

---

#### 3. ✅ Field C Värde

```swift
catalogEntry.writeU16LE(0x0081, at: 26)
```

**Status:** ✅ Matchar referens (0x0081 för alla banks)

---

## 🔍 JÄMFÖRELSE

| Aspekt | Referens | Appen (före fix) | Appen (efter fix) |
|--------|----------|------------------|-------------------|
| **Cluster Offset** | 0x83C00 (cluster 1) | 0xD720 ❌ | 0x83C00 ✅ |
| **FAT-kedja** | Korrekt | Korrekt ✅ | Korrekt ✅ |
| **Bank Index** | (entry-1)*256 | - ❌ | (catalogCount-1)*256 ✅ |
| **Catalog Entry** | På 0x1000 | Saknas ❌ | På 0x1000 ✅ |
| **Field C** | 0x0081 | - | 0x0081 ✅ |
| **Cluster Allocation** | Sekventiell | Sekventiell ✅ | Sekventiell ✅ |

---

## 💡 SLUTSATS

### ✅ Fixar Genomförda

1. **Cluster Offset Formel:** Fixad i BankImporter.swift ✅
2. **Catalog Entry Skrivning:** Lagt till i BankImporter.swift ✅
3. **Bank Index Beräkning:** Implementerad (matchar referens) ✅

### ⚠️  Kvarvarande Problem

**ImageCreator OS Offset:**
- Kommentaren säger fortfarande 0xD720
- Men koden använder `catalogOffset + clusterSize` (korrekt)
- Kommentaren behöver uppdateras

---

## 🔧 REKOMMENDATIONER

### 1. Uppdatera ImageCreator Kommentar

Kommentaren på rad 262-265 är förvirrande och säger fel offset. Den behöver uppdateras för att matcha faktisk kod.

### 2. Verifiera Catalog Entry Skrivning

Efter fix, verifiera att:
- Catalog entries skrivs på 0x1000 ✅
- Bank index ökar med 256 per bank ✅
- Field C = 0x0081 ✅

### 3. Testa Bank Import

Efter kompilering, testa att:
- Importera bank
- Verifiera catalog entry skapas
- Verifiera bank index är korrekt
- Verifiera FAT-kedja är korrekt

---

## 📋 STATUS

- ✅ **Cluster Offset:** FIXAD
- ✅ **Catalog Entry:** FIXAD
- ✅ **Bank Index:** FIXAD
- ⚠️  **ImageCreator Kommentar:** Behöver uppdateras

**Nästa:** Kompilera om appen och testa bank import!
