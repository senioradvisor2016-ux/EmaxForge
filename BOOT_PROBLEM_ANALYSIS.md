# Boot Problem Analys: FORGE EMAX PROBLEM vs FUNKAR

**Datum:** 2026-03-06  
**Syfte:** Identifiera varför "FORGE EMAX PROBLEM" inte bootar på EMAX II

---

## 🔍 HUVUDPROBLEM

### **KRITISK VARNING i zululog.txt:**
```
WARNING: file HD00.hda is not contiguous. This will increase read latency.
```

**Detta är troligen huvudorsaken till boot-problemet!**

---

## 📊 DETALJERAD JÄMFÖRELSE

### 1. **ZuluSCSI Config (zuluscsi.ini)**

**Båda är identiska:**
```ini
; ZuluSCSI config for EMAX II
[SCSI]
EnableParity = 1

[SCSI1]
```

✅ **Ingen skillnad här** - config är korrekt.

---

### 2. **HD00.hda (Boot Disk) - OS Struktur**

#### FUNKAR (fungerande):
- ✅ Magic: EMX2
- ✅ FAT Entry 0: 0x8000 (reserved, korrekt)
- ✅ FAT Entry 1: 0x7FFF (OS END marker, korrekt)
- ✅ OS Name: "EMAX2 Software"
- ✅ OS Bank Index: 30720 (0x7800, korrekt)
- ✅ OS Start Cluster: 1 (korrekt)
- ✅ OS Field C: 0x0081 (CRITICAL flag, korrekt)
- ✅ OS Data Size: 489,472 bytes (478.0 KB, korrekt)
- ✅ OS Data: Identisk med FORGE EMAX PROBLEM
- ✅ Boot Signature: 0x78 0x82 (korrekt)
- ✅ **Använda clusters: 165** (många banks)
- ✅ **101 banks totalt** (OS + 100 sample banks)

#### FORGE EMAX PROBLEM (fungerar inte):
- ✅ Magic: EMX2
- ✅ FAT Entry 0: 0x8000 (reserved, korrekt)
- ✅ FAT Entry 1: 0x7FFF (OS END marker, korrekt)
- ✅ OS Name: "EMAX2 Software"
- ✅ OS Bank Index: 30720 (0x7800, korrekt)
- ✅ OS Start Cluster: 1 (korrekt)
- ✅ OS Field C: 0x0081 (CRITICAL flag, korrekt)
- ✅ OS Data Size: 489,472 bytes (478.0 KB, korrekt)
- ✅ OS Data: Identisk med FUNKAR
- ✅ Boot Signature: 0x78 0x82 (korrekt)
- ❌ **Använda clusters: 0** (bara OS, inga andra banks)
- ❌ **1 bank totalt** (bara OS)

**🔴 KRITISK SKILLNAD:** FORGE EMAX PROBLEM har bara OS, inga sample banks på HD00.hda.

---

### 3. **FAT-Tabell Jämförelse**

#### FUNKAR:
```
Entry   0: 0x8000 (reserved)
Entry   1: 0x7FFF (OS END marker)
Entry   2: 0x0003 (→ cluster 3)
Entry   3: 0x0004 (→ cluster 4)
Entry   4: 0x0005 (→ cluster 5)
Entry   5: 0x0006 (→ cluster 6)
Entry   6: 0x7FFF (END)
Entry   7: 0x0008 (→ cluster 8)
... (många använda clusters)
```

#### FORGE EMAX PROBLEM:
```
Entry   0: 0x8000 (reserved)
Entry   1: 0x7FFF (OS END marker)
Entry   2: 0x0000 (tom)
Entry   3: 0x0000 (tom)
Entry   4: 0x0000 (tom)
... (alla tomma)
```

**🔴 SKILLNAD:** FUNKAR har många använda clusters, FORGE EMAX PROBLEM har bara OS.

---

### 4. **SD-Kort Fragmentering**

#### FUNKAR:
- ✅ Filen är **kontinuerlig** på SD-kortet
- ✅ Ingen varning i zululog.txt
- ✅ Snabb läsning, ingen latens

#### FORGE EMAX PROBLEM:
- ❌ Filen är **INTE kontinuerlig** (fragmenterad)
- ❌ **WARNING: file HD00.hda is not contiguous. This will increase read latency.**
- ❌ Ökad latens kan orsaka boot-timeout

**🔴 HUVUDPROBLEM:** Fragmenterad fil på SD-kortet!

---

## 🎯 ROOT CAUSE ANALYSIS

### Problem 1: Fragmenterad Fil (KRITISKT)
**Symptom:** `WARNING: file HD00.hda is not contiguous`

**Orsak:**
- Filen är fragmenterad på SD-kortet
- När EMAX II försöker läsa OS från cluster 1, måste SD-kortet hoppa mellan olika fysiska sektorer
- Detta orsakar latens och kan leda till timeout

**Lösning:**
1. Defragmentera SD-kortet
2. Ta bort och återskapa HD00.hda på ett kontinuerligt sätt
3. Använd `dd` för att kopiera filen kontinuerligt

### Problem 2: Tom FAT-Tabell (MINDRE KRITISKT)
**Symptom:** Bara OS på HD00.hda, inga sample banks

**Orsak:**
- HD00.hda är nästan tom (bara OS)
- Detta är inte nödvändigtvis ett problem, men kan indikera att filen inte är korrekt skapad

