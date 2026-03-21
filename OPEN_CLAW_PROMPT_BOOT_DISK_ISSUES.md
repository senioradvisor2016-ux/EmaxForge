# Prompt för Open Claw: EMAX II Boot Disk Skapande Problem

**Datum:** 2026-03-07  
**Kontext:** EmaxForge applikation för att skapa bootable EMAX II disk images för ZuluSCSI Pico

---

## 🎯 PROBLEM BESKRIVNING

EmaxForge skapar EMAX II boot- och samplediskar, men två kritiska problem har identifierats:

### Problem 1: INIT BANK FAT-struktur är felaktig

**Symptom:**
- När `ImageCreator.createBootableImage()` skapar HD00.hda, ska INIT BANK (minimal boot bank) spänna över 5 clusters (2→3→4→5→6)
- Men skapade filer har FAT[2] = 0x7FFF (END marker direkt), vilket betyder bara 1 cluster
- Funkar HD00.hda (verifierad working reference) har FAT[2] = 0x0003 (5 clusters: 2→3→4→5→6)

**Kod:**
```swift
// ImageCreator.swift - writeMinimalBootBank()
// Skriver INIT BANK data till clusters 2-6 (fungerar)
for clusterIndex in 2...6 {
    let clusterOffset = clusterAreaStart + (UInt64(clusterIndex) * UInt64(template.clusterSize))
    handle.seek(toFileOffset: clusterOffset)
    handle.write(emptyCluster)
}

// Skriver FAT entries (FUNGERAR INTE!)
handle.seek(toFileOffset: 0x400 + (2 * 2))  // FAT entry 2
handle.write(Data([0x03, 0x00]))  // FAT[2] = 0x0003
handle.synchronizeFile()

handle.seek(toFileOffset: 0x400 + (3 * 2))  // FAT entry 3
handle.write(Data([0x04, 0x00]))  // FAT[3] = 0x0004
handle.synchronizeFile()
// ... etc för entries 4, 5, 6
```

**Resultat:**
- INIT BANK data finns i cluster 2 (9 non-zero bytes, "INIT BANK" name) ✅
- Clusters 3-6 är tomma (0 non-zero bytes) ✅
- FAT[2] = 0x7FFF (felaktigt - ska vara 0x0003) ❌
- FAT[3-6] = 0x0000 (felaktigt - ska vara 0x0004, 0x0005, 0x0006, 0x7FFF) ❌

**Förväntat resultat (Funkar HD00.hda):**
- FAT[2] = 0x0003 (→ cluster 3)
- FAT[3] = 0x0004 (→ cluster 4)
- FAT[4] = 0x0005 (→ cluster 5)
- FAT[5] = 0x0006 (→ cluster 6)
- FAT[6] = 0x7FFF (END marker)

---

### Problem 2: HD10 skapas som mirror av HD00

**Symptom:**
- HD10.hda ska vara blank data disk för samples/banks
- Men HD10.hda är binärt identisk med HD00.hda (mirror)
- Loggen visar: "Created HD10.hda mirror successfully"

**Kod:**
```swift
// ImageCreator.swift - createBootableImage()
// Mirror-logik är BORTTAGEN från källkoden
// Men kompilerad kod använder fortfarande gammal version

// BootableDiskWizard.swift - startCreation()
if i == 0 && includeOS, let osURL = osFileURL {
    try ImageCreator.createBootableImage(at: destURL, sizeMB: sizeMB, osFileURL: osURL)
} else {
    // HD10 ska skapas här som blank data disk
    try ImageCreator.createBlankImage(at: destURL, sizeMB: sizeMB)
}
```

**Resultat:**
- HD10.hda är binärt identisk med HD00.hda ❌
- HD10 har OS data (ska vara blank) ❌
- HD10 har INIT BANK (ska vara blank) ❌

**Förväntat resultat:**
- HD10.hda är blank data disk (ingen OS, tom catalog)
- HD10 används för sample storage
- HD10 är INTE identisk med HD00

---

## 📋 TEKNISK KONTEKST

### EMAX II File System Struktur:

