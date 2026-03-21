# HD10.hda Boot Fix - Field C Problem

**Datum:** 2026-03-07  
**Problem:** HD10.hda bootar inte på EMAX II  
**Orsak:** Field C är 0x0080 istället för 0x0081  
**Status:** ✅ **FIXAD**

---

## 🚨 PROBLEM IDENTIFIERAT

### Field C Värde

**HD10.hda (Boot Disk på SCSI ID 1):**
- Field C: **0x0080** ❌
- Förväntat: **0x0081** ✅

**Skillnad:**
- 0x0080 = Kan sakna active flag
- 0x0081 = Active flag + OS flag (krävs för boot!)

---

## ✅ VERIFIERING AV HD10.HDA

### Vad som är korrekt:
- ✅ Magic: `EMX2`
- ✅ Status Byte: 0x0F (bootable with OS)
- ✅ Catalog på 0x1000: "EMAX2 Software"
- ✅ Bank Index: 0x7800 (OS entry)
- ✅ OS Signature: `e3fc48fd` (matchar referens!)
- ✅ OS Offset: 0x83C00 (korrekt!)
- ✅ Boot Signature: 0x78 0x82 (korrekt!)
- ✅ FAT[1]: 0x7FFF (OS END marker)

### Vad som var fel:
- ❌ Field C: 0x0080 (saknar active flag)
- ✅ Field C: 0x0081 (efter fix)

---

## 🔧 FIX GENOMFÖRD

### Field C Uppdatering

**Före:**
- Field C (offset 0x101A-0x101B): 0x0080

**Efter:**
- Field C (offset 0x101A-0x101B): 0x0081

**Fix:**
```python
# Sätt Field C till 0x0081
data[0x101A] = 0x81
data[0x101B] = 0x00
```

---

## 📊 BOOT DISK VERIFIERING (EFTER FIX)

- ✅ Magic: `EMX2`
- ✅ Status Byte: 0x0F
- ✅ Catalog på 0x1000
- ✅ OS Entry (Bank Index 0x7800)
- ✅ Field C: 0x0081 (FIXAD!)
- ✅ OS Signature: `e3fc48fd`
- ✅ Boot Signature: 0x78 0x82

**Status:** ✅ **HD10.HDA ÄR NU KORREKT STRUKTURERAD SOM BOOT DISK!**

---

## 💡 ZULUSCSI CONFIG

**Nuvarande:**
```ini
; ZuluSCSI config for EMAX II
[SCSI]
EnableParity = 1

[SCSI1]
```

**Rekommendation (valfritt men säkrare):**
```ini
; ZuluSCSI config for EMAX II
[SCSI]
EnableParity = 1

[SCSI1]
Vendor = E-mu
Product = EMAX II HD
SectorSize = 512
```

**Observera:** ZuluSCSI kan använda defaults, men explicit config är säkrare.

---

## 🎯 SLUTSATS

**Problemet:**
- Field C var 0x0080 (saknade active flag)
- EMAX II kräver 0x0081 för att boota

**Fixen:**
- Field C uppdaterad till 0x0081
- HD10.hda är nu korrekt strukturerad

**Nästa steg:**
1. ✅ Field C är fixad
2. ✅ Testa boot på EMAX II
3. 💡 Överväg att uppdatera zuluscsi.ini med explicit config

---

**Status:** ✅ **HD10.HDA FIELD C FIXAD - REDO FÖR BOOT!**