**Lösning:**
- Inte nödvändigt för boot, men kan vara en indikator på problem

---

## 💡 LÖSNINGAR

### Lösning 1: Defragmentera SD-kortet (REKOMMENDERAD)

**Steg:**
1. Kopiera alla filer från SD-kortet till datorn
2. Formatera SD-kortet (FAT32, full format)
3. Kopiera tillbaka filerna i rätt ordning:
   - Först: zuluscsi.ini
   - Sedan: HD00.hda (kontinuerligt)
   - Sedan: HD10.hda (kontinuerligt)

**Alternativ med `dd`:**
```bash
# Kopiera HD00.hda kontinuerligt till SD-kortet
dd if=HD00.hda of=/dev/diskX bs=1M conv=fsync
```

### Lösning 2: Återskapa HD00.hda

**Steg:**
1. Använd EmaxForge för att skapa en ny HD00.hda
2. Se till att filen skrivs kontinuerligt till SD-kortet
3. Verifiera att filen är kontinuerlig:
   ```bash
   # På macOS, kontrollera fragmentering
   diskutil info /dev/diskX | grep -i fragment
   ```

### Lösning 3: Använd FUNKAR som mall

**Steg:**
1. Kopiera HD00.hda från FUNKAR
2. Ersätt OS med din egen OS om nödvändigt
3. Se till att filen kopieras kontinuerligt till SD-kortet

---

## ✅ VERIFIERING

Efter fix, kontrollera:

1. **Ingen varning i zululog.txt:**
   ```
   -- Opening 'HD00.hda' for id: 0
   ---- Configuring as disk drive drive
   (ingen WARNING om fragmentering)
   ```

2. **Filen är kontinuerlig:**
   - Kontrollera med `diskutil info` eller liknande
   - Ingen fragmentering

3. **EMAX II bootar:**
   - EMAX II startar korrekt
   - OS laddas utan timeout

---

## 📝 SLUTSATS

**Huvudproblem:** Filen HD00.hda är fragmenterad på SD-kortet, vilket orsakar latens och boot-timeout.

**Lösning:** Defragmentera eller återskapa filen kontinuerligt på SD-kortet.

**Sekundärt problem:** HD00.hda är nästan tom (bara OS), men detta är inte nödvändigtvis ett problem för boot.

---

## 🔧 IDENTIFIERADE KODPROBLEM (2026-03-06)

### Problem 3: OS skrivs till fel cluster (KRITISKT) ❌ → ✅ FIXAT

**Symptom:** OS skrivs till cluster 0 istället för cluster 1.

**Kodproblem:**
- `ImageCreator.createBootableImage()` skrev OS till `caOffset` (cluster area start)
- Detta är cluster 0, men OS måste vara på cluster 1!
- Enligt VERIFICATION.md: OS ska vara på `clusterAreaStart + clusterSize`

**Fix:**
```swift
// FÖRE (felaktig):
handle.seek(toFileOffset: caOffset)  // Cluster 0 ❌

// EFTER (korrekt):
let osOffset = caOffset + UInt64(clusterSize)  // Cluster 1 ✅
handle.seek(toFileOffset: osOffset)
```

**Impact:** Om OS skrivs till fel cluster kan EMAX II inte hitta och ladda OS vid boot!

### Problem 4: Bank-import använder fel cluster-offset formel (KRITISKT) ❌ → ✅ FIXAT

**Symptom:** Banker kan bläddras men inte laddas på EMAX II.

**Kodproblem:**
- `BankImporter` använde: `clusterAreaOffset + (cluster - 1) * clusterSize`
  - Cluster 1 → `clusterAreaOffset + 0` = 0xC400
  - Cluster 2 → `clusterAreaOffset + clusterSize` = 0x83C00
- Men enligt VERIFICATION.md är OS (cluster 1) på 0x83C00 = `clusterAreaStart + clusterSize`
- Detta betyder att formeln ska vara: `clusterAreaOffset + (cluster * clusterSize)`
  - Cluster 1 → `clusterAreaOffset + clusterSize` = 0x83C00 ✅
  - Cluster 2 → `clusterAreaOffset + 2*clusterSize` = 0xFB400 ✅

**Fix:**
```swift
// FÖRE (felaktig):
func clusterOffset(_ cluster: Int) -> UInt64 {
    clusterAreaOffset + UInt64(cluster - 1) * UInt64(clusterSize)
}

// EFTER (korrekt):
func clusterOffset(_ cluster: Int) -> UInt64 {
    clusterAreaOffset + UInt64(cluster) * UInt64(clusterSize)
}
```

**Impact:** Om banker skrivs till fel cluster-offset kan EMAX II inte läsa bank-data korrekt, även om katalogen är korrekt!

### Problem 5: Bank-import felhantering (MINDRE KRITISKT) ❌ → ✅ FIXAT

**Symptom:** Bank-importfel ignoreras tyst med `try?`, användaren får ingen feedback.

**Kodproblem:**
- `BootableDiskWizard.swift` använder `try?` vilket döljer fel
- Om bank-import misslyckas får användaren ingen varning

**Fix:**
- Ändrat till `do-catch` med felmeddelanden i konsolen
- Fortsätter med andra banker istället för att krascha hela processen

**Impact:** Användaren kan nu se om banker misslyckas att importeras, men processen fortsätter.
