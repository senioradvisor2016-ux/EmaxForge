"""
SF2 → EMAX II disk importer
Läser en SF2-fil och skriver samples + preset-data till en .hda-bank

EMAX II On-Disk Bank Structure (reverse-engineerat från EMXP_BANK_REF.EZ2):

  0x000000 - 0x9B1FF:  PCM sample-data (raw Int16 LE, mono)
  0x9B200  - 0xC87FF:  Zero-padding (separator, 185 KB)
  0xC8800  - 0xC88C8:  Preset pointer-tabell (UInt16 LE, 348 bytes/preset)
  0xC88D0  - 0xC89A0:  0x00200000-block (kopieras från EB2/SF2)
  0xC89A0  + N*164:    Sample-descriptors:
                         [0x00] UInt32 sample_start_offset (bytes i PCM-area)
                         [0x04] UInt32 sample_end_offset
                         [0x08] UInt32 loop_end (eller storlek)
                         [0x0C] char[10] sample_name (null-padded)
                         [0x16] UInt8 original_pitch
                         [0x17] UInt8 unknown
                         [0x18] UInt16 loop_start_frames
                         [0x1A] UInt16 sample_rate_ish
                         [0x1C] UInt32 sample_size_frames
                         ... (keymap-data, variabel)
  0x14F700 + N*:       Preset-namnstabell (null-separerade strings)

Status: EXPERIMENTAL — exakta offset-fält under verifiering
"""

import struct
from pathlib import Path


# ──────────────────────────────────────────────────────────────────────────────
# SF2 Parser (egen, kräver inga externa beroenden)
# ──────────────────────────────────────────────────────────────────────────────

