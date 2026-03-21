# EMAXFORGE_STATE.md — Nuläge & Kritisk Kunskap

> Läs detta i början av varje EmaxForge-session. Håll det kompakt.
> Uppdateras efter varje viktig förändring.

---

## 🎯 Status (Mar 20, 2026)

- **Version:** v0.5 Beta
- **Senaste build:** ✅ Kompilerar (16-22s, warnings only)
- **Hardware-test:** ⏳ VÄNTAR — ej testat på riktig EMAX II
- **Ny approach:** Klona-baserad (se nedan) — ersätter scratch-skapande

---

## 🏛️ Referensdiskar (FACIT)

**Tre original E-mu factory diskar i `~/Downloads/`:**
| Fil | Storlek | Innehåll |
|-----|---------|---------|
| `EmaxII-01.ez2` | 154 MB | OS rev 2.14 + 63 banker (Factory Library 1) |
| `EmaxII-02.ez2` | 96 MB | 50 banker (Factory Library 2) |
| `EmaxII-03.ez2` | 96 MB | 47 banker (Factory Library 3) |

**Dessa är sanningskällan.** Allt EmaxForge skapar ska matcha deras format.

---

## ⚠️ NEVER FORGET — Kritiska fakta

### ZuluSCSI filnamn
- Filnamn MÅSTE ha **dubbel siffra**: `HD10.hda`, `HD20.hda` (INTE `HD1.hda`)
- `HD10.hda` = SCSI ID 1 = boot disk

### EMAX II bootar från SCSI ID 1
- `HD10.hda` = boot disk (bekräftat på hårdvara)
- zuluscsi.ini: `[SCSI]` + `EnableParity = 1` + `[SCSI1]` — inget mer behövs

### Boot-signaturer (BÅDA är giltiga!)
- `0xa1 0x93` — E-mu original factory format (de tre originaldiskarna)
- `0x78 0x82` — EMXP-programvarans format
- EMAX II-firmware accepterar båda

### Catalog-format (32 bytes per entry)
- Bytes 0-13: banknamn (14 tecken, null/space-paddat)
- Bytes 14-15: `00 00`
- Bytes 16-17: start-cluster (little-endian)
- Bytes 18-19: antal sektorer
- Bytes 22-23: storleksfält
- Bytes 24-25: flags (`0x8100`)
- Bytes 26-31: `00 00 00 00 00 00`
- Tomma slots = `00 00...` (nulls) — osynliga för EMAX II

### Catalog-layout i original-format
- Catalog börjar vid offset `0x1200` (efter EMX2-header + FAT)
- Entry 0: `"EMAX2 Software"` = OS-entry
- Entry 1+: banker i alfabetisk ordning
- Tomma slots = noll-bytes (INTE `0x8080` som i EMXP-format)

### EB2-format (standalone bank-fil)
- Banknamnet = **filnamnet** (ej i filen)
- Innehåller: preset-tabell, preset-parametrar (ADSR/filter), sample-audio
- Preset-namn finns som ASCII-strängar med `A`-suffix (typ-markör)

### OS
- OS rev 2.14 finns i `EmaxII-01.ez2` vid offset `0x83E240`
- Extrahera härifrån — **inte** från EMXP-skapade filer

### Disk storlekar (original E-mu)
- 96 MB, 239 MB, 481 MB, 633 MB, 962 MB

---

## 🎯 Ny approach: Klona-baserad disk-skapande

**Istället för att bygga diskar från scratch:**

1. Extrahera OS + diskstruktur från `EmaxII-01.ez2`
2. Nolla all sample-audio (copyright)
3. Nolla alla banknamn i catalog
4. Resultat: Tre rena tomma diskar med rätt format och OS

**Levereras med EmaxForge:**
```
Resources/BlankDisks/
├── HD10.hda  (154MB, OS + tom catalog)
├── HD20.hda  (96MB, tom catalog)
└── HD30.hda  (96MB, tom catalog)
```

**Användaren:** Importerar sina egna EB2-banker till tomma slots.

---

## ✅ Vad som fungerar (bekräftat)

- Bank import/export med korrekt cluster-offset
- CLI-Anything harness (24 kommandon, installerat)
- 73 Swift unit tests (0 failures)
- Floppy support (720KB/1.44MB/800KB, HFE för Gotek)
- ZuluSCSI config generator
- InspectorPanel + BankInspectorPanel

---

## ❌ Vad som INTE fungerat (historik)

| Bug | Symptom | Fix |
|-----|---------|-----|
| Felaktigt filnamn (HD0 vs HD00) | Bootar ej | Dubbel siffra i namn |
| OS skrivet på fel cluster | Bootar ej | cluster = clusterAreaStart + (1 × size) |
| Fel OS-fil | OS-data = noll | Extrahera från EmaxII-01.ez2 |
| Ingen bank på boot disk | Bootar ej | Auto-skapa INIT BANK (eller tom catalog) |
| FAT entry 0 = 0x8000 | Validering felar | Ska vara 0x000F |
| FLAGS big-endian | Catalog corrupt | Ska vara 0x8100 (bytes: 81 00) |
| bankCount overriden | Felformaterad | Använd template.bankCount |

---

## 🔧 Arkitektur

```
EmaxForge/
├── EmaxForge/Sources/Services/
│   ├── ImageCreator.swift      ← Disk-skapande (mest kritisk)
│   ├── EmaxIIFileSystem.swift  ← Parser + cluster offset
│   ├── BankImporter.swift      ← Bank import
│   └── BankManager.swift       ← Export/copy
├── agent-harness/              ← CLI-Anything (Python)
├── tests/                      ← Swift tests + .last-test
└── build.sh                    ← ./build.sh → .build/EmaxForge.app
```

**SwiftUI tips:** Dela upp stora `body` i computed properties → undviker "unable to type-check"

---

## 🎯 Nästa steg

1. **Extrahera OS** från `EmaxII-01.ez2` → ny referens-OS
2. **Skapa blank-diskar** via kloning + nollning av banker
3. **Testa blank-diskar** på riktig EMAX II
4. **Release build** — Xcode Archive + GitHub release
