"""
sample_extractor.py — Extract individual samples from EMAX II bank files as WAV/AIFF.

Supports:
  - .EB2 standalone bank files
  - .hda disk images (extract samples from a specific bank slot)
  - Output: WAV (default) or AIFF
  - Normalization (optional)
  - Per-sample metadata (name, rate, duration, size)

Implementation strategy:
  EMAX II banks have two regions:
    1. Preset/instrument headers (offsets 0x00–0x1FFFF) — unused here
    2. Sample data area (0x20000+) — 16-bit signed LE PCM at ~42kHz

  For EB2 files:
    - Sample parameter table at 0x10200 (if format == EMX/full RAM image)
    - Otherwise: entropy scan to find PCM start, emit as single "Full Bank" WAV

  We implement a pure-Python extractor here so the CLI harness has no Swift
  compilation dependency. The same logic mirrors EmaxIIParser in Swift.
"""

import struct
import math
import time
import wave
import os
import re
from pathlib import Path
from dataclasses import dataclass, field
from typing import List, Optional, Tuple


# ── EMAX II format constants ──────────────────────────────────────────────────
HEADER_SIZE         = 0x200        # Minimum valid bank data size
SAMPLE_PARAM_OFFSET = 0x10200      # EMX format: sample parameter table
SAMPLE_PARAM_SIZE   = 64           # Bytes per parameter block
SAMPLE_DATA_OFFSET  = 0x20000      # EMX format: raw PCM starts here
DEFAULT_SAMPLE_RATE = 42000        # EMAX II native rate (~42 kHz)
MAX_SAMPLE_PARAMS   = 64
BNT_OFFSET          = 0x1000
BNT_ENTRY_SIZE      = 32
BNT_MAX_SLOTS       = 100
CLUSTER_SIZE        = 489_472
CA_OFFSET           = 0xC400


@dataclass
class SampleEntry:
    index:       int
    name:        str
    pcm_data:    bytes
    sample_rate: int
    loop_start:  Optional[int] = None
    loop_end:    Optional[int] = None
    root_key:    int = 60

    @property
    def duration(self) -> float:
        return len(self.pcm_data) / 2 / self.sample_rate if self.sample_rate > 0 else 0.0

    @property
    def size_bytes(self) -> int:
        return len(self.pcm_data)


def _u16le(data, off):
    return struct.unpack_from('<H', data, off)[0]

def _u32le(data, off):
    return struct.unpack_from('<I', data, off)[0]

def _i16le(data, off):
    return struct.unpack_from('<h', data, off)[0]


# ── Bank format detection ─────────────────────────────────────────────────────

def _is_emx_format(data: bytes) -> bool:
    """
    EMX (full RAM image) has a valid sample param table at 0x10200.
    Each entry: non-zero start/end addresses within plausible range,
    reasonable sample rate.
    """
    if len(data) < SAMPLE_PARAM_OFFSET + SAMPLE_PARAM_SIZE:
        return False
    valid = 0
    for i in range(min(8, MAX_SAMPLE_PARAMS)):
        base = SAMPLE_PARAM_OFFSET + i * SAMPLE_PARAM_SIZE
        if base + SAMPLE_PARAM_SIZE > len(data):
            break
        start = _u32le(data, base)
        end   = _u32le(data, base + 4)
        rate  = _u16le(data, base + 8)
        if start == 0 and end == 0:
            continue
        if 0 < start < end < 0x800000 and 8000 < rate < 100000:
            valid += 1
    return valid >= 2


# ── EMX format: parameter table parsing ──────────────────────────────────────

