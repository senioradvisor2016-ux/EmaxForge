# Detaljerad Jämförelse: New Boot vs Funkar

**Datum:** 2026-03-07  
**Syfte:** Detaljerad analys av skillnader mellan "new boot" och "Funkar" mapparna

---

## 📊 SAMMANFATTNING

**⚠️  FILERNA ÄR INTE IDENTISKA!**

Trots att header-värden matchar, finns det stora skillnader i:
- ❌ FAT tabell (371 skillnader)
- ❌ Catalog (2,078 skillnader)
- ❌ OS Data / Cluster Area (46,871,873 skillnader - 18.7% av filen!)

---

## 📁 FILER

### New Boot Mappen
- `HD00.hda` - 250,398,720 bytes (skapad: 2026-03-07 17:30)
- `HD10.hda` - 250,398,720 bytes (skapad: 2026-03-07 17:30)
- `zuluscsi.ini` - 62 bytes (skapad: 2026-03-07 17:30)

### Funkar Mappen (Reference)
- `HD00.hda` - 250,398,720 bytes (skapad: 2026-02-25 20:17)
- `HD10.hda` - 250,398,720 bytes (skapad: 2026-02-25 20:17)
- `zuluscsi.ini` - 63 bytes (skapad: 2026-02-25 20:17)

---

## ✅ HEADER JÄMFÖRELSE

**Alla header-värden matchar perfekt:**
- ✅ Magic: `EMX2`
- ✅ Cluster Size: 489,472 bytes
- ✅ Cluster Area Start: Sector 98
- ✅ Bank Count: 90
- ✅ Boot Signature: 0x78 0x82
- ✅ Alla field värden matchar

**Header är IDENTISK!** ✅

---

## ❌ FAT TABELL JÄMFÖRELSE

### Skillnader
- **Totala skillnader:** 371 bytes
- **Första skillnaden:** Offset 0x404 (FAT entry 2)

### FAT Entries

| Entry | Funkar | New Boot | Status |
|-------|--------|----------|--------|
| 0 | 0x8000 | 0x8000 | ✅ |
| 1 | 0x7FFF | 0x7FFF | ✅ |
| 2 | 0x0003 | 0x7FFF | ❌ |
| 3 | 0x0004 | 0x0000 | ❌ |
| 4 | 0x0005 | 0x0000 | ❌ |
| 5 | 0x0006 | 0x0000 | ❌ |
| 6 | 0x7FFF | 0x0000 | ❌ |
| 7 | 0x0008 | 0x0000 | ❌ |
| 8 | 0x0009 | 0x0000 | ❌ |
| 9 | 0x7FFF | 0x0000 | ❌ |

**Problem:**
- Funkar har FAT entries för flera clusters (2, 3, 4, 5, 6, 8, 9)
- New Boot har mestadels nollor (0x0000) eller 0x7FFF i entry 2

**Detta indikerar att Funkar har fler banks/data skrivna, medan New Boot är mestadels tom.**

---

## ❌ CATALOG JÄMFÖRELSE

### Skillnader
- **Totala skillnader:** 2,078 bytes
- **Catalog Entry 0 (OS):** Matchar ✅
- **Övriga catalog entries:** Har skillnader ❌

**Problem:**
- Funkar har fler catalog entries (banks) skrivna
- New Boot har mestadels nollor i catalog entries efter entry 0

---

## ❌ OS DATA / CLUSTER AREA JÄMFÖRELSE

### Skillnader
- **Totala skillnader:** 46,871,873 bytes (18.7% av filen!)
- **Första skillnaden:** Offset 0xC401 (cluster area start + 1 byte)

### OS Data Analys

**Funkar:**
- Non-zero bytes: ~244,400 bytes (faktisk OS data)
- Nollor: ~245,072 bytes (padding)

**New Boot:**
- Non-zero bytes: ~0 bytes (ingen OS data!)
- Nollor: ~489,472 bytes (hela cluster 1 är tomt)

**KRITISKT PROBLEM:**
- ❌ **New Boot HD00.hda har INTE OS data skrivet!**
- ❌ OS data området (cluster 1) är helt tomt (alla nollor)
- ❌ Funkar har faktisk OS data skrivet

---

## ⚠️  ZULUSCSI.INI JÄMFÖRELSE

### Skillnad
- **Funkar:** 63 bytes (har trailing newline)
- **New Boot:** 62 bytes (saknar trailing newline)
- **Innehåll:** Funktionellt identiskt ✅

**Detta är en minimal skillnad och påverkar inte funktionaliteten.**

---

## 🎯 SLUTSATS

### ❌ New Boot HD00.hda är INTE identisk med Funkar!

**Kritiska problem:**

1. **❌ OS Data saknas:**
   - New Boot har INTE OS data skrivet i cluster 1
   - Funkar har faktisk OS data (~244 KB)
   - **Detta kommer att förhindra boot!**

2. **❌ FAT Tabell är ofullständig:**
   - New Boot har mestadels nollor i FAT entries
   - Funkar har korrekta FAT entries för flera clusters
   - **Detta indikerar att banks/data saknas**

3. **❌ Catalog är ofullständig:**
   - New Boot har mestadels nollor i catalog entries
   - Funkar har flera catalog entries (banks)
   - **Detta indikerar att banks saknas**

### ✅ Vad som matchar:

- ✅ Header (alla värden)
- ✅ Bank Status Table
- ✅ Catalog Entry 0 (OS entry - men OS data saknas!)
- ✅ zuluscsi.ini (funktionellt identiskt)

---

## 💡 REKOMMENDATION

**New Boot mappens HD00.hda kommer INTE att boota på EMAX II!**

**Orsak:** OS data saknas helt i cluster 1.

**Lösning:**
1. Kontrollera varför OS data inte skrevs när "new boot" filerna skapades
2. Verifiera att `ImageCreator.createBootableImage()` faktiskt skriver OS data
3. Kontrollera att OS-filen (`FUNKAR.EMX` eller `WORKING.EMX`) finns och kan läsas
4. Skapa om disk images med korrekt OS data

**Funkar mappens filer är korrekta och bootar perfekt - använd dem som reference!**
