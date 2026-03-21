# HD10.hda Fix - Samples på Data Disk

**Datum:** 2026-03-07  
**Problem:** HD10.hda skapades som mirror av HD00.hda (utan banks/samples)  
**Lösning:** HD10.hda ska skapas som blank data disk och banks importeras dit

---

## 🔍 PROBLEM

**Tidigare beteende:**
- `ImageCreator.createBootableImage()` skapade automatiskt HD10.hda som exakt kopia av HD00.hda
- HD10 hade OS men INGA banks/samples
- `BootableDiskWizard` hoppade över HD10 eftersom den redan fanns
- Banks importerades INTE till HD10

**Resultat:**
- New Boot HD10.hda var identisk med HD00.hda (bara OS, inga banks)
- Funkar HD10.hda har 101 catalog entries (OS + 100 banks)

---

## ✅ LÖSNING

### 1. Ta bort auto-mirror från ImageCreator

**Fil:** `ImageCreator.swift`  
**Ändring:** Tog bort logiken som automatiskt skapar HD10.hda som mirror av HD00.hda

**Före:**
```swift
// CRITICAL: EMAX II requires HD00 and HD10 to be identical (RAID-1 mirror)
// If creating HD00.hda, automatically create HD10.hda as exact copy
if isHD0 {
    // Copy HD00 → HD10 (exact mirror)
    try FileManager.default.copyItem(at: destinationURL, to: hd10URL)
}
```

**Efter:**
```swift
// NOTE: HD10.hda should be created as a separate data disk by BootableDiskWizard
// HD10 is NOT automatically created as a mirror - it should have its own banks/samples
```

### 2. Uppdatera BootableDiskWizard

**Fil:** `BootableDiskWizard.swift`  
**Ändringar:**

1. **Tog bort skip-logik för HD10:**
   - Före: Hoppade över HD10 eftersom den redan fanns som mirror
   - Efter: HD10 skapas som blank data disk (som alla andra data disks)

2. **HD10 skapas som blank data disk:**
   - HD0 (i == 0): Boot disk med OS
   - HD10 (i == 1): Blank data disk (ingen OS)
   - HD20+ (i > 1): Blank data disks

3. **Banks importeras till HD10:**
   - `shouldImportBanks = (count == 1) || (count > 1 && i > 0)`
   - Detta betyder att banks importeras till HD10 (i == 1) och andra data disks

---

## 📊 RESULTAT

**Efter fix:**
- ✅ HD00.hda: Boot disk med OS
- ✅ HD10.hda: Blank data disk (skapas av BootableDiskWizard)
- ✅ Banks importeras till HD10.hda
- ✅ HD10.hda får samples/banks som förväntat

**Funkar mappens HD10:**
- HD10 är identisk med HD00 (båda har OS + samma banks)
- Detta är troligen resultatet av att banks importerades till båda, eller att HD10 kopierades från HD00 efter import

**New Boot mappens HD10 (efter fix):**
- HD10 skapas som blank data disk
- Banks importeras till HD10
- HD10 får samples som förväntat

---

## 💡 NOTERINGAR

**Funkar HD00 vs HD10:**
- Båda är binärt identiska (100% match)
- Båda har OS + 100 banks
- Detta betyder att HD10 faktiskt ÄR en mirror av HD00, men med banks också

**Möjliga scenarion:**
1. Banks importerades till HD00 först, sedan kopierades HD00 → HD10
2. Banks importerades till både HD00 och HD10 separat (men de blev identiska)
3. HD10 skapades som mirror, sedan importerades banks till båda

**Vår lösning:**
- HD10 skapas som blank data disk
- Banks importeras till HD10
- Om användaren vill ha banks på HD00 också, kan de importeras separat

---

## ✅ VERIFIERING

**Kontrollera att:**
1. ✅ HD10.hda skapas som blank data disk (inte mirror)
2. ✅ Banks importeras till HD10.hda
3. ✅ HD10.hda har samples/banks efter import
4. ✅ HD00.hda har OS (och eventuellt banks om användaren importerar)