def _parse_sample_params_emx(data: bytes) -> List[dict]:
    params = []
    for i in range(MAX_SAMPLE_PARAMS):
        base = SAMPLE_PARAM_OFFSET + i * SAMPLE_PARAM_SIZE
        if base + SAMPLE_PARAM_SIZE > len(data):
            break
        start      = _u32le(data, base)
        end        = _u32le(data, base + 4)
        rate       = _u16le(data, base + 8)
        loop_start = _u32le(data, base + 12)
        loop_end   = _u32le(data, base + 16)
        root_key   = data[base + 24] if base + 24 < len(data) else 60
        name_bytes = data[base + 32: base + 48]
        name       = name_bytes.split(b'\x00')[0].decode('ascii', errors='replace').strip()

        if start == 0 and end == 0:
            continue
        if not (0 < start < end < 0x800000 and 8000 < rate < 100_000):
            continue

        has_loop = (loop_end > loop_start > 0)
        params.append({
            'index':       i,
            'name':        name or f'Sample {i+1}',
            'start':       start,
            'end':         end,
            'rate':        rate,
            'loop_start':  loop_start if has_loop else None,
            'loop_end':    loop_end   if has_loop else None,
            'root_key':    root_key,
        })
    return params


def _extract_emx(data: bytes) -> List[SampleEntry]:
    params = _parse_sample_params_emx(data)
    pcm_area = data[SAMPLE_DATA_OFFSET:]
    entries = []

    for p in params:
        s, e = p['start'], p['end']
        if s < 0 or e > len(pcm_area) or e <= s:
            continue
        # Align to even byte
        if (e - s) % 2:
            e -= 1
        entries.append(SampleEntry(
            index=p['index'],
            name=p['name'],
            pcm_data=pcm_area[s:e],
            sample_rate=p['rate'],
            loop_start=p['loop_start'],
            loop_end=p['loop_end'],
            root_key=p['root_key'],
        ))

    if not entries and len(pcm_area) >= 4:
        entries.append(SampleEntry(
            index=0, name='Full Bank',
            pcm_data=pcm_area,
            sample_rate=DEFAULT_SAMPLE_RATE,
        ))
    return entries


# ── EB2 format: entropy scan ──────────────────────────────────────────────────

def _estimate_entropy(data: bytes, offset: int, length: int = 256) -> float:
    """Shannon entropy of a window."""
    window = data[offset: offset + length]
    if len(window) < 16:
        return 0.0
    counts = [0] * 256
    for b in window:
        counts[b] += 1
    n = len(window)
    ent = 0.0
    for c in counts:
        if c > 0:
            p = c / n
            ent -= p * math.log2(p)
    return ent