def parse_sf2(path: Path) -> dict:
    """
    Läs SF2 (SoundFont 2) och returnera en dict med:
      - samples:  lista med sample-info + raw PCM
      - presets:  lista med preset-info
      - smpl_offset, smpl_size: position för raw PCM i filen
    """
    data = path.read_bytes()

    def find_chunk(tag: str) -> tuple[int | None, int]:
        idx = data.find(tag.encode('ascii'))
        if idx < 0:
            return None, 0
        size = struct.unpack_from("<I", data, idx + 4)[0]
        return idx + 8, size

    smpl_off, smpl_size = find_chunk('smpl')
    shdr_off, shdr_size = find_chunk('shdr')
    phdr_off, phdr_size = find_chunk('phdr')
    inst_off, inst_size = find_chunk('inst')
    ibag_off, ibag_size = find_chunk('ibag')
    igen_off, igen_size = find_chunk('igen')
    pbag_off, pbag_size = find_chunk('pbag')
    pgen_off, pgen_size = find_chunk('pgen')

    # ── Samples (SHDR = 46 bytes/entry) ──────────────────────────────────────
    samples = []
    if shdr_off:
        n = shdr_size // 46
        for i in range(n - 1):  # Sista = EOS terminal
            off = shdr_off + i * 46
            name = data[off:off + 20].rstrip(b'\x00').decode('ascii', 'replace')
            s_start, s_end, loop_s, loop_e = struct.unpack_from("<IIII", data, off + 20)
            rate = struct.unpack_from("<I", data, off + 36)[0]
            pitch = struct.unpack_from("<b", data, off + 40)[0]
            correction = struct.unpack_from("<b", data, off + 41)[0]
            link = struct.unpack_from("<H", data, off + 42)[0]
            stype = struct.unpack_from("<H", data, off + 44)[0]

            pcm = data[smpl_off + s_start * 2: smpl_off + s_end * 2] if smpl_off else b''
            samples.append({
                'name': name,
                'start': s_start,           # frames från smpl-start
                'end': s_end,               # frames från smpl-start
                'loop_start': loop_s,       # frames
                'loop_end': loop_e,         # frames
                'rate': rate,               # Hz
                'original_pitch': pitch,    # semitoner (MIDI note)
                'pitch_correction': correction,
                'link': link,
                'type': stype,
                'pcm': pcm,
                'pcm_size': len(pcm),
            })

    # ── Presets (PHDR = 38 bytes/entry) ──────────────────────────────────────
    presets = []
    if phdr_off:
        n = phdr_size // 38
        for i in range(n - 1):
            off = phdr_off + i * 38
            name = data[off:off + 20].rstrip(b'\x00').decode('ascii', 'replace')
            preset, bank, bag_idx = struct.unpack_from("<HHH", data, off + 20)
            presets.append({
                'name': name,
                'preset': preset,
                'bank': bank,
                'bag_idx': bag_idx,
            })

    # ── Instruments + zones (för keymap-extraktion) ───────────────────────────
    zones = []
    if ibag_off and igen_off and inst_off:
        try:
            n_inst = inst_size // 22
            for i in range(n_inst - 1):
                off = inst_off + i * 22
                iname = data[off:off + 20].rstrip(b'\x00').decode('ascii', 'replace')
                bag = struct.unpack_from("<H", data, off + 20)[0]
                next_bag = struct.unpack_from("<H", data, inst_off + (i + 1) * 22 + 20)[0]
                # Läs generators för detta instrument
                inst_zones = []
                for b in range(bag, next_bag):
                    gen_off = ibag_off + b * 4
                    if gen_off + 4 > ibag_off + ibag_size:
                        break
                    gen_idx = struct.unpack_from("<H", data, gen_off)[0]
                    gen_cnt = struct.unpack_from("<H", data, gen_off + 2)[0]
                    # Hämta generators
                    gens = {}
                    for g in range(gen_idx, gen_cnt):
                        goff = igen_off + g * 4
                        if goff + 4 > igen_off + igen_size:
                            break
                        gtype = struct.unpack_from("<H", data, goff)[0]
                        gval = struct.unpack_from("<H", data, goff + 2)[0]
                        gens[gtype] = gval
                    inst_zones.append(gens)
                zones.append({'name': iname, 'zones': inst_zones})
        except Exception:
            pass  # Keymap-extraktion är optional

    return {
        'path': path,
        'samples': samples,
        'presets': presets,
        'zones': zones,
        'smpl_offset': smpl_off,
        'smpl_size': smpl_size,
    }


# ──────────────────────────────────────────────────────────────────────────────
# EMAX II On-Disk Bank Builder
# ──────────────────────────────────────────────────────────────────────────────

# Kända layout-konstanter (239 MB disk, cluster_size=0x77800)
CLUSTER_SIZE         = 0x77800   # 489,472 bytes
PCM_AREA_END         = 0x9B200   # Zero-block börjar här
META_BLOCK_OFFSET    = 0xC8800   # Metadata-block börjar här
PRESET_TABLE_OFFSET  = 0xC8800   # Preset pointer-tabell start
PRESET_ENTRY_SIZE    = 348       # 0x15C bytes per preset (reverse-engineerat)
SAMPLE_DESC_OFFSET   = 0xC89A0   # Sample-descriptors börjar här
SAMPLE_DESC_SIZE     = 164       # bytes per sample-descriptor (approximation)
PRESET_NAME_OFFSET   = 0x14F700  # Preset-namnstabell start


