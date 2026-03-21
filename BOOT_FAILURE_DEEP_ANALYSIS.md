# Boot Failure - Djup Analys

**Datum:** 2026-03-07  
**Problem:** SD-minnet bootar inte EMAX 2  
**Status:** 🔍 **ANALYSERAR**

---

## 🔍 KRITISKA KONTROLLER

### 1. Filnamn och SCSI ID
- ✅ Filnamn: HD10.hda
- ✅ SCSI ID: 1 (från filnamn)
- ✅ EMAX II boot disk är på SCSI ID 1

### 2. zuluscsi.ini
- ✅ [SCSI1] finns i config
- ✅ EnableParity = 1

### 3. Disk Struktur
- ✅ Magic: EMX2
- ✅ Status Byte: 0x0F
- ✅ Boot Signature: 0x78 0x82
- ✅ Catalog på 0x1000
- ✅ OS Entry (Bank Index 0x7800)
- ✅ Field C: 0x0081
- ✅ OS Signature: e3fc48fd

---

## 🔍 MÖJLIGA ORSAKER

### 1. Byte-för-byte Skillnader
- Jämför med referens (_IMAGE_239.EZ2)
- Jämför med fungerande Funkar HD00.hda

### 2. FAT Integritet
- Kolla om alla FAT entries är giltiga
- Kolla om FAT[1] = 0x7FFF

### 3. Catalog Integritet
- Kolla om första entry är OS
- Kolla om alla entries är korrekta

### 4. OS Data Integritet
- Kolla om OS data är komplett
- Kolla om data efter OS är korrekt

---

## 📋 NÄSTA STEG

1. ✅ Jämför byte-för-byte med referens
2. ✅ Jämför med fungerande Funkar disk
3. ✅ Kolla FAT integritet
4. ✅ Kolla catalog integritet
5. ✅ Kolla OS data integritet

---

**Status:** 🔍 **ANALYSERAR DOLDA PROBLEM**
