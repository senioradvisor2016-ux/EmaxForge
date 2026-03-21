# Analys: EmaxII-01.ez2

**Datum:** 2026-03-06  
**Filstorlek:** 95.87 MB (100,528,128 bytes)  
**Diskstorlek:** 96 MB

---

## 📊 DISKSTRUKTUR

### Header Information
- **Magic:** EMX2 ✅
- **Cluster size:** 196,352 bytes (191.75 KB)
- **Cluster area start:** Sector 120 = 61,440 bytes (0xF000)
- **BNT start:** Sector 9 = 4,608 bytes (0x1200)
- **Max banks:** 111
- **FAT sectors:** 6

---

## ⚠️ IDENTIFIERADE PROBLEM

### 1. OS FAT Entry är FEL (KRITISKT) ❌

**Problem:**
- `FAT[1] = 0x0002` (pekar till cluster 2)
- **Förväntat:** `FAT[1] = 0x7FFF` (END marker för OS)

**Konsekvens:**
- OS är markerad som en multi-cluster kedja (cluster 1 → 2 → 3 → 4)
- OS använder 4 clusters istället för 1
- Detta kan orsaka problem vid boot om EMAX II förväntar sig OS på 1 cluster

**OS Cluster Chain:**
```
Cluster 1: 0x0002 → cluster 2
Cluster 2: 0x0003 → cluster 3
Cluster 3: 0x0004 → cluster 4
Cluster 4: 0x7FFF (END)
```

**Rekommendation:**
- OS bör normalt vara på 1 cluster med `FAT[1] = 0x7FFF`
- Om OS faktiskt är större än 1 cluster, kan detta vara korrekt, men ovanligt

---

### 2. OS PLACEMENT VERIFIERING ✅

**OS Signature Check:**
- ✅ OS signature match vid **new offset (0x3EF00)**
- ❌ Ingen OS signature vid old offset (0xF000)

**Formler:**
- **Old formula:** `clusterAreaStart + 0` = 0xF000 (61,440 bytes)
- **New formula:** `clusterAreaStart + clusterSize` = 0x3EF00 (257,792 bytes)

**Slutsats:**
- ✅ **New formula är KORREKT!**
- OS är faktiskt på `clusterAreaStart + clusterSize` (0x3EF00)
- Detta bekräftar att vår fix i `ImageCreator.swift` är korrekt

---

## 📚 BANKS

**Totalt:** 51 banks i katalogen

**Första 10 banks:**
1. 💻 EMAX2 Software (OS) - cluster 1, idx: 0x7800
2. 🎵 12 STRING - cluster 5, idx: 0x0000
3. 🎵 12 STRING - cluster 20, idx: 0x0200
4. 🎵 6 STRING GTR - cluster 37, idx: 0x0400
5. 🎵 8ARCATOSTRNG - cluster 49, idx: 0x0600
6. 🎵 9FT GRAND - cluster 63, idx: 0x0800
7. 🎵 AFRICAN INST - cluster 80, idx: 0x0A00
8. 🎵 ALEMBIC BASS - cluster 95, idx: 0x0C00
9. 🎵 ANALOGSTRING - cluster 109, idx: 0x0E00
10. 🎵 ANALOG COMBO - cluster 126, idx: 0x1000

**Första bank (12 STRING):**
- Start cluster: 5
- FAT[5]: 0x0006 (kedja fortsätter)
- Old formula offset: 0xCEC00
- New formula offset: 0xFEB00

**Observera:** Första banken börjar på cluster 5, vilket stämmer med att OS använder cluster 1-4.

---

## 🔍 FAT TABELL STATUS

- **FAT[0]:** 0x8000 ✅ (reserved, korrekt)
- **FAT[1]:** 0x0002 ❌ (borde vara 0x7FFF för OS END)
- **Använda clusters:** 477 (cluster 2-511)
- **Första använda cluster:** 2

---

## ✅ BEKRÄFTELSER

1. **OS Placement Formula:** ✅ KORREKT
   - New formula (`clusterAreaStart + clusterSize`) är korrekt
   - OS signature matchar vid new offset
   - Vår fix i `ImageCreator.swift` är verifierad

2. **Bank Placement Formula:** ✅ KORREKT
   - Banker börjar på cluster 5 (efter OS på cluster 1-4)
   - FAT-kedjor ser korrekta ut för banker

---

## 🎯 REKOMMENDATIONER

### För denna disk:
1. **FAT[1] fix:** Om möjligt, ändra `FAT[1]` från `0x0002` till `0x7FFF` om OS faktiskt bara behöver 1 cluster
2. **Verifiera OS storlek:** Kontrollera om OS verkligen behöver 4 clusters eller om det är ett fel

### För EmaxForge:
1. ✅ **OS placement fix är korrekt** - fortsätt använda `clusterAreaStart + clusterSize`
2. ✅ **Bank placement fix är korrekt** - fortsätt använda `clusterAreaStart + cluster * clusterSize`
3. ⚠️ **OS FAT entry:** Se till att OS alltid har `FAT[1] = 0x7FFF` om OS är 1 cluster

---

## 📝 SLUTSATS

**Huvudsakliga fynd:**
- ✅ OS placement formel är korrekt (new formula)
- ✅ Bank placement formel är korrekt (new formula)
- ⚠️ OS FAT entry är felaktig (multi-cluster istället för END marker)
- ✅ Diskstrukturen är annars korrekt

**Status:** Disk ser ut att vara fungerande, men OS FAT entry kan orsaka problem vid boot om EMAX II förväntar sig OS på 1 cluster med END marker.
