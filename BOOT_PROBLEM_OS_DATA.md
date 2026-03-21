# Boot Problem: OS Data Matchar Inte Referens

**Datum:** 2026-03-07  
**Problem:** SD-minnet bootar inte med banker  
**Orsak:** OS-data matchar inte referens (_IMAGE_239.EZ2)

---

## 🔍 PROBLEM IDENTIFIERAT

### OS Data Avvikelse

**Referens (_IMAGE_239.EZ2):**
- OS Data offset: 0x83C00
- Första 32 bytes: `e3fc48fd22fdcefcfafbc0fae1f962f963f97bf9d6f91efa4dfab1fa2efb30fb`

**SD-minnes filer (Funkar HD00 & new boot HD00):**
- OS Data offset: 0x83C00 ✅ (korrekt)
- Första 32 bytes: `b7ce59ce3ace31ce6bcef7ce73cf09d091d04ed160d28ad3cdd40ed6a6d751d9` ❌
- **Första skillnad vid offset 0: 0xB7 vs 0xE3**

---

## 📊 ANALYS

### Alla Andra Värden Matchar

✅ **Header värden:**
- Magic: `EMX2` ✅
- Cluster Size: 489,472 bytes ✅
- Cluster Area Start: Sector 98 ✅
- Bank Count: 90 ✅
- Boot Signatures: 0x00, 0x00 ✅

✅ **Bank Status Table:**
- Entry 0: 0x0F ✅
- Entry 1-3: 0x00 ✅
- Entry 4-9: 0x80 ✅

✅ **Catalog Entry 0 (OS):**
- Name: "EMAX2 Software.." ✅
- Bank Index: 0x7800 ✅
- Start Cluster: 1 ✅
- Field C: 0x0081 ✅

✅ **FAT Entry 1 (OS):**
- Value: 0x7FFF ✅

❌ **OS Data:**
- Matchar INTE referens ❌

---

## 💡 SLUTSATS

**Problemet:** OS-filen (`emax2_os.bin`) som används av EmaxForge är **fel version** eller **korrupt**.

**Bekräftat:**
- Alla strukturella värden matchar referens ✅
- Enda avvikelsen är OS-data ❌
- OS-data är kritiskt för boot-processen

**Rekommendation:**
1. Extrahera korrekt OS från `_IMAGE_239.EZ2`
2. Ersätt `emax2_os.bin` i Resources/
3. Verifiera att OS-data matchar referens

---

## 🔧 LÖSNING

### Steg 1: Extrahera OS från Referens

```python
import struct

# Läs _IMAGE_239.EZ2
with open("_IMAGE_239.EZ2", "rb") as f:
    data = f.read()

# Extrahera OS data
cluster_area_start = struct.unpack('<I', data[32:36])[0]  # 98
cluster_size = struct.unpack('<I', data[4:8])[0]  # 489472
os_cluster_offset = (cluster_area_start * 512) + (1 * cluster_size)  # 0x83C00

os_data = data[os_cluster_offset:os_cluster_offset+cluster_size]

# Spara som emax2_os.bin
with open("emax2_os.bin", "wb") as f:
    f.write(os_data)
```

### Steg 2: Ersätt OS-fil

1. Kopiera extraherad `emax2_os.bin` till `EmaxForge/Resources/`
2. Verifiera att första 32 bytes matchar: `e3fc48fd22fdcefcfafbc0fae1f962f963f97bf9d6f91efa4dfab1fa2efb30fb`
3. Kompilera om appen

### Steg 3: Verifiera

Efter fix, verifiera att skapade images har korrekt OS-data:
- Första 32 bytes ska vara: `e3fc48fd22fdcefcfafbc0fae1f962f963f97bf9d6f91efa4dfab1fa2efb30fb`

---

## 📋 REFERENS

**Working Reference:** `_IMAGE_239.EZ2`
- ✅ Bootar perfekt på EMAX II
- ✅ OS-data: `e3fc48fd22fdcefcfafbc0fae1f962f9...`

**Problem File:** `emax2_os.bin` (nuvarande)
- ❌ OS-data: `b7ce59ce3ace31ce6bcef7ce73cf09d0...`
- ❌ Matchar INTE referens

**Slutsats:** OS-filen är fel version och måste ersättas med korrekt OS från referens.
