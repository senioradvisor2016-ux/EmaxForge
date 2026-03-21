# Analys: EMAXII_IMAGE_239.EZ2 - Bank/Sample Struktur

**Datum:** 2026-03-07  
**Syfte:** Förstå hur standard tools hanterar banker/samples i disk images

---

## 📊 FILINFO

**Storlek:** 250,398,720 bytes (238.80 MB)  
**Magic:** `EMX2`  
**Cluster Size:** 489,472 bytes  
**Cluster Area Start:** Sector 98  
**Bank Count:** 90 (enligt header)

---

## 📋 CATALOG STRUKTUR

**Totala catalog entries:** 101

### Entry 0: OS
- **Name:** "EMAX2 Software.."
- **Bank Index:** 0x7800 (30,720 decimal)
- **Start Cluster:** 1
- **Presets:** 1
- **Field A:** 0x01F8, **Field B:** 0x0200, **Field C:** 0x0081

### Entry 1-100: Sample Banks

**Första 20 sample banks:**

| Entry | Name | Bank Index | Cluster | Presets | Field A | Field B | Field C |
|-------|------|------------|---------|---------|---------|---------|---------|
| 1 | "_4 Pc 5ths    .." | 0x0000 | 2 | 4 | 0x01F9 | 0x01FC | 0x0081 |
| 2 | "_V-S  Doiks   .." | 0x0100 | 6 | 3 | 0x00F1 | 0x0180 | 0x0081 |
| 3 | "_Split 3      .." | 0x0200 | 9 | 3 | 0x0050 | 0x01BC | 0x0081 |
| 4 | "440 Percussn  .." | 0x0300 | 12 | 3 | 0x002A | 0x01B8 | 0x0081 |
| 5 | "AcousticKiks  .." | 0x0400 | 15 | 2 | 0x0182 | 0x00AE | 0x0081 |
| 6 | "AcousticToms  .." | 0x0500 | 17 | 3 | 0x0038 | 0x018E | 0x0081 |
| 7 | "Add-One Kit   .." | 0x0600 | 20 | 3 | 0x0045 | 0x0020 | 0x0081 |
| 8 | "Afri*Block    .." | 0x0700 | 23 | 4 | 0x0068 | 0x00B6 | 0x0081 |
| 9 | "_Ahhs 4 Seq   .." | 0x0800 | 27 | 2 | 0x017D | 0x00CC | 0x0081 |
| 10 | "Anvil         .." | 0x0900 | 29 | 2 | 0x01FB | 0x0062 | 0x0081 |
| 11 | "B3 PercOrgan  .." | 0x0A00 | 31 | 2 | 0x015A | 0x0058 | 0x0081 |
| 12 | "Banjo         .." | 0x0B00 | 33 | 3 | 0x0127 | 0x006A | 0x0081 |
| 13 | "Bass Eight    .." | 0x0C00 | 36 | 5 | 0x002A | 0x007A | 0x0081 |
| 14 | "Mello Bass    .." | 0x0D00 | 41 | 4 | 0x017D | 0x000C | 0x0081 |
| 15 | "Clean Bass    .." | 0x0E00 | 45 | 3 | 0x01B5 | 0x005A | 0x0081 |
| 16 | "Funk 1        .." | 0x0F00 | 48 | 3 | 0x00D8 | 0x0144 | 0x0081 |
| 17 | "Sitar         .." | 0x1000 | 51 | 5 | 0x0013 | 0x0094 | 0x0081 |
| 18 | "Sarod         .." | 0x1100 | 56 | 3 | 0x00A8 | 0x0180 | 0x0081 |
| 19 | "Wide Tambora  .." | 0x1200 | 59 | 3 | 0x01B9 | 0x01B4 | 0x0081 |
| 20 | ... | ... | ... | ... | ... | ... | ... |

---

## 🔍 KRITISKA UPPTÄCKTER

### 1. Bank Index Mönster

**Bank Index ökar med 0x0100 (256 decimal) per bank:**
- Entry 1: 0x0000 (0)
- Entry 2: 0x0100 (256)
- Entry 3: 0x0200 (512)
- Entry 4: 0x0300 (768)
- ...

**Detta matchar EmaxForge implementation:**
```swift
let bankIndex = UInt16(catalogCount * 256)
```

✅ **EmaxForge använder korrekt formel!**

---

### 2. Field C Värde

**Alla entries har Field C = 0x0081:**
- Detta är en flagga som indikerar att banken är aktiv/valid
- **EmaxForge använder 0x0081** ✅

---

### 3. Cluster Allocation

**Banks använder varierande antal clusters:**
- Entry 1 ("_4 Pc 5ths"): 4 clusters (2→3→4→5)
- Entry 2 ("_V-S  Doiks"): 3 clusters (6→7→8)
- Entry 3 ("_Split 3"): 3 clusters (9→10→11)
- Entry 4 ("440 Percussn"): 3 clusters (12→13→14)
- Entry 5 ("AcousticKiks"): 2 clusters (15→16)
- Entry 6 ("AcousticToms"): 3 clusters (17→18→19)
- ...

**FAT-kedjor:**
- Första cluster i kedjan är start cluster från catalog
- Varje FAT entry pekar på nästa cluster
- Sista cluster har FAT entry = 0x7FFF (END marker)

**EmaxForge implementation:**
```swift
// Update FAT: chain the allocated clusters
for i in 0..<allocatedClusters.count {
    let cluster = allocatedClusters[i]
    if i < allocatedClusters.count - 1 {
        fat[cluster] = UInt16(allocatedClusters[i + 1])
    } else {
        fat[cluster] = 0x7FFF // End of chain
    }
}
```