**Header (Sector 0):**
- Magic: `EMX2` (0x45 0x4D 0x58 0x32)
- Cluster Size: 489,472 bytes (239 MB disk)
- Cluster Area Start: Sector 98
- Boot Signature: 0x78 0x82 (size-specific)

**FAT Tabell (Sectors 2-3, offset 0x400):**
- Entry 0: 0x8000 (reserved)
- Entry 1: 0x7FFF (OS END marker)
- Entry 2+: Cluster chains eller 0x0000 (free)

**Catalog (Offset 0x1000):**
- Entry 0: OS ("EMAX2 Software", cluster 1, Field C = 0x0081)
- Entry 1: INIT BANK ("INIT BANK", cluster 2, Field C = 0x0081)
- Entry 2+: Sample banks

**Cluster Structure:**
- Cluster 0: Reserved
- Cluster 1: OS data
- Cluster 2-6: INIT BANK (5 clusters, required for boot)
- Cluster 7+: Sample banks

---

## 🔍 VERIFIERING MOT DEKOMPILERADE standard tools FILER

**Totalt:** 3,395 dekompilerade .c filer analyserade

**Kritiska värden hittade:**
- 0x8000 (FAT Entry 0): 3 filer
- 0x7FFF (FAT END marker): Flera filer
- 0x0081 (Field C): 11 filer
- 0x1000 (Catalog start): 5 filer
- 0x400 (FAT start): 6 filer
- 0x200 (Bank Status Table): 7 filer
- 0x80 (Empty marker): 9 filer

**Slutsats:** EmaxForge använder korrekta värden från standard tools templates ✅

---

## 🎯 UPPDRAG FÖR OPEN CLAW

### 1. Fixa INIT BANK FAT Write Problem

**Problem:**
- `writeMinimalBootBank()` skriver INIT BANK data korrekt (clusters 2-6)
- Men FAT entries skrivs INTE korrekt (FAT[2] = 0x7FFF istället för 0x0003)

**Möjliga orsaker:**
1. `handle.seek()` positionerar fel
2. `handle.write()` skriver inte korrekt
3. `handle.synchronizeFile()` synkar INTE
4. FileHandle caching problem
5. Byte order problem

**Åtgärd:**
- Analysera varför FAT entries inte skrivs korrekt
- Testa alternativa metoder för att skriva FAT entries
- Verifiera att `synchronizeFile()` faktiskt synkar
- Lägg till debug logging för att spåra problemet

**Förväntat resultat:**
- FAT[2] = 0x0003 (→ cluster 3)
- FAT[3] = 0x0004 (→ cluster 4)
- FAT[4] = 0x0005 (→ cluster 5)
- FAT[5] = 0x0006 (→ cluster 6)
- FAT[6] = 0x7FFF (END marker)

---

### 2. Fixa HD10 Mirror Problem

**Problem:**
- HD10.hda skapas som mirror av HD00.hda
- Källkoden är fixad (mirror-logik borttagen)
- Men kompilerad kod använder fortfarande gammal version

**Möjliga orsaker:**
1. Appen inte omkompilerad
2. Cached build i Xcode/Swift
3. Mirror-logik finns kvar någonstans

**Åtgärd:**
- Verifiera att mirror-logik är helt borttagen från källkoden
- Kontrollera att `BootableDiskWizard` inte skapar HD10 som mirror
- Se till att HD10 skapas med `createBlankImage()` (inte `createBootableImage()`)

**Förväntat resultat:**
- HD10.hda är blank data disk
- HD10 är INTE identisk med HD00
- HD10 har ingen OS data
- HD10 har tom catalog (förutom eventuella banks)

---

## 📊 REFERENS: FUNKAR HD00.HDA (Working)

**FAT Struktur:**
```
Entry 0: 0x8000 (reserved)
Entry 1: 0x7FFF (OS END)
Entry 2: 0x0003 (INIT BANK → cluster 3)
Entry 3: 0x0004 (→ cluster 4)
Entry 4: 0x0005 (→ cluster 5)
Entry 5: 0x0006 (→ cluster 6)
Entry 6: 0x7FFF (END marker)
```

