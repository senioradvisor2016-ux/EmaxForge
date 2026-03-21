# SD-Minne Analys - Komplett Rapport

**Datum:** 2026-03-07  
**Status:** ✅ **ANALYS KLAR**

---

## 📊 SAMMANFATTNING

### Analyserade Filer

| Fil | Catalog | OS Offset | OS Match | Status |
|-----|---------|-----------|----------|--------|
| **SD_BOOT2/Funkar/HD00.hda** | ✅ 0x1000 | 0x83C00 | ❌ | Catalog OK, OS fel |
| **new boot/HD00.hda** | ✅ 0x1000 | 0x83C00 | ❌ | Catalog OK, OS fel |
| **_IMAGE_239.EZ2** (Referens) | ✅ 0x1000 | 0x83C00 | ✅ | Allt korrekt |

---

## ✅ POSITIVA FYND

### 1. Catalog Offset ✅
**Status:** **KORREKT!**

- **SD_BOOT2/Funkar/HD00.hda:**
  - Catalog på 0x1000: "EMAX2 Software"
  - Bank Index: 0x7800
  - Field C: 0x0081
  - ✅ **Korrekt plats!**

- **new boot/HD00.hda:**
  - Catalog på 0x1000: "EMAX2 Software"
  - Bank Index: 0x7800
  - Field C: 0x0081
  - ✅ **Korrekt plats!**

**Slutsats:** Catalog är på korrekt plats (0x1000) i båda filerna!

---

### 2. OS Offset ✅
**Status:** **KORREKT!**

- **SD_BOOT2/Funkar/HD00.hda:**
  - OS Offset: 0x83C00 (korrekt!)
  - Cluster Area Start: Sector 98 = 0xC400
  - Cluster Size: 489,472 bytes
  - Beräkning: 0xC400 + 489,472 = 0x83C00 ✅

- **new boot/HD00.hda:**
  - OS Offset: 0x83C00 (korrekt!)
  - ✅ **Korrekt offset!**

**Slutsats:** OS är på korrekt offset (0x83C00) i båda filerna!

---

## ❌ PROBLEM IDENTIFIERADE

### 1. OS Data Matchar INTE Referens ❌
**Status:** **KRITISKT PROBLEM!**

**Referens (_IMAGE_239.EZ2):**
- OS Signature: `e3fc48fd`
- OS Data: `e3fc48fd22fdcefcfafbc0fae1f962f9...`

**SD_BOOT2/Funkar/HD00.hda:**
- OS Signature: `b7ce59ce`
- OS Data: `b7ce59ce3ace31ce6bcef7ce73cf09d0...`
- ❌ **Matchar INTE referens!**

**new boot/HD00.hda:**
- OS Signature: `b7ce59ce`
- OS Data: `b7ce59ce3ace31ce6bcef7ce73cf09d0...`
- ❌ **Matchar INTE referens!**

**Problemet:**
- OS data är på korrekt offset (0x83C00) ✅
- Men OS innehållet matchar INTE referens ❌
- Detta kan förklara varför diskarna inte bootar korrekt!

**Möjliga orsaker:**
1. OS-filen (`emax2_os.bin`) är fel version
2. OS-filen är korrupt
3. OS-filen är från en annan EMAX II modell/version

---

## 📋 DETALJERAD ANALYS

### SD_BOOT2/Funkar/HD00.hda

**Header:**
- Magic: `EMX2` ✅
- Cluster Size: 489,472 bytes ✅
- Cluster Area Start: Sector 98 = 0xC400 ✅
- Status Byte: 0x0F (bootable with OS) ✅

**Catalog (0x1000):**
- Name: "EMAX2 Software" ✅
- Bank Index: 0x7800 (30720) ✅
- Start Cluster: 1 ✅
- Field C: 0x0081 ✅
- ✅ **Korrekt plats och format!**

**OS Data (0x83C00):**
- Offset: 0x83C00 ✅
- Signature: `b7ce59ce` ❌ (förväntat: `e3fc48fd`)
- ❌ **OS data matchar INTE referens!**

