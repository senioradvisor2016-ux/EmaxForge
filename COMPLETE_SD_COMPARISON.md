# Komplett Jämförelse: Fixad Kod vs SD-Minnet

**Datum:** 2026-03-07  
**Syfte:** Verifiera att fixen i ImageCreator.swift matchar SD-minnes filer och referens

---

## 📊 REFERENS: _IMAGE_239.EZ2

**OS Offset Beräkning:**
- Cluster Area Start: Sector 98 = 50,176 bytes (0xC400)
- Cluster Size: 489,472 bytes
- **OS Offset:** `0xC400 + 489,472 = 0x83C00` (539,648 bytes) ✅

**OS Data:**
- Första 32 bytes: `e3fc48fd22fdcefcfafbc0fae1f962f963f97bf9d6f91efa4dfab1fa2efb30fb`

---

## 📝 FIXAD KOD (ImageCreator.swift)

**Beräkning:**
```swift
catalogOffset = clusterAreaStartSector * 512
osOffset = catalogOffset + clusterSize
```

**För 239 MB:**
- `catalogOffset = 98 * 512 = 0xC400`
- `osOffset = 0xC400 + 489,472 = 0x83C00` ✅

**Status:** ✅ **Matchar referens perfekt!**

---

## 📁 SD-MINNES FILER

### 1. Funkar HD00.hda

**OS Offset:**
- Korrekt: 0x83C00 ✅ (matchar fixad kod)
- Fel (gammal bugg): 0xD720 ❌

**OS Data:**
- På korrekt offset (0x83C00): `b7ce59ce3ace31ce6bcef7ce73cf09d0...` ❌
- På fel offset (0xD720): `110014b8eabe821c086abe5ad40e8414...` (OS-fil matchar)

**Problem:**
- ❌ OS offset är korrekt, men OS data matchar INTE referens!
- ❌ OS finns på fel plats (0xD720) istället för korrekt plats (0x83C00)
- **Detta betyder:** Image skapades med gammal buggig kod som skrev OS på fel offset

**Slutsats:** ❌ **Behöver skapas om med fixad kod!**

---

### 2. new boot HD00.hda

**OS Offset:**
- Korrekt: 0x83C00 ✅ (matchar fixad kod)
- Fel (gammal bugg): 0xD720 ❌

**OS Data:**
- På korrekt offset (0x83C00): `b7ce59ce3ace31ce6bcef7ce73cf09d0...` ❌
- På fel offset (0xD720): `00000000000000000000000000000000...` (tomt!)

**Problem:**
- ❌ OS saknas helt!
- ❌ Data på korrekt offset matchar INTE referens
- **Detta betyder:** Image skapades innan OS-filen laddades korrekt eller med gammal buggig kod

**Slutsats:** ❌ **Behöver skapas om med fixad kod!**

---

## 🔍 OS-FIL JÄMFÖRELSE

### Referens OS (från _IMAGE_239.EZ2)
- Offset: 0x83C00
- Size: 489,472 bytes
- Första 64 bytes: `e3fc48fd22fdcefcfafbc0fae1f962f963f97bf9d6f91efa4dfab1fa2efb30fbaefa9bfa5afb93fcdefdfffe0c00ab00d500dd009d00e9ff92feb9fce4fa97f9`

### Bundled OS-fil (emax2_os.bin)
- Size: 489,472 bytes
- Första 64 bytes: `110014b8eabe821c086abe5ad40e8414e7de088405eabe171c086abe499cb003000a0ceec0de83f683fb8abe5cce0fd883f0827defd80487ffaaff1e011a0000`

**Jämförelse:**
- ❌ **OS-fil matchar INTE referens OS data!**
- Första skillnad vid offset 0: Referens=0xE3, OS-fil=0x11
- **Detta betyder:** OS-filen är fel version eller korrupt!

---

## 💡 SLUTSATS

### Problem Identifierat

1. **Fixad kod:** ✅ Korrekt beräkning (matchar referens)
2. **SD-minnes filer:** ❌ Skapade med gammal buggig kod
3. **OS-fil:** ❌ Fel version eller korrupt

### Root Causes

1. **OS Offset Bugg (FIXAD):**
   - Gammal kod: `osOffset = catalogOffset + catalogSize` ❌
   - Fixad kod: `osOffset = catalogOffset + clusterSize` ✅

2. **OS-fil Problem (INTE FIXAD):**
   - Bundled OS-fil matchar INTE referens OS data
   - OS-filen är troligen fel version eller korrupt
   - **LÖSNING:** Extrahera OS från _IMAGE_239.EZ2 och ersätt emax2_os.bin

### Rekommendationer

1. ✅ **Fixad kod är korrekt** - OS offset beräkning matchar referens
2. ❌ **OS-fil behöver fixas** - Extrahera korrekt OS från referens
3. ❌ **SD-minnes filer behöver skapas om** - Efter OS-fil fix

---

## 🔧 NÄSTA STEG

### Steg 1: Fixa OS-fil

Extrahera OS från referens:
```python
import struct

with open("_IMAGE_239.EZ2", "rb") as f:
    data = f.read()

cluster_area_start = struct.unpack('<I', data[32:36])[0]  # 98
cluster_size = struct.unpack('<I', data[4:8])[0]  # 489472
os_offset = (cluster_area_start * 512) + cluster_size  # 0x83C00

os_data = data[os_offset:os_offset+cluster_size]

with open("emax2_os.bin", "wb") as f:
    f.write(os_data)
```

### Steg 2: Ersätt OS-fil

Kopiera extraherad `emax2_os.bin` till `EmaxForge/Resources/`

### Steg 3: Kompilera om Appen

Kompilera om appen med fixad kod och korrekt OS-fil

### Steg 4: Skapa Nya Boot Disks

Skapa nya boot disks med fixad kod och korrekt OS-fil

### Steg 5: Verifiera

Verifiera att:
- OS offset = 0x83C00 ✅
- OS data första 32 bytes = `e3fc48fd22fdcefcfafbc0fae1f962f9...` ✅
- Image bootar på EMAX II ✅

---

## 📋 STATUS

- ✅ **OS Offset Bugg:** FIXAD i ImageCreator.swift
- ❌ **OS-fil:** Behöver fixas (extrahera från referens)
- ❌ **SD-minnes filer:** Behöver skapas om (efter OS-fil fix)

**Nästa:** Fixa OS-fil och skapa nya boot disks!
