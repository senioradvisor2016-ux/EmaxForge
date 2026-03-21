"""Bank operations for EmaxForge CLI

Verified EMAX II disk layout (Mar 18 2026):
  Header:   sector 0 (512 bytes), magic="EMX2"
  FAT:      ALWAYS at 0x400 (NOT header[0x0C]*512!)
  BNT:      header[0x10]*512 (32-byte entries, NOT 64!)
  Clusters: 1-based — cluster n → ca_off + (n-1) * clusterSize
  
Header fields:
  0x04: clusterSize (UInt32LE, raw bytes)
  0x10: bntStartSector (UInt32LE)
  0x14: maxBanks (UInt32LE)
  0x1C: fatSectors (UInt32LE)
  0x20: clusterAreaStartSector (UInt32LE)
  0x24: totalClusters (UInt32LE)

BNT entry (32 bytes):
  [0-13]:  name (ASCII, space-padded)
  [14-15]: padding/null
  [16-17]: idx (slot_index * 0x100; OS = 0x7800)
  [18-19]: startCluster (UInt16LE)
  [20-21]: clusterCount (UInt16LE)
  [22-23]: f22 (UInt16LE, set to 0 on import)
  [24-25]: f24 (UInt16LE, set to 0 on import)
  [26-27]: flags (UInt16LE, 0x0081 = active)
  [28-31]: zeros
"""

import os
import struct
from pathlib import Path


def _read_header(f):
    """Read and parse EMAX II disk header."""
    f.seek(0)
    header = f.read(512)
    if len(header) < 0x28:
        raise ValueError("File too small for EMAX II header")
    
    magic = header[0:4]
    if magic != b'EMX2':
        raise ValueError(f"Not an EMAX II image (magic: {magic!r})")
    
    return {
        'clusterSize':    struct.unpack_from('<I', header, 0x04)[0],
        'bntStartSector': struct.unpack_from('<I', header, 0x10)[0],
        'maxBanks':       struct.unpack_from('<I', header, 0x14)[0],
        'fatSectors':     struct.unpack_from('<I', header, 0x1C)[0],
        'caStartSector':  struct.unpack_from('<I', header, 0x20)[0],
        'totalClusters':  struct.unpack_from('<I', header, 0x24)[0],
    }