def _find_pcm_start_by_entropy(data: bytes, threshold: float = 6.0) -> Optional[int]:
    """
    Scan for the PCM data start in EB2 format.
    PCM (audio) has higher entropy than pure-zero headers.
    Starts at 0x200 (EB2 standard header size) — returns 0x200 if
    entropy there already exceeds the threshold (most banks).
    Falls back to scanning forward if 0x200 is pure header data.
    """
    # Always try 0x200 first — EMXP EB2 export has a 512-byte header block
    if len(data) > 0x200 + 256:
        if _estimate_entropy(data, 0x200) >= threshold:
            return 0x200

    # Fallback: scan forward for higher-entropy region
    step = 512
    for off in range(0x400, len(data) - 256, step):
        if _estimate_entropy(data, off) >= threshold:
            return (off // 512) * 512

    # Last resort: use 0x200
    return 0x200


def _extract_eb2(data: bytes, bank_name: str = '') -> List[SampleEntry]:
    """
    EB2 export: single WAV containing all PCM data.
    We attempt to detect the sample rate from the bank header.
    """
    # Try to read sample rate from known EB2 header field (0x10)
    rate = DEFAULT_SAMPLE_RATE
    if len(data) > 0x12:
        candidate = _u16le(data, 0x10)
        if 8000 < candidate < 100_000:
            rate = candidate

    pcm_start = _find_pcm_start_by_entropy(data)
    if pcm_start is None:
        pcm_start = 0x200   # Last-resort fallback

    pcm_data = data[pcm_start:]
    # Align to even bytes
    if len(pcm_data) % 2:
        pcm_data = pcm_data[:-1]

    name = bank_name or 'Full Bank'
    return [SampleEntry(index=0, name=name, pcm_data=pcm_data, sample_rate=rate)]


# ── Disk image: extract bank cluster data ─────────────────────────────────────

def _read_bank_from_disk(disk_path: str, slot: int) -> Optional[Tuple[bytes, str]]:
    """
    Read raw bank cluster data from a .hda disk image.
    Returns (data, bank_name) or None.
    """
    with open(disk_path, 'rb') as f:
        hdr = f.read(0x200)

    cluster_size = struct.unpack_from('<I', hdr, 0x04)[0] or CLUSTER_SIZE
    ca_start_sec = struct.unpack_from('<I', hdr, 0x20)[0]
    ca_offset    = ca_start_sec * 512 if ca_start_sec else CA_OFFSET

    # Read BNT entry
    bnt_off = BNT_OFFSET + slot * BNT_ENTRY_SIZE
    with open(disk_path, 'rb') as f:
        f.seek(bnt_off)
        bnt_entry = f.read(BNT_ENTRY_SIZE)

    if len(bnt_entry) < BNT_ENTRY_SIZE:
        return None

    name      = bnt_entry[:14].split(b'\x00')[0].decode('ascii', errors='replace').strip()
    flags     = struct.unpack_from('<H', bnt_entry, 26)[0]
    start_cl  = struct.unpack_from('<H', bnt_entry, 18)[0]
    cl_count  = struct.unpack_from('<H', bnt_entry, 20)[0]

    if not name or not (flags & 0x0001) or start_cl < 1 or cl_count < 1:
        return None

    # Read contiguous clusters (EMAX II uses contiguous allocation)
    cluster_offset = ca_offset + (start_cl - 1) * cluster_size
    total_bytes    = cl_count * cluster_size

    with open(disk_path, 'rb') as f:
        f.seek(cluster_offset)
        data = f.read(total_bytes)

    if len(data) < HEADER_SIZE:
        return None

    return (data, name)


# ── Main extract function ─────────────────────────────────────────────────────

def extract_samples(
    source_path: str,
    output_dir: str,
    fmt: str = 'wav',
    normalize: bool = False,
    slot: Optional[int] = None,
) -> dict:
    """
    Extract samples from an EB2 bank file or a disk image slot.

    Parameters:
      source_path — .EB2 bank file or .hda disk image
      output_dir  — directory to write WAV/AIFF files
      fmt         — 'wav' or 'aiff'
      normalize   — normalize PCM to full dynamic range
      slot        — required when source_path is a .hda disk image

    Returns dict with: success, files, total_samples, elapsed_ms
    """
    t0 = time.time()
    src = Path(source_path).expanduser()
    out = Path(output_dir).expanduser()

    if not src.exists():
        return {'success': False, 'error': f'File not found: {src}'}

    fmt = fmt.lower()
    if fmt not in ('wav', 'aiff'):
        return {'success': False, 'error': f'Unknown format: {fmt} (use wav or aiff)'}

    # ── Read bank data ────────────────────────────────────────────────────────
    bank_name = src.stem
    if src.suffix.lower() == '.hda':
        if slot is None:
            return {'success': False, 'error': '--slot is required for disk images'}
        result = _read_bank_from_disk(str(src), slot)
        if result is None:
            return {'success': False, 'error': f'No bank found in slot {slot}'}
        data, bank_name = result
    else:
        with open(src, 'rb') as f:
            data = f.read()
        # Strip slotN_ prefix from filename for cleaner bank name
        stem = re.sub(r'^slot\d+_', '', src.stem, flags=re.IGNORECASE)
        bank_name = stem.replace('_', ' ')

    # ── Parse samples ─────────────────────────────────────────────────────────
    if _is_emx_format(data):
        entries = _extract_emx(data)
    else:
        entries = _extract_eb2(data, bank_name=bank_name)

    if not entries:
        return {'success': False, 'error': 'No sample data found in bank'}

    # ── Write audio files ─────────────────────────────────────────────────────
    out.mkdir(parents=True, exist_ok=True)
    files = []

    for entry in entries:
        if not entry.pcm_data:
            continue
        if normalize:
            entry = _normalize_entry(entry)

        safe_name = _sanitize(entry.name)
        filename  = f'{entry.index + 1:02d}_{safe_name}.{fmt}'
        filepath  = out / filename

        if fmt == 'wav':
            _write_wav(entry, filepath)
        else:
            _write_aiff(entry, filepath)

        file_size = filepath.stat().st_size
        files.append({
            'name':        entry.name,
            'path':        str(filepath),
            'sample_rate': entry.sample_rate,
            'duration':    round(entry.duration, 3),
            'size_bytes':  file_size,
        })

    return {
        'success':       True,
        'bank_name':     bank_name,
        'total_samples': len(files),
        'format':        fmt.upper(),
        'output_dir':    str(out),
        'files':         files,
        'elapsed_ms':    int((time.time() - t0) * 1000),
    }


# ── Audio writing helpers ─────────────────────────────────────────────────────

def _write_wav(entry: SampleEntry, path: Path):
    """Write 16-bit mono WAV file (little-endian PCM)."""
    with wave.open(str(path), 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)    # 16-bit
        wf.setframerate(entry.sample_rate)
        wf.writeframes(entry.pcm_data)


def _write_aiff(entry: SampleEntry, path: Path):
    """Write 16-bit mono AIFF file (big-endian PCM)."""
    import struct as st
    pcm = entry.pcm_data
    # Byte-swap LE→BE
    be_pcm = bytearray(len(pcm))
    for i in range(0, len(pcm) - 1, 2):
        be_pcm[i]     = pcm[i + 1]
        be_pcm[i + 1] = pcm[i]

    num_frames = len(be_pcm) // 2
    sample_rate_bytes = _ieee754_extended(entry.sample_rate)

    comm_chunk  = b'COMM' + st.pack('>I', 18) + st.pack('>hIh', 1, num_frames, 16) + sample_rate_bytes
    ssnd_chunk  = b'SSND' + st.pack('>I', 8 + len(be_pcm)) + st.pack('>II', 0, 0) + be_pcm
    form_size   = 4 + len(comm_chunk) + len(ssnd_chunk)
    aiff_data   = b'FORM' + st.pack('>I', form_size) + b'AIFF' + comm_chunk + ssnd_chunk

    with open(path, 'wb') as f:
        f.write(aiff_data)


def _ieee754_extended(rate: int) -> bytes:
    """Encode sample rate as 80-bit IEEE 754 extended (AIFF requirement)."""
    import struct as st
    if rate == 0:
        return b'\x00' * 10
    sign = 0
    if rate < 0:
        sign = 0x8000
        rate = -rate
    exponent = int(math.floor(math.log2(rate))) + 16383
    mantissa = int(rate * (2 ** (63 - int(math.floor(math.log2(rate))))))
    return st.pack('>HQ', sign | exponent, mantissa)


def _normalize_entry(entry: SampleEntry) -> SampleEntry:
    """Scale PCM so peak = 32767."""
    data = entry.pcm_data
    if len(data) < 2:
        return entry
    frames = len(data) // 2
    samples = struct.unpack_from(f'<{frames}h', data)
    peak = max(abs(s) for s in samples) if samples else 0
    if peak == 0 or peak >= 32700:
        return entry
    scale = 32767.0 / peak
    scaled = [max(-32768, min(32767, int(s * scale))) for s in samples]
    new_data = struct.pack(f'<{frames}h', *scaled)
    return SampleEntry(
        index=entry.index, name=entry.name, pcm_data=new_data,
        sample_rate=entry.sample_rate,
        loop_start=entry.loop_start, loop_end=entry.loop_end,
        root_key=entry.root_key,
    )


def _sanitize(name: str) -> str:
    safe = re.sub(r'[/\\:*?"<>|]', '_', name.strip())
    return safe or 'untitled'
