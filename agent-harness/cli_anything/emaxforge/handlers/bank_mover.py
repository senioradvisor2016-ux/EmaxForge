"""
bank_mover.py — Move or copy a bank directly between two EMAX II disk images.

No EB2 intermediate file needed. Reads cluster data from source disk,
writes it to destination disk, updates BNT on both disks.

Modes:
  copy  — bank stays on source, appears on destination
  move  — bank removed from source after successful copy
"""

import struct
import time
from pathlib import Path


# ── Disk layout constants ────────────────────────────────────────────────────
FAT_OFFSET     = 0x0200
FAT_END        = 0x1000
BNT_OFFSET     = 0x1000
BNT_ENTRY_SIZE = 32
BNT_MAX_SLOTS  = 100
CLUSTER_SIZE   = 489_472   # fallback


def _u16(data, off):
    return struct.unpack_from('<H', data, off)[0]


def _u32(data, off):
    return struct.unpack_from('<I', data, off)[0]


def _w16(data, off, val):
    struct.pack_into('<H', data, off, val)


def _parse_header(data):
    cluster_size = _u32(data, 0x04) or CLUSTER_SIZE
    ca_start_sec = _u32(data, 0x20)
    total_clusters = _u32(data, 0x24)
    ca_offset = ca_start_sec * 512 if ca_start_sec else 0xC400
    return cluster_size, ca_offset, total_clusters


def _parse_fat(data):
    return bytearray(data[FAT_OFFSET:FAT_END])


def _fat_get(fat_bytes, idx):
    return struct.unpack_from('<H', fat_bytes, idx * 2)[0]


def _fat_set(fat_bytes, idx, val):
    struct.pack_into('<H', fat_bytes, idx * 2, val)


def _follow_chain(fat_bytes, start):
    chain, visited = [], set()
    cur = start
    while True:
        if cur in visited or cur < 1:
            break
        n = _fat_get(fat_bytes, cur)
        chain.append(cur)
        visited.add(cur)
        if n == 0x0000 or n >= 0x7F00:
            break
        cur = n
    return chain


def _find_bank_by_name(data, name: str):
    """Return (slot, start_cluster, cluster_count) or None."""
    name_lower = name.lower().strip()
    for s in range(BNT_MAX_SLOTS):
        off = BNT_OFFSET + s * BNT_ENTRY_SIZE
        if off + BNT_ENTRY_SIZE > len(data):
            break
        raw = data[off: off + 14]
        bname = raw.split(b'\x00')[0].decode('ascii', errors='replace').strip()
        if bname.lower() == name_lower:
            start_cl   = _u16(data, off + 18)
            cl_count   = _u16(data, off + 20)
            flags      = _u16(data, off + 26)
            if flags & 0x0001:
                return s, start_cl, cl_count
    return None


def _find_free_bnt_slot(data):
    """Return index of first empty BNT slot (name == empty and flags == 0)."""
    for s in range(1, BNT_MAX_SLOTS):   # slot 0 = OS, skip
        off = BNT_OFFSET + s * BNT_ENTRY_SIZE
        if off + BNT_ENTRY_SIZE > len(data):
            break
        raw  = data[off: off + 14]
        name = raw.split(b'\x00')[0].decode('ascii', errors='replace').strip()
        flags = _u16(data, off + 26)
        if not name and flags == 0:
            return s
    return None


def _find_free_clusters(fat_bytes, total_clusters, count_needed):
    """Return list of `count_needed` free cluster indices, or None if not enough."""
    free = []
    for i in range(1, total_clusters + 1):
        if _fat_get(fat_bytes, i) == 0x0000:
            free.append(i)
            if len(free) == count_needed:
                return free
    return None


def _write_fat_chain(fat_bytes, clusters):
    """Link clusters as a FAT chain ending with EOC (0x7FFF)."""
    for i, cl in enumerate(clusters):
        nxt = clusters[i + 1] if i + 1 < len(clusters) else 0x7FFF
        _fat_set(fat_bytes, cl, nxt)


def _clear_fat_chain(fat_bytes, clusters):
    """Zero out all clusters in chain (mark free)."""
    for cl in clusters:
        _fat_set(fat_bytes, cl, 0x0000)


def _write_bnt_entry(data, slot, name: str, start_cluster, cluster_count, slot_idx):
    """Write a 32-byte BNT entry."""
    off = BNT_OFFSET + slot * BNT_ENTRY_SIZE
    # Clear slot
    data[off: off + BNT_ENTRY_SIZE] = b'\x00' * BNT_ENTRY_SIZE
    # Name: up to 14 bytes, space-padded
    name_bytes = name[:14].encode('ascii', errors='replace').ljust(14, b' ')
    data[off: off + 14] = name_bytes
    # idx (slot * 0x100)
    _w16(data, off + 16, slot_idx * 0x100)
    # start cluster
    _w16(data, off + 18, start_cluster)
    # cluster count
    _w16(data, off + 20, cluster_count)
    # f22, f24 = 0
    _w16(data, off + 22, 0)
    _w16(data, off + 24, 0)
    # flags = 0x0081 (active)
    _w16(data, off + 26, 0x0081)