**Catalog:**
- Entry 0: "EMAX2 Software", cluster 1, Field C = 0x0081
- Entry 1: "STEEL DRUMS", cluster 2, Field C = 0x0081
- (INIT BANK finns också i cluster 2-6)

**Status:** ✅ Bootar perfekt på EMAX II

---

## 🔧 TEKNISKA DETALJER

### FileHandle Operations:

**Nuvarande kod:**
```swift
let handle = try FileHandle(forUpdating: imageURL)
handle.seek(toFileOffset: 0x400 + (2 * 2))
handle.write(Data([0x03, 0x00]))
handle.synchronizeFile()
```

**Möjliga problem:**
- FileHandle kan cacha writes
- `synchronizeFile()` kanske inte synkar korrekt
- Byte order kan vara fel

**Alternativa lösningar:**
1. Använd `Data` buffer och skriv hela FAT på en gång
2. Använd `FileHandle.write(contentsOf:)` istället för `write()`
3. Lägg till explicit flush efter varje write
4. Verifiera efter write genom att läsa tillbaka

---

## ✅ VERIFIERINGSKRITERIER

**Efter fix, verifiera:**

1. **INIT BANK FAT-struktur:**
   - ✅ FAT[2] = 0x0003 (inte 0x7FFF)
   - ✅ FAT[3] = 0x0004
   - ✅ FAT[4] = 0x0005
   - ✅ FAT[5] = 0x0006
   - ✅ FAT[6] = 0x7FFF

2. **HD10 Data Disk:**
   - ✅ HD10 är INTE identisk med HD00
   - ✅ HD10 är blank (ingen OS, tom catalog)
   - ✅ HD10 kan importera banks

3. **Boot Test:**
   - ✅ HD00.hda bootar på EMAX II
   - ✅ HD10.hda fungerar som data disk

---

## 📝 FILER ATT GRANSKA

1. **EmaxForge/Sources/Services/ImageCreator.swift**
   - `createBootableImage()` - rad 185-322
   - `writeMinimalBootBank()` - rad 324-402
   - `createBlankImage()` - rad 404-471

2. **EmaxForge/Sources/Views/BootableDiskWizard.swift**
   - `startCreation()` - rad 855-970
   - HD10 skapande logik - rad 894-901

3. **Reference Files:**
   - `/Users/senioradvisor/clawd/BOOTY/Funkar/HD00.hda` (working reference)
   - `/Users/senioradvisor/clawd/EmaxForge/new boot/HD00.hda` (problem file)

---

## 💡 REKOMMENDATIONER

1. **FAT Write Fix:**
   - Använd `Data` buffer för hela FAT-sektionen
   - Skriv allt på en gång istället för sekventiellt
   - Verifiera efter write genom att läsa tillbaka

2. **HD10 Mirror Fix:**
   - Verifiera att ingen mirror-logik finns kvar
   - Se till att `BootableDiskWizard` skapar HD10 med `createBlankImage()`
   - Lägg till debug logging för att verifiera

3. **Testing:**
   - Skapa nya filer efter fix
   - Verifiera FAT-struktur matchar Funkar HD00
   - Testa boot på EMAX II

---

## 🎯 SLUTSATS

**Två kritiska problem:**
1. ❌ INIT BANK FAT-struktur är felaktig (FAT[2] = 0x7FFF istället för 0x0003)
2. ❌ HD10 skapas som mirror (trots fixad källkod)

**Orsak:**
- Källkoden är fixad
- Men appen körs med gammal kompilerad kod
- Eller FAT write fungerar inte korrekt

**Åtgärd:**
- Fixa FAT write logik
- Verifiera att HD10 inte skapas som mirror
- Testa om-skapande av filer
- Verifiera mot Funkar HD00 (working reference)

**Mål:**
- HD00.hda med korrekt INIT BANK (5 clusters)
- HD10.hda som blank data disk (inte mirror)
- Båda bootar/fungerar på EMAX II med ZuluSCSI Pico
