# Whiskey/standard tools Start Problem - Fix

**Datum:** 2026-03-07  
**Problem:** standard tools kan inte starta i Whiskey  
**Status:** 🔍 **DIAGNOSTISERAR**

---

## 🔍 IDENTIFIERADE PROBLEM

### standard tools Körs Men Startar Inte

**Status:**
- ✅ Whiskey körs
- ✅ standard tools process finns (standardn.exe)
- ⚠️  Men standard tools startar inte korrekt

**Möjliga orsaker:**
1. Saknade DLL-filer
2. Wine prefix problem
3. Windows version mismatch
4. standard tools.exe är korrupt eller fel plats

---

## 🔧 FIXAR

### 1. Installera Saknade DLL-filer

**Vanliga DLL-filer som standard tools behöver:**
- msvcr120.dll
- msvcp120.dll
- msvcr140.dll
- msvcp140.dll
- vcruntime140.dll

**Fix via winetricks:**
```bash
# I Whiskey bottle terminal
winetricks vcrun2013
winetricks vcrun2015
winetricks vcrun2017
```

**Eller manuellt:**
1. Öppna Whiskey
2. Välj din standard tools bottle
3. Klicka på "Run" → "Run Command"
4. Kör: `winetricks vcrun2013 vcrun2015 vcrun2017`

---

### 2. Kontrollera standard tools.exe Plats

**standard tools bör finnas i:**
```
~/Library/Containers/com.isaacmarovitz.Whisky/Bottles/[BOTTLE_ID]/drive_c/standard tools/standardn.exe
```

**Om den saknas:**
```bash
# Kopiera från källan
cp /Users/senioradvisor/clawd/standard/standardn.exe \
   ~/Library/Containers/com.isaacmarovitz.Whisky/Bottles/[BOTTLE_ID]/drive_c/standard tools/
```

---

### 3. Konfigurera Windows Version

**Sätt Windows 10 (rekommenderat):**
1. Öppna Whiskey
2. Välj din standard tools bottle
3. Klicka på "Run" → "Run Command"
4. Kör: `winecfg`
5. Välj "Windows 10" i "Windows Version" tab

---

### 4. Skapa Ny Bottle (Om Nuvarande Är Korrupt)

**I Whiskey:**
1. Skapa ny bottle
2. Välj Windows 10
3. Installera Visual C++ Redistributable:
   - winetricks vcrun2013
   - winetricks vcrun2015
   - winetricks vcrun2017
4. Kopiera standardn.exe till drive_c/standard tools/
5. Testa starta standard tools

---

## 📋 CHECKLIST

- [ ] standard tools.exe finns i bottle
- [ ] Visual C++ DLL-filer är installerade
- [ ] Windows version är Windows 10
- [ ] Wine prefix är inte korrupt
- [ ] Kolla Whiskey loggar för felmeddelanden

---

## 💡 REKOMMENDATIONER

1. **Använd Windows 10** i Wine prefix
2. **Installera alla Visual C++ Redistributables** (2013, 2015, 2017)
3. **Kontrollera Whiskey loggar** för specifika felmeddelanden
4. **Testa med enkel Windows-app** först för att verifiera Whiskey fungerar

---

**Status:** 🔍 **DIAGNOSTISERAR PROBLEM**

**Nästa steg:** Identifiera exakt felmeddelande från Whiskey loggar.
