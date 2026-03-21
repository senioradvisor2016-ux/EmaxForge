# SD-Minne Diskar - Djup Analys

**Datum:** 2026-03-07  
**Status:** ✅ **KOMPLETT ANALYS**

---

## 📊 REFERENS (_IMAGE_239.EZ2)

**Kritiska värden:**
- Catalog Name: "EMAX2 Software"
- Bank Index: 0x7800
- Field C: 0x0081
- OS Offset: 0x83C00
- OS Signature: `e3fc48fd`
- Status Byte: 0x0F
- Boot Signature: 0x78 0x82

---

## 📋 DISKAR PÅ SD-MINNET

### HD10.hda (Boot Disk på SCSI ID 1)

**Struktur:**
- ✅ Magic: `EMX2`
- ✅ Cluster Size: 489,472 bytes
- ✅ Cluster Area Start: Sector 98 = 0xC400
- ✅ Status Byte: 0x0F (bootable with OS)
- ✅ Bank Count: 90
- ✅ Boot Signature: 0x78 0x82

**Catalog (0x1000):**
- ✅ Name: "EMAX2 Software" (matchar referens)
- ✅ Bank Index: 0x7800 (matchar referens)
- ✅ Start Cluster: 1
- ✅ Field C: 0x0081 (matchar referens) - **FIXAD!**

**OS Data (0x83C00):**
- ✅ OS Offset: 0x83C00 (matchar referens)
- ✅ OS Signature: `e3fc48fd` (matchar referens perfekt!)

**FAT:**
- ✅ FAT[0]: 0x8000 (reserved)
- ✅ FAT[1]: 0x7FFF (OS END marker)

**Innehåll:**
- ✅ OS + 127 banks (128 catalog entries)

**Verifiering:**
- ✅ Magic
- ✅ Status Byte
- ✅ Boot Signature
- ✅ Catalog på 0x1000
- ✅ OS Entry
- ✅ Field C
- ✅ OS Offset
- ✅ OS Signature

**Status:** ✅ **PERFEKT STRUKTURERAD BOOT DISK!**

---

### HD20.hda (Data Disk på SCSI ID 2)

**Struktur:**
- ✅ Magic: `EMX2`
- ✅ Cluster Size: 489,472 bytes
- ✅ Cluster Area Start: Sector 98 = 0xC400
- ✅ Status Byte: 0x0F
- ✅ Bank Count: 90
- ✅ Boot Signature: 0x78 0x82

**Catalog (0x1000):**
- ✅ Name: "EMAX2 Software" (matchar referens)
- ✅ Bank Index: 0x7800 (matchar referens)
- ✅ Start Cluster: 1
- ⚠️  Field C: 0x0080 (saknar active flag) - Referens: 0x0081

**OS Data (0x83C00):**
- ✅ OS Offset: 0x83C00 (matchar referens)
- ⚠️  OS Signature: `00000000` (tomt - korrekt för data disk)

**FAT:**
- ✅ FAT[0]: 0x8000 (reserved)
- ✅ FAT[1]: 0x7FFF (OS END marker)

**Innehåll:**
- ✅ OS + 127 banks (128 catalog entries)

**Verifiering:**
- ✅ Magic
- ✅ Status Byte
- ✅ Boot Signature
- ✅ Catalog på 0x1000
- ✅ OS Entry
- ❌ Field C (0x0080 istället för 0x0081)
- ✅ OS Offset
- ✅ OS Signature (tomt är korrekt för data disk)

**Status:** ⚠️  **DATA DISK - Field C kan uppdateras**

---

## 📊 JÄMFÖRELSE TABELL

| Disk | Field C | OS Signature | Status |
|------|---------|--------------|--------|
| **HD10.hda** | ✅ 0x0081 | ✅ e3fc48fd | ✅ PERFEKT |
| **HD20.hda** | ❌ 0x0080 | ✅ 00000000 (tomt) | ⚠️  Field C kan fixas |
| **Referens** | 0x0081 | e3fc48fd | - |

---

## 🎯 SLUTSATS

### HD10.hda (Boot Disk)
- ✅ **Alla värden matchar referens perfekt!**
- ✅ Field C är fixad (0x0081)
- ✅ OS data matchar referens
- ✅ Redo för boot på EMAX II!

### HD20.hda (Data Disk)
- ✅ Struktur är korrekt
- ⚠️  Field C är 0x0080 (kan uppdateras till 0x0081)
- ✅ OS är tomt (korrekt för data disk)
- ✅ Kan användas för sample banks

---

## 💡 REKOMMENDATIONER

### HD10.hda
- ✅ **Inga ändringar behövs - perfekt!**

### HD20.hda
- 💡 Överväg att uppdatera Field C till 0x0081 (valfritt)
- ✅ Struktur är korrekt för data disk

---

**Status:** ✅ **HD10.HDA ÄR PERFEKT - REDO FÖR BOOT!**

**HD20.hda är korrekt strukturerad som data disk.**