def _clear_bnt_entry(data, slot):
    """Zero out a BNT entry (marks slot free)."""
    off = BNT_OFFSET + slot * BNT_ENTRY_SIZE
    data[off: off + BNT_ENTRY_SIZE] = b'\x00' * BNT_ENTRY_SIZE


def move_bank(
    src_path: str,
    dst_path: str,
    bank_name: str,
    mode: str = 'copy',          # 'copy' | 'move'
    dst_bank_name: str = None,   # rename on destination (optional)
) -> dict:
    """
    Copy or move a bank from src_path to dst_path.

    mode='copy': bank stays on source
    mode='move': bank removed from source after copy

    Returns dict with status, slot, elapsed_ms.
    """
    t0 = time.time()

    src = Path(src_path).expanduser()
    dst = Path(dst_path).expanduser()

    if not src.exists():
        return {'success': False, 'error': f'Source disk not found: {src}'}
    if not dst.exists():
        return {'success': False, 'error': f'Destination disk not found: {dst}'}

    # ── Read source ──────────────────────────────────────────────────────────
    with open(src, 'rb') as f:
        src_data = bytearray(f.read())

    src_cluster_size, src_ca_offset, src_total = _parse_header(src_data)
    src_fat = _parse_fat(src_data)

    # Find bank on source
    found = _find_bank_by_name(src_data, bank_name)
    if not found:
        return {'success': False,
                'error': f'Bank "{bank_name}" not found on source disk'}

    src_slot, start_cl, cl_count = found

    # Extract cluster chain from source
    chain = _follow_chain(src_fat, start_cl)
    if not chain:
        return {'success': False,
                'error': f'Bank "{bank_name}": empty or broken FAT chain'}

    # Read raw cluster data
    cluster_data = []
    for cl in chain:
        off = src_ca_offset + (cl - 1) * src_cluster_size
        end = off + src_cluster_size
        if end > len(src_data):
            return {'success': False,
                    'error': f'Cluster {cl} out of bounds in source disk'}
        cluster_data.append(bytes(src_data[off:end]))

    # ── Read destination ─────────────────────────────────────────────────────
    with open(dst, 'rb') as f:
        dst_data = bytearray(f.read())

    dst_cluster_size, dst_ca_offset, dst_total = _parse_header(dst_data)
    dst_fat = _parse_fat(dst_data)

    if dst_cluster_size != src_cluster_size:
        return {'success': False,
                'error': f'Cluster size mismatch: src={src_cluster_size}, dst={dst_cluster_size}'}

    # Check bank name not already on destination
    target_name = (dst_bank_name or bank_name)[:14]
    if _find_bank_by_name(dst_data, target_name):
        return {'success': False,
                'error': f'Bank "{target_name}" already exists on destination disk'}

    # Find free BNT slot on destination
    dst_slot = _find_free_bnt_slot(dst_data)
    if dst_slot is None:
        return {'success': False, 'error': 'Destination disk: no free BNT slots'}

    # Find free clusters on destination
    free_cls = _find_free_clusters(dst_fat, dst_total, len(chain))
    if free_cls is None:
        return {'success': False,
                'error': f'Destination disk full: need {len(chain)} clusters, not enough free'}

    # ── Write cluster data to destination ────────────────────────────────────
    for i, (cl, data_chunk) in enumerate(zip(free_cls, cluster_data)):
        off = dst_ca_offset + (cl - 1) * dst_cluster_size
        dst_data[off: off + dst_cluster_size] = data_chunk

    # Update destination FAT chain
    _write_fat_chain(dst_fat, free_cls)
    dst_data[FAT_OFFSET:FAT_END] = dst_fat

    # Write destination BNT entry
    _write_bnt_entry(dst_data, dst_slot, target_name,
                     free_cls[0], len(free_cls), dst_slot)

    # Save destination
    with open(dst, 'wb') as f:
        f.write(dst_data)

    # ── If move mode: remove from source ─────────────────────────────────────
    if mode == 'move':
        _clear_fat_chain(src_fat, chain)
        src_data[FAT_OFFSET:FAT_END] = src_fat
        _clear_bnt_entry(src_data, src_slot)
        with open(src, 'wb') as f:
            f.write(src_data)

    elapsed = int((time.time() - t0) * 1000)
    return {
        'success':       True,
        'mode':          mode,
        'bank_name':     bank_name,
        'dst_bank_name': target_name,
        'src_slot':      src_slot,
        'dst_slot':      dst_slot,
        'clusters':      len(chain),
        'elapsed_ms':    elapsed,
    }
