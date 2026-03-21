# Whiskey/standard tools Problem - Sammanfattning

**Datum:** 2026-03-07  
**Problem:** standard tools kan inte starta i Whiskey  
**Status:** ✅ **PROBLEM IDENTIFIERAT**

---

## 🔍 IDENTIFIERADE PROBLEM

### 1. Saknad DLL-fil ❌
- **msvcr140.dll** saknas
- **Orsak:** Visual C++ 2015 Redistributable är inte installerad
- **Effekt:** standard tools kan inte starta eftersom den behöver denna DLL

### 2. Registry Saknas ⚠️
- **system.reg** saknas i Wine prefix
- **Orsak:** Wine prefix kan vara korrupt eller ofullständig
- **Effekt:** Wine kan inte konfigureras korrekt

### 3. standard tools.exe ✅
- **Status:** Finns och är korrekt storlek (5.5 MB)
- **Plats:** `~/Library/Containers/com.isaacmarovitz.Whisky/Bottles/785BA294-9A93-4E87-9C1B-FB9A251D6B4A/drive_c/standard tools/standardn.exe`

---

## 🔧 FIXAR

### Fix 1: Installera Saknade DLL-filer (Rekommenderat)

**I Whiskey:**
1. Öppna Whiskey
2. Välj din standard tools bottle (785BA294-9A93-4E87-9C1B-FB9A251D6B4A)
3. Klicka på "Run" → "Run Command"
4. Kör: `winetricks vcrun2015`

**Eller installera alla Visual C++ Redistributables:**
```bash
winetricks vcrun2013 vcrun2015 vcrun2017
```

**Detta kommer att:**
- Installera msvcr140.dll
- Installera msvcp140.dll
- Installera vcruntime140.dll
- Installera andra nödvändiga DLL-filer

---

### Fix 2: Skapa Ny Bottle (Om Registry Saknas)

**Om system.reg saknas, skapa ny bottle:**

1. **I Whiskey:**
   - Skapa ny bottle
   - Välj "Windows 10" (rekommenderat)

2. **Installera Visual C++ Redistributables:**
   - Run → Run Command
   - Kör: `winetricks vcrun2013 vcrun2015 vcrun2017`

3. **Kopiera standard tools:**
   ```bash
   mkdir -p ~/Library/Containers/com.isaacmarovitz.Whisky/Bottles/[NY_BOTTLE_ID]/drive_c/standard tools
   cp /Users/senioradvisor/clawd/standard/standardn.exe \
      ~/Library/Containers/com.isaacmarovitz.Whisky/Bottles/[NY_BOTTLE_ID]/drive_c/standard tools/
   ```

4. **Testa starta standard tools:**
   - I Whiskey: Välj bottle → Klicka på "Run" → Välj standardn.exe

---

## 📋 CHECKLIST

- [ ] Installera Visual C++ 2015 Redistributable (winetricks vcrun2015)
- [ ] Verifiera att msvcr140.dll finns i system32
- [ ] Kontrollera att system.reg finns (om inte, skapa ny bottle)
- [ ] Testa starta standard tools i Whiskey

---

## 💡 REKOMMENDATIONER

1. **Installera alla Visual C++ Redistributables** (2013, 2015, 2017) för bäst kompatibilitet
2. **Använd Windows 10** i Wine prefix (bättre kompatibilitet än Windows 7)
3. **Kontrollera Whiskey loggar** om problemet kvarstår

---

## 🎯 SNABB FIX

**Kör diagnostik script:**
```bash
cd /Users/senioradvisor/clawd/EmaxForge
./fix_whiskey_standard.sh
```

**Eller manuellt i Whiskey:**
1. Öppna Whiskey
2. Välj standard tools bottle
3. Run → Run Command
4. Kör: `winetricks vcrun2015`

---

**Status:** ✅ **PROBLEM IDENTIFIERAT - FIX TILLGÄNGLIG**

**Nästa steg:** Installera Visual C++ 2015 Redistributable via winetricks.