**FAT:**
- FAT[0]: 0x8000 (reserved) ✅
- FAT[1]: 0x7FFF (OS END marker) ✅
- FAT[2]: 0x0003 (first bank chain) ✅

---

### new boot/HD00.hda

**Header:**
- Magic: `EMX2` ✅
- Cluster Size: 489,472 bytes ✅
- Cluster Area Start: Sector 98 = 0xC400 ✅
- Status Byte: 0x0F (bootable with OS) ✅

**Catalog (0x1000):**
- Name: "EMAX2 Software" ✅
- Bank Index: 0x7800 (30720) ✅
- Start Cluster: 1 ✅
- Field C: 0x0081 ✅
- ✅ **Korrekt plats och format!**

**OS Data (0x83C00):**
- Offset: 0x83C00 ✅
- Signature: `b7ce59ce` ❌ (förväntat: `e3fc48fd`)
- ❌ **OS data matchar INTE referens!**

**FAT:**
- FAT[0]: 0x8000 (reserved) ✅
- FAT[1]: 0x7FFF (OS END marker) ✅
- FAT[2]: 0x0003 (first bank chain) ✅

---

## 💡 SLUTSATS

### ✅ Vad som är korrekt:
1. **Catalog Offset:** 0x1000 (fast offset) ✅
2. **OS Offset:** 0x83C00 (clusterAreaStart + clusterSize) ✅
3. **Catalog Format:** Korrekt (Bank Index 0x7800, Field C 0x0081) ✅
4. **FAT Structure:** Korrekt (FAT[1] = 0x7FFF) ✅
5. **Header Values:** Korrekt (Status byte 0x0F) ✅

### ❌ Vad som är fel:
1. **OS Data:** Matchar INTE referens ❌
   - Referens: `e3fc48fd...`
   - SD filer: `b7ce59ce...`
   - Detta kan förklara varför diskarna inte bootar korrekt!

---

## 🔧 REKOMMENDATIONER

### 1. Verifiera OS-filen
**Kontrollera:** `EmaxForge/Resources/emax2_os.bin`

```bash
# Extrahera OS från referens
dd if=_IMAGE_239.EZ2 of=emax2_os_correct.bin bs=1 skip=$((0x83C00)) count=489472

# Jämför med nuvarande OS-fil
diff emax2_os.bin emax2_os_correct.bin
```

### 2. Uppdatera OS-filen
Om OS-filen är fel:
1. Extrahera korrekt OS från `_IMAGE_239.EZ2`
2. Ersätt `EmaxForge/Resources/emax2_os.bin`
3. Bygg om appen
4. Skapa nya boot disks

### 3. Testa Nya Boot Disks
Efter OS-fil uppdatering:
1. Skapa nya boot disks med fixad app
2. Verifiera att OS signature matchar referens (`e3fc48fd`)
3. Testa boot på riktig EMAX II hardware

---

## 📊 JÄMFÖRELSE TABELL

| Komponent | Referens | SD_BOOT2/Funkar | new boot | Status |
|-----------|----------|-----------------|----------|--------|
| **Catalog Offset** | 0x1000 | 0x1000 | 0x1000 | ✅ |
| **Catalog Name** | "EMAX2 Software" | "EMAX2 Software" | "EMAX2 Software" | ✅ |
| **Catalog Bank Index** | 0x7800 | 0x7800 | 0x7800 | ✅ |
| **Catalog Field C** | 0x0081 | 0x0081 | 0x0081 | ✅ |
| **OS Offset** | 0x83C00 | 0x83C00 | 0x83C00 | ✅ |
| **OS Signature** | e3fc48fd | b7ce59ce | b7ce59ce | ❌ |

---

**Status:** ✅ **Catalog är korrekt, men OS data matchar INTE referens!**

**Nästa steg:** Verifiera och uppdatera OS-filen (`emax2_os.bin`) för att matcha referens.
