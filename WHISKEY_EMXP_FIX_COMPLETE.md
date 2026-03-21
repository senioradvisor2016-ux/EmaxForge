# Whiskey/standard tools Fix - Komplett

**Datum:** 2026-03-07  
**Status:** ✅ **FIX APPLICERAD**

---

## ✅ APPLICERADE FIXAR

### 1. Kopierade Saknade DLL-filer
- ✅ **msvcr140.dll** kopierad från syswow64 till system32
- ✅ **msvcp140.dll** kopierad (om saknad)
- ✅ **vcruntime140.dll** kopierad (om saknad)

**Plats:**
```
~/Library/Containers/com.isaacmarovitz.Whisky/Bottles/785BA294-9A93-4E87-9C1B-FB9A251D6B4A/drive_c/windows/system32/
```

### 2. Verifierade standard tools
- ✅ **standardn.exe** finns i bottle
- ✅ Storlek: 5,497,856 bytes (korrekt)

**Plats:**
```
~/Library/Containers/com.isaacmarovitz.Whisky/Bottles/785BA294-9A93-4E87-9C1B-FB9A251D6B4A/drive_c/standard tools/standardn.exe
```

---

## 📊 VERIFIERING

**Alla nödvändiga DLL-filer:**
- ✅ msvcr120.dll (Visual C++ 2013)
- ✅ msvcp120.dll (Visual C++ 2013)
- ✅ msvcr140.dll (Visual C++ 2015) - **FIXAD**
- ✅ msvcp140.dll (Visual C++ 2015)
- ✅ vcruntime140.dll (Visual C++ 2015)

---

## 🎯 NÄSTA STEG

**Testa starta standard tools i Whiskey:**
1. Öppna Whiskey
2. Välj din standard tools bottle
3. Klicka på "Run" → Välj "standardn.exe"
4. standard tools borde nu starta!

---

## ⚠️  OM PROBLEM KVARSTÅR

**Om standard tools fortfarande inte startar:**

1. **Kontrollera Whiskey loggar:**
   - Öppna Whiskey
   - Välj bottle → "View Logs"
   - Leta efter felmeddelanden

2. **Installera Visual C++ Redistributables via winetricks:**
   - I Whiskey: Välj bottle → Run → Run Command
   - Kör: `winetricks vcrun2013 vcrun2015 vcrun2017`

3. **Skapa ny bottle (om registry saknas):**
   - Skapa ny bottle i Whiskey (Windows 10)
   - Installera: `winetricks vcrun2013 vcrun2015 vcrun2017`
   - Kopiera standardn.exe till drive_c/standard tools/

---

**Status:** ✅ **FIX APPLICERAD - TESTA STARTA standard tools!**
