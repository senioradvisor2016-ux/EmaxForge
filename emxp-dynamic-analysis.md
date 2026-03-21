# standard tools Dynamic Analysis - Enklare än Dekompilering?

## Idé: Kör standard tools under debugger och logga vad den gör

### Verktyg: x64dbg (Windows debugger)
1. Kör standard tools i Wine/Windows VM
2. Attach x64dbg
3. Sätt breakpoints på:
   - WriteFile (när den skriver boot signature)
   - SetFilePointer (när den söker till offset 0x400)
   - CreateFile (när den öppnar .EZ2 filer)
4. Logga exakt vad den skriver och var

### Fördelar:
- Ser EXAKTA värden (inte bara decompiled algoritm)
- Kan köra "Create Boot Disk" och se live vad den gör
- Enklare än att läsa 5.2MB assembly

### Verktyg på Mac:
**OllyDbg/x64dbg via Wine:**
```bash
brew install wine-stable
# Hämta x64dbg: https://x64dbg.com
wine x64dbg.exe
```

**Alternative: API Monitor**
- Logga alla WriteFile/ReadFile calls automatiskt
- Visar buffer contents
- https://www.rohitab.com/apimonitor

### Snabbare metod: Patch standard tools för loggning
Använd Ghidra/IDA för att hitta WriteFile-anrop, ersätt med wrapper som loggar!

## Bottom Line
Om målet är "förstå hur standard tools skapar boot disks":
→ **Dynamic analysis** (debugger) kan vara snabbare än dekompilering
→ Se exakt vad den skriver istället för att gissa från kod

Om målet är "implementera alla standard tools features":
→ **IDA Pro** eller **Binary Ninja** är bättre än Ghidra för Windows PE32
