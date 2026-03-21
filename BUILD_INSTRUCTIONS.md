# Bygginstruktioner - EmaxForge med Catalog Offset Fix

**Datum:** 2026-03-07  
**Status:** ✅ **Alla kritiska fixes inkluderade**

---

## 🚀 BYGG I XCODE (Rekommenderat)

### Steg 1: Öppna projektet
```bash
cd /Users/senioradvisor/clawd/EmaxForge
open EmaxForge.xcodeproj
```

### Steg 2: Välj scheme och destination
- **Scheme:** `EmaxForge`
- **Destination:** `My Mac` (eller din Mac)

### Steg 3: Bygg appen
- Tryck **Cmd+B** (Build)
- Eller: **Product** → **Build**

### Steg 4: Kör appen
- Tryck **Cmd+R** (Run)
- Eller: **Product** → **Run**

---

## ✅ KRITISKA FIXES INKLUDERADE

### 1. Catalog Offset Fix ✅
**Fil:** `EmaxForge/Sources/Services/ImageCreator.swift`
- Catalog skrivs nu på **0x1000** (fast offset)
- Tidigare: Catalog skrevs på cluster area start (0xC400) ❌

### 2. OS Offset Fix ✅
**Fil:** `EmaxForge/Sources/Services/ImageCreator.swift`
- OS skrivs på **clusterAreaStart + clusterSize**
- Korrekt offset: 0x83C00 för 239MB disk

### 3. Cluster Offset Fix ✅
**Fil:** `EmaxForge/Sources/Services/BankImporter.swift`
- Cluster offset: `clusterAreaStart + cluster * clusterSize`

### 4. Catalog Entry Fix ✅
**Fil:** `EmaxForge/Sources/Services/BankImporter.swift`
- Catalog entries skrivs på 0x1000
- Bank index: (catalogCount - 1) * 256
- Field C: 0x0081

---

## 📊 VERIFIERING EFTER BUILD

### Testa Boot Disk Creation

1. **Skapa ny boot disk:**
   - Öppna appen
   - Välj "Create Bootable Disk"
   - Välj 239MB
   - Inkludera OS
   - Skapa disk

2. **Verifiera catalog offset:**
   ```bash
   # Använd hexdump eller Python script
   hexdump -C HD00.hda | grep -A 16 "00001000"
   ```
   - Förväntat: "EMAX2 Software" på offset 0x1000

3. **Verifiera OS offset:**
   ```bash
   hexdump -C HD00.hda | grep -A 16 "00083c00"
   ```
   - Förväntat: OS data börjar på 0x83C00

---

## 🎯 FÖRVÄNTADE RESULTAT

### Efter build med fixes:
- ✅ Catalog är på 0x1000
- ✅ OS är på 0x83C00 (för 239MB)
- ✅ Boot disk bootar på EMAX II
- ✅ Banker kan importeras korrekt

---

## 🐛 OM BUILD MISSLYCKAS

### Problem: "No such module"
**Lösning:** 
```bash
cd /Users/senioradvisor/clawd/EmaxForge
swift package resolve
```

### Problem: SDK/toolchain mismatch
**Lösning:** Använd Xcode (inte command line tools)

### Problem: "Operation not permitted"
**Lösning:** 
```bash
sudo chmod -R 755 ~/.cache/clang
```

---

## 📋 NÄSTA STEG EFTER BUILD

1. ✅ Testa boot disk creation
2. ✅ Verifiera catalog på 0x1000
3. ✅ Verifiera OS på 0x83C00
4. ✅ Testa boot på riktig EMAX II hardware

---

**Status:** ✅ **APPEN ÄR REDO FÖR BUILD MED ALLA FIXES!**