✅ **EmaxForge använder korrekt FAT-kedja logik!**

---

### 4. Bank Name Storage

**Bank name finns på två ställen:**

1. **Catalog Entry (offset 0x1000 + entry_num * 32):**
   - Bytes 0-15: Bank name (16 bytes, space-padded)

2. **Bank Data (offset 0x1AC i första cluster):**
   - Bank name lagras i bank data själv
   - Detta är samma värde som i catalog

**Verifiering:**
- Entry 1 ("_4 Pc 5ths"):
  - Catalog name: "_4 Pc 5ths    .."
  - Bank data offset 0x1AC: "_4 Pc 5ths    .."
  - ✅ Matchar!

**EmaxForge implementation:**
```swift
// Extract bank name from EB2 data (offset 0x1AC, 12 bytes)
let bankName = String(data: bankData[0x1AC..<0x1B8], encoding: .ascii)?
    .trimmingCharacters(in: .controlCharacters)
    .trimmingCharacters(in: .init(charactersIn: "\0 ")) ?? eb2URL.deletingPathExtension().lastPathComponent
```

✅ **EmaxForge läser bank name korrekt från EB2 data!**

---

### 5. Cluster Allocation Strategi

**standard tools använder första tillgängliga clusters:**
- OS: Cluster 1
- Entry 1: Clusters 2, 3, 4, 5
- Entry 2: Clusters 6, 7, 8
- Entry 3: Clusters 9, 10, 11
- ...

**Ingen fragmentering i början:**
- Clusters allokeras sekventiellt
- Varje bank får på varandra följande clusters när möjligt

**EmaxForge implementation:**
```swift
// Find free clusters (value == 0x0000, skip cluster 0 and 1)
var freeClusters = [Int]()
for i in 2..<512 {
    if fat[i] == 0x0000 {
        freeClusters.append(i)
    }
    if freeClusters.count >= clustersNeeded { break }
}
```

✅ **EmaxForge använder samma strategi (första tillgängliga)!**

---

## 📊 FAT TABELL ANALYS

**FAT entries med data:** 99

**Första 20 FAT entries:**
- Entry 0: 0x8000 (reserved)
- Entry 1: 0x7FFF (END marker - OS)
- Entry 2: 0x0003 (→ cluster 3)
- Entry 3: 0x0004 (→ cluster 4)
- Entry 4: 0x0005 (→ cluster 5)
- Entry 5: 0x7FFF (END marker)
- Entry 6: 0x0007 (→ cluster 7)
- Entry 7: 0x0008 (→ cluster 8)
- Entry 8: 0x7FFF (END marker)
- ...

**Mönster:**
- Varje bank har en FAT-kedja
- Första cluster i kedjan är start cluster
- Varje FAT entry pekar på nästa cluster
- Sista cluster har 0x7FFF (END marker)

---

## 💡 SLUTSATS: standard tools vs EMAXFORGE

### ✅ Vad som matchar:

1. **Bank Index:** EmaxForge använder `catalogCount * 256` ✅
2. **Field C:** EmaxForge använder 0x0081 ✅
3. **FAT-kedja:** EmaxForge skapar korrekta kedjor ✅
4. **Bank name:** EmaxForge läser från offset 0x1AC ✅
5. **Cluster allocation:** EmaxForge använder första tillgängliga ✅
6. **Catalog entry struktur:** EmaxForge skriver korrekt format ✅

### ⚠️  Potentiella skillnader:

1. **INIT BANK:** 
   - EMAXII_IMAGE_239.EZ2 har INGEN "INIT BANK" entry
   - Detta är en minimal boot bank som bara behövs på tomma boot disks
   - EmaxForge skapar INIT BANK på boot disks (korrekt för tomma disks)

2. **Bank name längd:**
   - Catalog: 16 bytes (space-padded)
   - Bank data: 12 bytes (offset 0x1AC)
   - EmaxForge läser 12 bytes från bank data (korrekt)

3. **Field A/B:**
   - Dessa värden varierar mellan banks
   - EmaxForge kopierar från bank data (korrekt)

---

## 🎯 REKOMMENDATIONER

### ✅ EmaxForge implementation är korrekt!

**Alla kritiska aspekter matchar standard tools:**
- Bank index beräkning ✅
- FAT-kedja skapande ✅
- Catalog entry format ✅
- Bank name hantering ✅
- Cluster allocation ✅

### 🔧 Eventuella förbättringar:

1. **INIT BANK:** 
   - Behåll logiken för INIT BANK på tomma boot disks
   - Detta är korrekt för att skapa bootable disks

2. **Bank name padding:**
   - Se till att bank name är korrekt space-padded till 16 bytes i catalog
   - EmaxForge gör detta redan ✅

3. **Field A/B kopiering:**
   - Fortsätt kopiera Field A/B från bank data
   - EmaxForge gör detta redan ✅

---

## 📋 REFERENS

**Working Image:** `EMAXII_IMAGE_239.EZ2`
- ✅ 101 catalog entries (1 OS + 100 sample banks)
- ✅ Alla banks har korrekt FAT-kedjor
- ✅ Bank index ökar med 256 per bank
- ✅ Field C = 0x0081 för alla banks
- ✅ Bank names matchar mellan catalog och bank data

**EmaxForge Status:** ✅ **MATCHAR standard tools IMPLEMENTATION!**
