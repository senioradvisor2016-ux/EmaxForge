# Installera msvcr140.dll i Whiskey

**Datum:** 2026-03-07  
**Status:** 🔧 **INSTALLATION GUIDE**

---

## 🔍 PROBLEM

**msvcr140.dll saknas i:**
- `system32/msvcr140.dll` ❌
- `syswow64/msvcr140.dll` ❌

**Detta förhindrar standard tools från att starta.**

---

## ✅ LÖSNING

### Metod 1: Via winetricks (Rekommenderat)

**I Whiskey:**
1. Öppna Whiskey.app
2. Välj din standard tools bottle (785BA294-9A93-4E87-9C1B-FB9A251D6B4A)
3. Klicka på "Run" → "Run Command"
4. Kör: `winetricks vcrun2015 --force`
5. Vänta tills installationen är klar

**Verifiera:**
```bash
ls ~/Library/Containers/com.isaacmarovitz.Whisky/Bottles/785BA294-9A93-4E87-9C1B-FB9A251D6B4A/drive_c/windows/system32/msvcr140.dll
```

---

### Metod 2: Installera alla Visual C++ Redistributables

**I Whiskey → Run Command:**
```
winetricks vcrun2013 vcrun2015 vcrun2017
```

Detta installerar:
- Visual C++ 2013 Redistributable
- Visual C++ 2015 Redistributable (inkl. msvcr140.dll)
- Visual C++ 2017 Redistributable

---

### Metod 3: Ladda ner och installera manuellt

**Steg:**
1. Ladda ner Visual C++ 2015 Redistributable från Microsoft:
   - https://www.microsoft.com/en-us/download/details.aspx?id=48145
   - Välj: `vc_redist.x64.exe` (för 64-bit) eller `vc_redist.x86.exe` (för 32-bit)

2. I Whiskey:
   - Välj bottle → "Run" → "Run Command"
   - Navigera till nedladdningsmappen:
     ```
     cd ~/Downloads
     wine vc_redist.x64.exe
     ```
   - Följ installationsguiden

3. Verifiera:
   ```bash
   ls ~/Library/Containers/com.isaacmarovitz.Whisky/Bottles/785BA294-9A93-4E87-9C1B-FB9A251D6B4A/drive_c/windows/system32/msvcr140.dll
   ```

---

## 📋 VERIFIERING

**Efter installation, verifiera:**
```bash
cd /Users/senioradvisor/clawd/EmaxForge
./fix_whiskey_standard.sh
```

**Förväntat resultat:**
- ✅ msvcr120.dll
- ✅ msvcp120.dll
- ✅ **msvcr140.dll ← Borde nu finnas!**
- ✅ msvcp140.dll
- ✅ vcruntime140.dll

---

## 💡 TIPS

**Om winetricks inte installerar msvcr140.dll:**
- Försök installera alla Visual C++ Redistributables (metod 2)
- Eller ladda ner och installera manuellt (metod 3)

**Om problemet kvarstår:**
- Kontrollera Whiskey loggar
- Testa att starta standard tools ändå (kanske fungerar med msvcp140.dll)

---

**Status:** 🔧 **FÖLJ INSTRUKTIONERNA OVAN FÖR ATT INSTALLERA msvcr140.dll**
