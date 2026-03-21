# Importera Roland-banker till EmaxII-01.ez2

## 📋 Förberedelser

1. **Hitta Roland-banker (.EB2 filer)**
   - Roland-banker är vanligtvis i .EB2 format
   - De kan finnas i Downloads, Desktop, eller andra mappar
   - Om du har .EM2 eller andra format, konvertera dem först till .EB2

2. **Kontrollera diskutrymme**
   - EmaxII-01.ez2 har 51 banks redan
   - Max banks: 111
   - Du kan lägga till upp till 60 fler banks

## 🚀 Användning

### Metod 1: Python Script (Rekommenderad)

```bash
cd ~/Downloads
python3 ~/clawd/EmaxForge/import_banks_to_disk.py EmaxII-01.ez2 roland_bank1.eb2 roland_bank2.eb2 roland_bank3.eb2
```

**Exempel:**
```bash
# Om du har Roland-banker i Downloads
python3 ~/clawd/EmaxForge/import_banks_to_disk.py \
  ~/Downloads/EmaxII-01.ez2 \
  ~/Downloads/ROLAND_*.EB2
```

### Metod 2: EmaxForge App

1. Öppna EmaxForge
2. Öppna `EmaxII-01.ez2` från Downloads
3. Klicka på "Import Banks"
4. Välj Roland-banker (.EB2 filer)
5. Klicka på "Import"

## 📁 Var hittar jag Roland-banker?

Roland-banker kan finnas i:
- `~/Downloads/` - Nedladdade filer
- `~/Desktop/` - Skrivbordet
- `~/Documents/` - Dokument
- Andra mappar där du lagrat sample banks

**Sök efter Roland-banker:**
```bash
find ~/Downloads ~/Desktop -name "*roland*" -o -name "*ROLAND*" -o -name "*.EB2" 2>/dev/null
```

## ⚠️ Viktigt

1. **Backup:** Ta backup av `EmaxII-01.ez2` innan du importerar
   ```bash
   cp ~/Downloads/EmaxII-01.ez2 ~/Downloads/EmaxII-01.ez2.backup
   ```

2. **Format:** Endast .EB2 filer kan importeras direkt
   - Om du har .EM2 eller andra format, använd EmaxForge's konverteringsfunktion först

3. **Namn:** Bank-namn begränsas till 14 tecken
   - Långa namn kommer trunkeras automatiskt

## ✅ Verifiering

Efter import, verifiera att bankerna är importerade:

```bash
python3 ~/clawd/EmaxForge/analyze_image.py ~/Downloads/EmaxII-01.ez2
```

Eller öppna disken i EmaxForge och kontrollera att bankerna syns i listan.

## 🐛 Felsökning

**Problem: "Not enough space"**
- Disken är full (111 banks max)
- Lösning: Använd en större disk eller ta bort gamla banks

**Problem: "No free BNT slot"**
- BNT (Bank Name Table) är full
- Lösning: Ta bort gamla banks eller använd en större disk

**Problem: "Bank file too small"**
- .EB2 filen är korrupt eller för liten
- Lösning: Kontrollera att filen är korrekt

## 📝 Exempel: Importera flera Roland-banker

```bash
# Hitta alla Roland-banker
cd ~/Downloads
find . -name "*roland*.eb2" -o -name "*ROLAND*.EB2" > roland_banks.txt

# Importera alla
python3 ~/clawd/EmaxForge/import_banks_to_disk.py \
  EmaxII-01.ez2 \
  $(cat roland_banks.txt)
```