def build_sample_descriptor(sample: dict, pcm_byte_offset: int) -> bytes:
    """
    Bygg ett EMAX II sample-descriptor (on-disk format).
    Totalt SAMPLE_DESC_SIZE bytes.

    Känd struktur (från 0xC89A0-analys):
      [0x00] UInt32 sample_start  (byte-offset i PCM-area)
      [0x04] UInt32 sample_end    (byte-offset i PCM-area)
      [0x08] UInt32 loop_end      (byte-offset i PCM-area)
      [0x0C] char[10] name
      [0x16] UInt8 original_pitch
      [0x17] UInt8 unknown (0)
      [0x18] UInt16 loop_start_frames
      [0x1A] UInt16 rate (lsb)
      [0x1C] UInt32 size_frames
      ... rest: zeros (keymap-data, okänt format)
    """
    name_bytes = sample['name'][:10].encode('ascii', 'replace').ljust(10, b'\x00')
    pcm_end = pcm_byte_offset + sample['pcm_size']
    loop_end_bytes = pcm_byte_offset + sample['loop_end'] * 2

    desc = bytearray(SAMPLE_DESC_SIZE)
    struct.pack_into("<I", desc, 0x00, pcm_byte_offset)
    struct.pack_into("<I", desc, 0x04, pcm_end)
    struct.pack_into("<I", desc, 0x08, loop_end_bytes)
    desc[0x0C:0x16] = name_bytes
    desc[0x16] = sample['original_pitch'] & 0xFF
    desc[0x17] = 0
    struct.pack_into("<H", desc, 0x18, sample['loop_start'])
    struct.pack_into("<H", desc, 0x1A, sample['rate'] & 0xFFFF)
    struct.pack_into("<I", desc, 0x1C, sample['pcm_size'] // 2)

    return bytes(desc)


def sf2_to_emax_bank(sf2_path: Path, bank_name: str, cluster_count: int = 4) -> bytes:
    """
    Konvertera SF2-fil till EMAX II bank-blob.

    Returnerar raw bytes (cluster_count × CLUSTER_SIZE) som kan skrivas
    direkt till disk-clustrar.
    """
    sf2 = parse_sf2(sf2_path)
    samples = sf2['samples']
    presets = sf2['presets']

    total_size = CLUSTER_SIZE * cluster_count
    bank = bytearray(total_size)

    # ── 1. Skriv PCM-data från 0x0 ──────────────────────────────────────────
    pcm_cursor = 0
    pcm_offsets = []
    for s in samples:
        if pcm_cursor + s['pcm_size'] > PCM_AREA_END:
            print(f"VARNING: PCM overflows area (sample {s['name']!r} ryms ej)")
            break
        bank[pcm_cursor:pcm_cursor + s['pcm_size']] = s['pcm']
        pcm_offsets.append(pcm_cursor)
        pcm_cursor += s['pcm_size']

    print(f"PCM: {pcm_cursor:,} bytes ({len(pcm_offsets)} samples)")

    # ── 2. Skriv preset pointer-tabell @ META_BLOCK_OFFSET ──────────────────
    # Tabellen är UInt16-värden som pekar på preset-offset
    # TODO: exakt format okänt — detta är placeholder
    # preset_table_off = PRESET_TABLE_OFFSET
    # for i, p in enumerate(presets):
    #     val = i * PRESET_ENTRY_SIZE
    #     struct.pack_into("<H", bank, preset_table_off + i * 2, val & 0xFFFF)

    # ── 3. Skriv 0x00200000-block (från EB2/SF2 metadata) ──────────────────
    # Kopieras direkt — innehåller sample-storlekstabeller
    # Offset: 0xC88D0, storlek: 0xD0 bytes
    zero_two = bytes([0x00, 0x00, 0x20, 0x00]) * (0xD0 // 4)
    bank[0xC88D0:0xC88D0 + len(zero_two)] = zero_two

    # ── 4. Skriv sample-descriptors @ SAMPLE_DESC_OFFSET ────────────────────
    for i, (s, off) in enumerate(zip(samples, pcm_offsets)):
        desc = build_sample_descriptor(s, off)
        desc_pos = SAMPLE_DESC_OFFSET + i * SAMPLE_DESC_SIZE
        if desc_pos + SAMPLE_DESC_SIZE > total_size:
            print(f"VARNING: Sample descriptor {i} ryms ej")
            break
        bank[desc_pos:desc_pos + SAMPLE_DESC_SIZE] = desc

    print(f"Sample descriptors: {len(pcm_offsets)} st @ 0x{SAMPLE_DESC_OFFSET:X}")

    # ── 5. Skriv preset-namnstabell @ PRESET_NAME_OFFSET ────────────────────
    name_cursor = PRESET_NAME_OFFSET
    for p in presets:
        name_bytes = p['name'].encode('ascii', 'replace') + b'\x00'
        if name_cursor + len(name_bytes) < total_size:
            bank[name_cursor:name_cursor + len(name_bytes)] = name_bytes
            name_cursor += len(name_bytes)

    print(f"Preset-namn: {len(presets)} st @ 0x{PRESET_NAME_OFFSET:X}")
    print(f"Bank-blob: {total_size:,} bytes ({cluster_count} clusters)")
    print(f"OBS: Metadata-format delvis känt — kräver verifiering mot EMXP")

    return bytes(bank)


# ──────────────────────────────────────────────────────────────────────────────
# Analys-verktyg
# ──────────────────────────────────────────────────────────────────────────────

def analyze_sf2(sf2_path: Path) -> None:
    """Skriv ut detaljerad info om en SF2-fil."""
    sf2 = parse_sf2(sf2_path)
    print(f"=== {sf2_path.name} ===")
    print(f"Presets: {len(sf2['presets'])}")
    print(f"Samples: {len(sf2['samples'])}")
    print(f"PCM-data: {sf2['smpl_size']:,} bytes @ offset 0x{sf2['smpl_offset']:X}")
    print()

    print("--- PRESETS ---")
    for p in sf2['presets']:
        print(f"  [{p['bank']:3d}:{p['preset']:3d}] {p['name']}")

    print()
    print("--- SAMPLES ---")
    total_pcm = 0
    for s in sf2['samples']:
        total_pcm += s['pcm_size']
        print(
            f"  {s['name']!r:20s}  "
            f"rate={s['rate']:5d} Hz  "
            f"size={s['pcm_size']:8,} bytes  "
            f"loop={s['loop_start']}-{s['loop_end']}  "
            f"pitch={s['original_pitch']}"
        )
    print(f"\nTotal PCM: {total_pcm:,} bytes ({total_pcm / 1024 / 1024:.1f} MB)")


def analyze_emax_bank(disk_path: Path, cluster_start: int, cluster_count: int,
                      cluster_size: int = CLUSTER_SIZE, ca_offset: int = 0xC400) -> None:
    """
    Analysera en EMAX II bank på disk och skriv ut strukturinfo.
    cluster_start: 1-baserat cluster-nummer (EMAX II-konvention)
    """
    with open(disk_path, 'rb') as f:
        f.seek(ca_offset + (cluster_start - 1) * cluster_size)
        bank = f.read(cluster_size * cluster_count)

    print(f"=== Bank @ cluster {cluster_start} ({cluster_count} clusters) ===")
    print(f"Total size: {len(bank):,} bytes")

    # Hitta PCM-ände (zero-block)
    import re
    zeros = list(re.finditer(b'\x00{4096,}', bank))
    if zeros:
        pcm_end = zeros[0].start()
        meta_start = zeros[-1].end()
        print(f"PCM area: 0x0 - 0x{pcm_end:X} ({pcm_end:,} bytes)")
        print(f"Meta area: 0x{meta_start:X} - 0x{len(bank):X}")

    # Visa meta-start
    for region_off in [0xC8800, META_BLOCK_OFFSET]:
        if region_off < len(bank):
            print(f"\n@ 0x{region_off:X}: {bank[region_off:region_off+32].hex(' ')}")


# ──────────────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    import sys
    if len(sys.argv) > 1:
        p = Path(sys.argv[1])
        if p.suffix.upper() == '.SF2':
            analyze_sf2(p)
        else:
            print(f"Okänt format: {p.suffix}")
    else:
        sf2_dir = Path.home() / "clawd/emxp/EMAX2SF2/DISK_1"
        analyze_sf2(sf2_dir / "9FT GRAND.SF2")
