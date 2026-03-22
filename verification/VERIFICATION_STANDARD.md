# EmaxForge Verification Standard

## Princip: Alla jämförelser mot EMXP-skapade diskar

**HD10.EZ2 skall INTE användas som referens.**
- Källa: Peters riktiga EMAX II-disk (ZuluSCSI → EMXP)
- Risk: Kan innehålla EMAX II-specifika quirks som EMXP inte skriver
- Status: ❌ FÖRBJUDEN som gold standard

---

## Gold Standard: EMXP_GOLD_EMPTY

**Fil:** `EMXP/Images/EMAXII_IMAGE_EMXP_GOLD.EZ2`  
**Skapad:** EMXP v3.11 → New Image → 239 MB → Boot disk (med OS)  
**Datum:** Mar 21 20:17  
**Innehåll:** OS only, 0 banker  
**Status:** ✅ Ren EMXP-skapad disk — gold standard för tom disk

### Hur den återskapas (om den förstörs)

```
EMXP → 4 (Manage HD Images) → 1 (New File)
→ Filnamn: EMAXII_IMAGE_EMXP_GOLD
→ Storlek: 239 MB
→ Inkludera OS: Ja
```

---

## Referensdisk med banker: EMXP_BANK_REF

**Fil:** `EMXP/Images/EMAXII_IMAGE_EMXP_BANK_REF.EZ2`  
**Skapad:** EMXP v3.11 → Import Banks från GP1/Rhodes/Synth_Blend.EB2  
**Status:** ✅ EMXP-importerade banker — gold standard för bankformat

### Banker i EMXP_BANK_REF (att återskapa)

Importera dessa EB2-filer via EMXP i denna ordning:

| Slot | Bank | EB2-fil | Presets | Samples |
|------|------|---------|---------|---------|
| 1 | Grand Piano 1 | Grand_Piano_1.EB2 | 64 | 64 |
| 2 | Rhodes | Rhodes.EB2 | 64 | 64 |
| 3 | Synth Blend | Synth_Blend.EB2 | 64 | 64 |

### Hur man importerar via EMXP

```
EMXP → 1 (Manage Bank Files)
→ i (Import)
→ Välj TARGET: EMAXII_IMAGE_EMXP_BANK_REF
→ Välj SOURCE: C:\EMXP\Banks\Grand_Piano_1.EB2
→ Upprepa för Rhodes och Synth_Blend
```

**EB2-filer i Wine:**
`C:\EMXP\Banks\` = `~/Library/Containers/.../drive_c/EMXP/Banks/`

---

## Verifieringsflöde

### Steg 1: Skapa EmaxForge-disk

```bash
cd ~/clawd/EmaxForge/agent-harness
python3 -c "
from cli_anything.emaxforge.core import disk, bank
disk.create_disk(239, 1, '/tmp/EMAXFORGE_TEST.hda', include_os=True)
bank.import_bank('/tmp/EMAXFORGE_TEST.hda', 'Grand_Piano_1.EB2')
bank.import_bank('/tmp/EMAXFORGE_TEST.hda', 'Rhodes.EB2')
bank.import_bank('/tmp/EMAXFORGE_TEST.hda', 'Synth_Blend.EB2')
"
```

### Steg 2: Kopiera till EMXP

```bash
cp /tmp/EMAXFORGE_TEST.hda \
  ~/Library/.../drive_c/EMXP/Images/EMAXFORGE_TEST.EZ2
```

### Steg 3: Jämför mot EMXP_BANK_REF

```bash
python3 ~/clawd/EmaxForge/verification/compare_disks.py \
  EMAXII_IMAGE_EMXP_BANK_REF.EZ2 \
  EMAXFORGE_TEST.EZ2
```

### Steg 4: Verifiera i EMXP GUI

```
EMXP → 4 → Välj EMAXFORGE_TEST → b (Banks)
Förväntat: Grand Piano 1 / Rhodes / Synth Blend
           Ingen -CORRUPT- Error: 2
```

---

## Vad som SKALL matcha

| Fält | Källa | Krav |
|------|-------|------|
| Boot sector (0x000-0x200) | Template | Identisk |
| FAT primary (0x400-0x1000) | Beräknad | Identisk struktur |
| BNT entries (0x1000+) | Beräknad | Namn, flags, cluster, count, pres, samp |
| Bank-data (cluster area) | EB2-fil | Byte-för-byte identisk |

## Vad som FÅR skilja

| Fält | Förklaring |
|------|-----------|
| FAT backup (0x200-0x400) | EMXP uppdaterar — vi behöver synka |
| Oanvända cluster-area | Zeros vs garbage — spelar ingen roll |

---

## Kända buggar (fixade)

| Datum | Bug | Fix | Commit |
|-------|-----|-----|--------|
| Mar 22 | BNT preset/sample count hardkodad (fel!) | Räkna från EB2 pointers | `4662473` |
| Mar 18 | FAT entry 0 = 0x8000 → fixat 0x000F | Template fix | — |
| Mar 8 | Boot från SCSI ID 0, inte ID 1 | Alla HD0→HD1 | — |

---

*Uppdaterad: 2026-03-22*
