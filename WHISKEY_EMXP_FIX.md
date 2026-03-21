# Whiskey/standard tools Problem - Diagnostik och Fix

**Datum:** 2026-03-07  
**Problem:** standard tools kan inte starta i Whiskey  
**Status:** 🔍 **DIAGNOSTISERAR**

---

## 🔍 VANLIGA ORSAKER

### 1. Whiskey inte installerat
- Whiskey måste vara installerat för att köra Windows-appar
- **Fix:** Installera Whiskey från GitHub

### 2. standard tools.exe hittas inte
- Whiskey kan inte hitta standard tools.exe
- **Fix:** Kontrollera sökväg till standard tools.exe

### 3. Wine Prefix Problem
- Whiskey använder Wine prefix som kan vara korrupt
- **Fix:** Skapa ny Wine prefix

### 4. DLL Saknas
- standard tools kan sakna Windows DLL-filer
- **Fix:** Installera saknade DLL-filer

### 5. Kompatibilitetsproblem
- standard tools kan kräva specifik Windows-version
- **Fix:** Konfigurera Wine prefix för rätt Windows-version

---

## 🔧 FIXAR

### 1. Installera Whiskey

**Om Whiskey inte är installerat:**
1. Ladda ner från: https://getwhiskey.app/
2. Installera Whiskey.app
3. Öppna Whiskey

---

### 2. Skapa Ny Bottle (Wine Prefix)

**I Whiskey:**
1. Klicka på "+" för att skapa ny bottle
2. Välj Windows-version (Windows 10 rekommenderas)
3. Ge bottle ett namn (t.ex. "standard tools")

---

### 3. Installera standard tools i Bottle

**Metod 1: Via Whiskey UI**
1. Öppna Whiskey
2. Välj din standard tools bottle
3. Klicka på "Run" eller "Install"
4. Välj standard.exe eller installer

**Metod 2: Via Terminal**
```bash
# Hitta Whiskey bottle path
cd ~/Library/Application\ Support/Whiskey/Bottles/

# Kör standard tools via Wine
wine /path/to/standard.exe
```

---

### 4. Installera Saknade DLL-filer

**Vanliga DLL-filer som kan saknas:**
- msvcrt.dll
- msvcp140.dll
- vcruntime140.dll

**Fix:**
```bash
# I Whiskey bottle, installera Visual C++ Redistributable
winetricks vcrun2015
winetricks vcrun2017
```

---

### 5. Konfigurera Wine Prefix

**Sätt Windows-version:**
```bash
# I Whiskey bottle terminal
winecfg
# Välj Windows 10 eller Windows 7
```

---

## 📋 CHECKLIST

- [ ] Whiskey är installerat
- [ ] Bottle (Wine prefix) är skapad
- [ ] standard tools.exe finns i bottle
- [ ] Saknade DLL-filer är installerade
- [ ] Windows-version är korrekt konfigurerad

---

## 💡 REKOMMENDATIONER

1. **Använd Windows 10** i Wine prefix (bättre kompatibilitet)
2. **Installera Visual C++ Redistributable** (krävs för många Windows-appar)
3. **Kontrollera Whiskey loggar** för felmeddelanden
4. **Testa med enkel Windows-app** först för att verifiera Whiskey fungerar

---

**Status:** 🔍 **DIAGNOSTISERAR PROBLEM**

**Nästa steg:** Identifiera exakt vad som är fel och applicera rätt fix.
