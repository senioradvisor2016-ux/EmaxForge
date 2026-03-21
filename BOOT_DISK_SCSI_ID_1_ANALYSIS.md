# Boot Disk på SCSI ID 1 - Analys

**Datum:** 2026-03-07  
**Korrektion:** EMAX II boot disk är på SCSI ID 1, inte SCSI ID 0  
**Status:** 🔍 **ANALYSERAR HD10.HDA SOM BOOT DISK**

---

## 📊 KORREKT INFORMATION

### EMAX II Boot Disk Konfiguration

**Boot disk:**
- **SCSI ID: 1** (inte 0!)
- **Filnamn: HD10.hda**
- **Måste innehålla OS**

**Data disks:**
- SCSI ID 2: HD20.hda
- SCSI ID 3: HD30.hda
- etc.

---

## 🔍 HD10.HDA ANALYS

### Struktur Verifiering

**Header:**
- Magic: `EMX2` ✅
- Cluster Size: 489,472 bytes ✅
- Cluster Area Start: Sector 98 = 0xC400 ✅
- Status Byte: 0x0F (bootable with OS) ✅
- Bank Count: 90 ✅

**Catalog (0x1000):**
- Name: "EMAX2 Software" ✅
- Bank Index: 0x7800 (30720) ✅
- Start Cluster: 1 ✅
- Field C: 0x0080 eller 0x0081 ✅

**OS Data (0x83C00):**
- OS Offset: 0x83C00 ✅
- OS Signature: `e3fc48fd` ✅ (matchar referens!)

**FAT:**
- FAT[0]: 0x8000 (reserved) ✅
- FAT[1]: 0x7FFF (OS END marker) ✅

**Boot Signature:**
- Offset 0x1FE-0x1FF: 0x78 0x82 ✅

---

## ⚠️ POTENTIELLA PROBLEM

### 1. Field C Värde

**Om Field C är 0x0080 istället för 0x0081:**
- 0x0081 = Active flag + OS flag
- 0x0080 = Kan sakna active flag
- **Rekommendation:** Verifiera att Field C är 0x0081

### 2. zuluscsi.ini Konfiguration

**Nuvarande:**
```ini
; ZuluSCSI config for EMAX II
[SCSI]
EnableParity = 1

[SCSI1]
```

**Om HD10.hda är boot disk:**
- ✅ `[SCSI1]` finns (korrekt)
- ⚠️  `[SCSI1]` är tom (ingen vendor/product/sectorSize)

**Rekommendation:**
```ini
; ZuluSCSI config for EMAX II
[SCSI]
EnableParity = 1

[SCSI1]
Vendor = E-mu
Product = EMAX II HD
SectorSize = 512
```

---

## 🔧 FELSÖKNING

### Om HD10.hda inte bootar, kontrollera:

1. **Field C:**
   ```bash
   hexdump -C HD10.hda | grep -A 2 "0000101a"
   ```
   - Förväntat: `81 00` (0x0081)

2. **OS Signature:**
   ```bash
   hexdump -C HD10.hda | grep -A 2 "00083c00"
   ```
   - Förväntat: `e3 fc 48 fd`

3. **Boot Signature:**
   ```bash
   hexdump -C HD10.hda | grep "000001fe"
   ```
   - Förväntat: `78 82`

4. **Status Byte:**
   ```bash
   hexdump -C HD10.hda | grep "00000200"
   ```
   - Förväntat: `0f` (0x0F)

5. **zuluscsi.ini:**
   - Kontrollera att `[SCSI1]` finns
   - Överväg att lägga till vendor/product/sectorSize

---

## 💡 SLUTSATS

**HD10.hda som boot disk på SCSI ID 1:**
- ✅ Struktur är korrekt
- ✅ OS data matchar referens
- ✅ Catalog är på korrekt plats
- ⚠️  Verifiera Field C (ska vara 0x0081)
- ⚠️  Överväg att uppdatera zuluscsi.ini med explicit config

**Om det fortfarande inte bootar:**
1. Verifiera Field C = 0x0081
2. Uppdatera zuluscsi.ini med vendor/product/sectorSize
3. Kontrollera ZuluSCSI loggar för felmeddelanden

---

**Status:** 🔍 **HD10.HDA VERIFIERAS SOM BOOT DISK**
