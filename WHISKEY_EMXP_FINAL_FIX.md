# Whiskey/standard tools Fix - Slutgiltig Lösning

**Datum:** 2026-03-07  
**Problem:** msvcr140.dll saknas - standard tools kan inte starta  
**Status:** ✅ **LÖSNING TILLGÄNGLIG**

---

## 🔍 PROBLEM

**msvcr140.dll saknas helt:**
- ❌ Finns inte i syswow64
- ❌ Finns inte i andra bottles
- ❌ Kräver installation via winetricks

**Detta är den ENDA saknade DLL-filen som förhindrar standard tools från att starta.**

---

## ✅ LÖSNING

### Metod 1: Via Whiskey UI (Rekommenderat)

**Steg-för-steg:**

1. **Öppna Whiskey.app**
   - Leta efter Whiskey i Applications eller Launchpad

2. **Välj din standard tools bottle**
   - Bottle ID: `785BA294-9A93-4E87-9C1B-FB9A251D6B4A`
   - Den borde synas i Whiskey's bottle-lista

3. **Öppna Run Command**
   - Klicka på "Run" → "Run Command"
   - Eller tryck `Cmd+R` när bottlen är vald

4. **Installera Visual C++ 2015 Redistributable**
   - Skriv: `winetricks vcrun2015`
   - Tryck Enter
   - Vänta tills installationen är klar (kan ta några minuter)

5. **Verifiera installation**
   - Kolla att `msvcr140.dll` nu finns i:
     ```
     ~/Library/Containers/com.isaacmarovitz.Whisky/Bottles/785BA294-9A93-4E87-9C1B-FB9A251D6B4A/drive_c/windows/system32/msvcr140.dll
     ```

6. **Testa starta standard tools**
   - I Whiskey: Välj bottle → "Run" → Välj "standardn.exe"
   - standard tools borde nu starta!

---

### Metod 2: Installera Alla Visual C++ Redistributables

**För bäst kompatibilitet, installera alla:**

I Whiskey → Run Command:
```
winetricks vcrun2013 vcrun2015 vcrun2017
```

Detta installerar:
- Visual C++ 2013 Redistributable
- Visual C++ 2015 Redistributable (inkl. msvcr140.dll)
- Visual C++ 2017 Redistributable

---

## 📋 VERIFIERING

**Efter installation, verifiera att alla DLL-filer finns:**

```bash
cd /Users/senioradvisor/clawd/EmaxForge
./fix_whiskey_standard.sh
```

**Förväntat resultat:**
- ✅ msvcr120.dll
- ✅ msvcp120.dll
- ✅ msvcr140.dll ← **Detta borde nu finnas!**
- ✅ msvcp140.dll
- ✅ vcruntime140.dll

---

## ⚠️  OM PROBLEM KVARSTÅR

**Om winetricks inte fungerar:**

1. **Kontrollera att Whiskey är uppdaterad**
   - Öppna Whiskey → About
   - Uppdatera om nödvändigt

2. **Skapa ny bottle**
   - Skapa ny bottle i Whiskey (Windows 10)
   - Installera: `winetricks vcrun2013 vcrun2015 vcrun2017`
   - Kopiera standardn.exe till drive_c/standard tools/

3. **Kontrollera Whiskey loggar**
   - Öppna Whiskey → Välj bottle → "View Logs"
   - Leta efter felmeddelanden

---

## 🎯 SNABB GUIDE

**3 enkla steg:**

1. Öppna **Whiskey.app**
2. Välj **standard tools bottle** → **Run** → **Run Command**
3. Skriv: **`winetricks vcrun2015`** → Tryck Enter

**Klart!** standard tools borde nu kunna starta.

---

**Status:** ✅ **LÖSNING TILLGÄNGLIG - FÖLJ INSTRUKTIONERNA OVAN**

**Nästa steg:** Installera `winetricks vcrun2015` i Whiskey för att fixa problemet.
