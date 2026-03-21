"""
bank_renamer.py — Rename a bank directly in the BNT of an EMAX II disk image.

EMXP has no rename feature — you'd have to export + reimport.
This edits the 14-byte name field in the BNT entry in-place.
"""

import struct
from pathlib import Path


BNT_OFFSET     = 0x1000
BNT_ENTRY_SIZE = 32
BNT_MAX_SLOTS  = 100
MAX_NAME_LEN   = 14


def _u16(data, off):
    return struct.unpack_from('<H', data, off)[0]


def _find_bank(data, name: str):
    """Find bank by name (case-insensitive). Returns slot index or None."""
    target = name.lower().strip()
    for s in range(BNT_MAX_SLOTS):
        off = BNT_OFFSET + s * BNT_ENTRY_SIZE
        if off + BNT_ENTRY_SIZE > len(data):
            break
        raw   = data[off: off + 14]
        bname = raw.split(b'\x00')[0].decode('ascii', errors='replace').strip()
        flags = _u16(data, off + 26)
        if bname.lower() == target and (flags & 0x0001):
            return s
    return None


def _name_exists(data, name: str, exclude_slot: int = -1) -> bool:
    """Check if a bank name already exists on disk."""
    target = name.lower().strip()
    for s in range(BNT_MAX_SLOTS):
        if s == exclude_slot:
            continue
        off = BNT_OFFSET + s * BNT_ENTRY_SIZE
        if off + BNT_ENTRY_SIZE > len(data):
            break
        raw   = data[off: off + 14]
        bname = raw.split(b'\x00')[0].decode('ascii', errors='replace').strip()
        flags = _u16(data, off + 26)
        if bname.lower() == target and (flags & 0x0001):
            return True
    return False


def rename_bank(disk_path: str, old_name: str, new_name: str) -> dict:
    """
    Rename a bank in-place on the disk image.

    - old_name: current bank name (case-insensitive match)
    - new_name: new name, truncated to 14 chars

    Returns dict with success, slot, old_name, new_name.
    """
    disk = Path(disk_path).expanduser()
    if not disk.exists():
        return {'success': False, 'error': f'Disk not found: {disk}'}

    new_name_clean = new_name.strip()[:MAX_NAME_LEN]
    if not new_name_clean:
        return {'success': False, 'error': 'New name cannot be empty'}

    with open(disk, 'rb') as f:
        data = bytearray(f.read())

    slot = _find_bank(data, old_name)
    if slot is None:
        return {'success': False, 'error': f'Bank "{old_name}" not found on disk'}

    # Check new name not already taken (excluding current slot)
    if _name_exists(data, new_name_clean, exclude_slot=slot):
        return {'success': False,
                'error': f'Bank "{new_name_clean}" already exists on disk'}

    # Write new name — 14 bytes, space-padded, null-terminated at end
    off = BNT_OFFSET + slot * BNT_ENTRY_SIZE
    name_bytes = new_name_clean.encode('ascii', errors='replace')
    name_bytes = name_bytes[:14].ljust(14, b'\x00')
    data[off: off + 14] = name_bytes

    with open(disk, 'wb') as f:
        f.write(data)

    return {
        'success':  True,
        'slot':     slot,
        'old_name': old_name.strip(),
        'new_name': new_name_clean,
    }


def list_banks_summary(disk_path: str) -> list:
    """Return list of (slot, name) for all active banks."""
    disk = Path(disk_path).expanduser()
    if not disk.exists():
        return []
    with open(disk, 'rb') as f:
        data = f.read()
    banks = []
    for s in range(1, BNT_MAX_SLOTS):   # skip slot 0 (OS)
        off = BNT_OFFSET + s * BNT_ENTRY_SIZE
        if off + BNT_ENTRY_SIZE > len(data):
            break
        raw   = data[off: off + 14]
        name  = raw.split(b'\x00')[0].decode('ascii', errors='replace').strip()
        flags = _u16(data, off + 26)
        if name and (flags & 0x0001):
            banks.append((s, name))
    return banks