def _geo(hdr, disk_size_bytes):
    """Compute derived geometry.

    cluster_size is at header offset 0x04 (U32LE, raw bytes).
    Verified for 239 MB disk: 0x04 = 489472 bytes = 478 KB/cluster.
    """
    fat_offset   = 0x400   # FAT always starts at 0x400
    fat_size     = hdr['fatSectors'] * 512
    bnt_offset   = hdr['bntStartSector'] * 512
    ca_offset    = hdr['caStartSector'] * 512
    bnt_size     = ca_offset - bnt_offset
    max_slots    = min(hdr['maxBanks'] + 1, bnt_size // 32)
    cluster_size = hdr['clusterSize']  # directly from header[0x04]

    if cluster_size == 0 or cluster_size > 0x200000:
        raise ValueError(f"Invalid cluster size from header: {cluster_size}")

    total_clusters = hdr['totalClusters']
    sects_per_cluster = cluster_size // 512

    return {
        'fat_offset':        fat_offset,
        'fat_size':          fat_size,
        'bnt_offset':        bnt_offset,
        'bnt_size':          bnt_size,
        'ca_offset':         ca_offset,
        'max_slots':         max_slots,
        'cluster_size':      cluster_size,
        'sects_per_cluster': sects_per_cluster,
        'total_clusters':    total_clusters,
    }


def _cluster_offset(geo, cluster_num):
    """1-based: cluster n → ca_offset + (n-1) * clusterSize"""
    return geo['ca_offset'] + (cluster_num - 1) * geo['cluster_size']


def _read_fat(f, geo):
    """Read entire FAT."""
    f.seek(geo['fat_offset'])
    return bytearray(f.read(geo['fat_size']))


def _read_bnt(f, geo):
    """Read entire BNT."""
    f.seek(geo['bnt_offset'])
    return bytearray(f.read(geo['bnt_size']))


def _parse_bnt_entry(bnt_data, slot):
    """Parse a single 32-byte BNT entry."""
    off = slot * 32
    if off + 32 > len(bnt_data):
        return None
    entry = bnt_data[off:off + 32]
    if all(b == 0 for b in entry):
        return None
    if all(b == 0xFF for b in entry):
        return None
    
    # Verified BNT entry offsets (32 bytes, against HD10.hda Mar 2026):
    # name is 14 bytes, SPACE-padded (not null-padded!)
    name = entry[0:14].decode('ascii', errors='replace').rstrip('\x00 ')
    return {
        'name':         name,
        'idx':          struct.unpack_from('<H', entry, 16)[0],
        'startCluster': struct.unpack_from('<H', entry, 18)[0],
        'clusterCount': struct.unpack_from('<H', entry, 20)[0],
        'f22':          struct.unpack_from('<H', entry, 22)[0],
        'f24':          struct.unpack_from('<H', entry, 24)[0],
        'flags':        struct.unpack_from('<H', entry, 26)[0],
    }


def _follow_fat_chain(fat_data, start_cluster, max_entries=10000):
    """Follow FAT chain, return list of cluster numbers."""
    clusters = []
    current = start_cluster
    visited = set()
    
    while current > 0 and current * 2 + 2 <= len(fat_data) and len(clusters) < max_entries:
        if current in visited:
            break  # loop
        visited.add(current)
        clusters.append(current)
        
        nxt = struct.unpack_from('<H', fat_data, current * 2)[0]
        if nxt == 0x7FFF or nxt == 0xFFFF:  # end-of-chain
            break
        if nxt == 0x0000:  # free (broken chain)
            break
        if nxt == 0x8000:  # reserved
            break
        current = nxt
    
    return clusters


def _find_free_slot(bnt_data, geo):
    """Find first free BNT slot (skip slot 0 = OS)."""
    for i in range(1, geo['max_slots']):
        off = i * 32
        if off + 32 > len(bnt_data):
            break
        entry = bnt_data[off:off + 32]
        if all(b == 0 for b in entry) or all(b == 0xFF for b in entry):
            return i
    raise ValueError("No free BNT slots available")


def _find_free_clusters(fat_data, count, total_clusters):
    """Find `count` free clusters (FAT value == 0x0000), starting from cluster 2."""
    free = []
    for i in range(2, total_clusters + 1):
        off = i * 2
        if off + 2 > len(fat_data):
            break
        val = struct.unpack_from('<H', fat_data, off)[0]
        if val == 0x0000:
            free.append(i)
            if len(free) >= count:
                return free
    raise ValueError(f"Need {count} free clusters but only found {len(free)}")


# ============ PUBLIC API ============

def import_bank(disk_path: str, bank_path: str, slot: int = None) -> dict:
    """Import .EB2 bank into disk image."""
    disk = Path(disk_path)
    bank_file = Path(bank_path)
    
    if not disk.exists():
        raise FileNotFoundError(f"Disk not found: {disk_path}")
    if not bank_file.exists():
        raise FileNotFoundError(f"Bank not found: {bank_path}")
    
    bank_data = bank_file.read_bytes()
    # Derive bank name from filename.
    # Strip leading "slotN_" prefix if present (e.g. "slot1_STEEL_DRUMS" → "STEEL_DRUMS")
    import re as _re
    stem = bank_file.stem
    stem = _re.sub(r'^slot\d+_', '', stem, flags=_re.IGNORECASE)
    # Preserve original case from filename (underscores → spaces), truncate to 14 chars
    bank_name = stem.replace("_", " ")[:14]
    
    with open(disk, 'r+b') as f:
        hdr = _read_header(f)
        disk_size = os.path.getsize(disk)
        g = _geo(hdr, disk_size)
        fat = _read_fat(f, g)
        bnt = _read_bnt(f, g)
        
        # Find slot
        if slot is None:
            slot = _find_free_slot(bnt, g)
        
        # EMAX II BNT layout (verified against EmaxII-02.ez2, Mar 19 2026):
        #   startCluster = first_sector_rel_to_ca (pre-scaled: cluster_idx * sects_per_cluster)
        #   sectorCount  = SIZE IN SECTORS (not clusters!)
        # Hardware formula: byte_off = ca_bytes + startCluster * 512
        #                   size      = sectorCount * 512
        # FAT is used for free/used tracking but NOT chained reads (contiguous only)
        
        cs = g['cluster_size']
        clusters_needed = (len(bank_data) + cs - 1) // cs
        sectors_needed  = (len(bank_data) + 511) // 512  # ACTUAL sector count
        
        # Find contiguous run of free clusters
        allocated = _find_free_clusters(fat, clusters_needed, g['total_clusters'])
        first_cluster_idx = allocated[0]
        
        # Write bank data contiguously
        # Cluster addressing is 1-based: cluster n → ca_offset + (n-1)*clusterSize
        ca_bytes = g['ca_offset']
        for i in range(clusters_needed):
            chunk_start = i * cs
            chunk_end   = min(chunk_start + cs, len(bank_data))
            chunk = bank_data[chunk_start:chunk_end]
            if len(chunk) < cs:
                chunk = chunk + b'\x00' * (cs - len(chunk))

            cl_idx = first_cluster_idx + i
            offset = ca_bytes + (cl_idx - 1) * cs  # 1-based!
            f.seek(offset)
            f.write(chunk)
        
        # Mark FAT entries as used
        for i, cl in enumerate(allocated):
            fat_off = cl * 2
            if i < len(allocated) - 1:
                struct.pack_into('<H', fat, fat_off, allocated[i + 1])
            else:
                struct.pack_into('<H', fat, fat_off, 0x7FFF)
        
        f.seek(g['fat_offset'])
        f.write(fat)
        
        # BNT entry (32 bytes) — verified against HD10.hda (EMXP-created, Mar 2026):
        #   [0-13]:  name (14 bytes ASCII, SPACE-padded — NOT null!)
        #   [14-15]: zeros
        #   [16-17]: idx (U16LE): (slot-1)*0x100 for banks; 0x7800 for OS
        #   [18-19]: startCluster (U16LE, 1-based)
        #   [20-21]: clusterCount (U16LE)
        #   [22-23]: f22 (U16LE, 0 on import — EMAX II writes runtime state here)
        #   [24-25]: f24 (U16LE, 0 on import)
        #   [26-27]: flags (U16LE, 0x0081 = active bank)
        #   [28-31]: zeros
        entry = bytearray(32)
        name_bytes = bank_name.encode('ascii', errors='replace').ljust(14, b' ')[:14]
        entry[0:14] = name_bytes
        # 14-15: zeros (already)

        idx = (slot - 1) * 0x100  # bank slot idx pattern: slot1=0x0000, slot2=0x0100, ...
        struct.pack_into('<H', entry, 16, idx)
        struct.pack_into('<H', entry, 18, first_cluster_idx)   # startCluster (1-based)
        struct.pack_into('<H', entry, 20, clusters_needed)      # clusterCount
        struct.pack_into('<H', entry, 22, 0)                    # f22 = 0 (EMAX II updates this)
        struct.pack_into('<H', entry, 24, 0)                    # f24 = 0 (EMAX II updates this)
        struct.pack_into('<H', entry, 26, 0x0081)               # flags = active bank
        # 28-31: zeros (already)
        
        bnt_entry_offset = g['bnt_offset'] + (slot * 32)
        f.seek(bnt_entry_offset)
        f.write(entry)
    
    return {
        "bank_name": bank_name.strip(),
        "slot": slot,
        "cluster": allocated[0],
        "size_bytes": len(bank_data),
        "clusters_used": clusters_needed,
    }


def list_banks(disk_path: str) -> dict:
    """List all banks on disk."""
    disk = Path(disk_path)
    if not disk.exists():
        raise FileNotFoundError(f"Disk not found: {disk_path}")
    
    banks = []
    
    with open(disk, 'rb') as f:
        hdr = _read_header(f)
        disk_size = os.path.getsize(disk)
        g = _geo(hdr, disk_size)
        bnt = _read_bnt(f, g)
        
        for i in range(g['max_slots']):
            parsed = _parse_bnt_entry(bnt, i)
            if parsed is None:
                continue  # skip empty slots (don't break — gaps allowed!)
            if parsed['flags'] != 0x0081:
                continue
            
            banks.append({
                "slot": i,
                "name": parsed['name'],
                "index": f"0x{parsed['idx']:04X}",
                "cluster": parsed['startCluster'],
                "presets": parsed['clusterCount'],  # display as "presets" for compat
                "flags": f"0x{parsed['flags']:04X}",
            })
    
    return {
        "disk_path": str(disk),
        "count": len(banks),
        "banks": banks,
    }


def export_bank(disk_path: str, slot: int, output_path: str) -> dict:
    """Export bank from disk to .EB2 file."""
    disk = Path(disk_path)
    output = Path(output_path)
    
    if not disk.exists():
        raise FileNotFoundError(f"Disk not found: {disk_path}")
    
    with open(disk, 'rb') as f:
        hdr = _read_header(f)
        disk_size = os.path.getsize(disk)
        g = _geo(hdr, disk_size)
        bnt = _read_bnt(f, g)
        fat = _read_fat(f, g)
        
        # Parse target BNT entry
        parsed = _parse_bnt_entry(bnt, slot)
        if parsed is None:
            raise ValueError(f"No bank at slot {slot}")
        
        # Follow FAT chain
        clusters = _follow_fat_chain(fat, parsed['startCluster'])
        if not clusters:
            raise ValueError(f"Empty FAT chain for slot {slot}")
        
        # Read cluster data (1-based)
        bank_data = bytearray()
        for cl in clusters:
            offset = _cluster_offset(g, cl)
            f.seek(offset)
            chunk = f.read(g['cluster_size'])
            bank_data.extend(chunk)
    
    # Write output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(bank_data)
    
    return {
        "bank_name": parsed['name'],
        "output_path": str(output),
        "size_bytes": len(bank_data),
        "clusters_used": len(clusters),
        "slot": slot,
    }
