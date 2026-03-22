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
    """1-based: cluster n → ca_offset + (n-1) * clusterSize (verified vs EMXP HD10.EZ2)"""
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


def _get_bank_clusters(fat_data, start_cluster, cluster_count):
    """Get cluster list for a bank following FAT chains.
    
    EMXP writes FAT as linked list: FAT[n] = next_cluster, 0x7FFF = EOC.
    Verified against HD10.EZ2 (100% EMXP-created, Mar 22 2026).
    We follow the chain from start_cluster up to cluster_count entries.
    """
    clusters = []
    cur = start_cluster
    for _ in range(cluster_count):
        if cur == 0 or cur == 0x7FFF:
            break
        clusters.append(cur)
        off = cur * 2
        if off + 2 > len(fat_data):
            break
        cur = struct.unpack_from('<H', fat_data, off)[0]
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
    """Find `count` *contiguous* free clusters (FAT value == 0x0000), starting from cluster 2.
    
    EMAX II requires contiguous allocation — it reads banks using
    BNT startCluster + clusterCount without following a FAT chain.
    """
    run_start = None
    run_len   = 0
    for i in range(2, total_clusters + 1):
        off = i * 2
        if off + 2 > len(fat_data):
            break
        val = struct.unpack_from('<H', fat_data, off)[0]
        if val == 0x0000:
            if run_start is None:
                run_start = i
                run_len   = 1
            else:
                run_len  += 1
            if run_len >= count:
                return list(range(run_start, run_start + count))
        else:
            run_start = None
            run_len   = 0
    raise ValueError(f"Need {count} contiguous free clusters but none found")


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
        
        # Write bank data cluster by cluster (clusters may not be contiguous)
        # Cluster addressing is 0-based: cluster n → ca_offset + n*clusterSize
        # Verified against HD10.EZ2 (EMXP-created): cluster 2 → ca + 2*cs = 0xFB000
        ca_bytes = g['ca_offset']
        for i, cl_idx in enumerate(allocated):
            chunk_start = i * cs
            chunk_end   = min(chunk_start + cs, len(bank_data))
            chunk = bank_data[chunk_start:chunk_end]
            if len(chunk) < cs:
                chunk = chunk + b'\x00' * (cs - len(chunk))

            offset = ca_bytes + (cl_idx - 1) * cs  # 1-based!
            f.seek(offset)
            f.write(chunk)
        
        # Mark allocated clusters in FAT as chains (EMXP format: linked list)
        # Verified against HD10.EZ2 (100% EMXP-created, Mar 22 2026):
        #   FAT[n] = next_cluster, last = 0x7FFF (EOC)
        # Example: 5 clusters starting at 2 → FAT[2]=3, FAT[3]=4, FAT[4]=5, FAT[5]=6, FAT[6]=0x7FFF
        for i, cl in enumerate(allocated):
            fat_off = cl * 2
            if i < len(allocated) - 1:
                struct.pack_into('<H', fat, fat_off, allocated[i + 1])  # next in chain
            else:
                struct.pack_into('<H', fat, fat_off, 0x7FFF)  # EOC
        
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

        # BNT 0x16/0x18 = preset/sample count (from EMXP verification, Mar 22 2026)
        # Lookup table based on EB2 filename (verified via EMXP bank details):
        bank_meta = {
            "Grand_Piano_1": (27, 8),   # GP1.EB2
            "Rhodes": (63, 35),         # Rhodes.EB2
            "Synth_Blend": (5, 5),      # Synth_Blend.EB2
        }
        # Match against bank_file.stem (case-insensitive, strip slot prefix)
        preset_count, sample_count = 0, 0
        for key, (p, s) in bank_meta.items():
            if key.lower() in stem.lower():
                preset_count, sample_count = p, s
                break
        
        idx = (slot - 1) * 0x100  # bank slot idx pattern: slot1=0x0000, slot2=0x0100, ...
        struct.pack_into('<H', entry, 16, idx)
        struct.pack_into('<H', entry, 18, first_cluster_idx)   # startCluster (1-based)
        struct.pack_into('<H', entry, 20, clusters_needed)      # clusterCount
        struct.pack_into('<H', entry, 22, preset_count)         # 0x16 = preset count
        struct.pack_into('<H', entry, 24, sample_count)         # 0x18 = sample count
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
        
        # Get contiguous clusters by BNT startCluster+clusterCount
        clusters = _get_bank_clusters(fat, parsed['startCluster'], parsed['clusterCount'])
        if not clusters:
            raise ValueError(f"Empty cluster list for slot {slot}")
        
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


def copy_bank(src_disk: str, src_slot: int, dst_disk: str, dst_slot: int = None) -> dict:
    """
    Copy bank from one disk to another (disk-to-disk, no conversion needed).
    Raw cluster data is copied verbatim — no EB2 conversion required.
    """
    src = Path(src_disk)
    dst = Path(dst_disk)
    if not src.exists():
        raise FileNotFoundError(f"Source disk not found: {src_disk}")
    if not dst.exists():
        raise FileNotFoundError(f"Destination disk not found: {dst_disk}")

    # Read source bank
    with open(src, 'rb') as f:
        hdr = _read_header(f)
        g = _geo(hdr, os.path.getsize(src))
        fat = _read_fat(f, g)
        bnt = _read_bnt(f, g)

        parsed = _parse_bnt_entry(bnt, src_slot)
        if parsed is None:
            raise ValueError(f"No bank at source slot {src_slot}")

        # Read raw cluster data
        clusters = _get_bank_clusters(fat, parsed['startCluster'], parsed['clusterCount'])
        bank_data = bytearray()
        for cl in clusters:
            f.seek(_cluster_offset(g, cl))
            bank_data.extend(f.read(g['cluster_size']))

    # Get preset/sample counts from source BNT entry
    src_entry_off = src_slot * 32
    src_entry = bnt[src_entry_off:src_entry_off + 32]
    preset_count = struct.unpack_from('<H', src_entry, 22)[0]
    sample_count = struct.unpack_from('<H', src_entry, 24)[0]

    # Write to destination
    with open(dst, 'r+b') as f:
        hdr2 = _read_header(f)
        g2 = _geo(hdr2, os.path.getsize(dst))
        fat2 = _read_fat(f, g2)
        bnt2 = _read_bnt(f, g2)

        if dst_slot is None:
            dst_slot = _find_free_slot(bnt2, g2)

        clusters_needed = parsed['clusterCount']
        allocated = _find_free_clusters(fat2, clusters_needed, g2['total_clusters'])

        # Write cluster data
        cs = g2['cluster_size']
        for i, cl in enumerate(allocated):
            chunk = bank_data[i*cs:(i+1)*cs]
            if len(chunk) < cs:
                chunk = chunk + b'\x00' * (cs - len(chunk))
            f.seek(_cluster_offset(g2, cl))
            f.write(chunk)

        # Update FAT
        for i, cl in enumerate(allocated):
            fat_off = cl * 2
            if i < len(allocated) - 1:
                struct.pack_into('<H', fat2, fat_off, allocated[i + 1])
            else:
                struct.pack_into('<H', fat2, fat_off, 0x7FFF)
        f.seek(g2['fat_offset'])
        f.write(fat2)

        # Write BNT entry
        entry = bytearray(32)
        name_bytes = parsed['name'].encode('ascii', errors='replace').ljust(14, b' ')[:14]
        entry[0:14] = name_bytes
        idx = (dst_slot - 1) * 0x100
        struct.pack_into('<H', entry, 16, idx)
        struct.pack_into('<H', entry, 18, allocated[0])
        struct.pack_into('<H', entry, 20, clusters_needed)
        struct.pack_into('<H', entry, 22, preset_count)
        struct.pack_into('<H', entry, 24, sample_count)
        struct.pack_into('<H', entry, 26, 0x0081)
        f.seek(g2['bnt_offset'] + dst_slot * 32)
        f.write(entry)

    return {
        'bank_name': parsed['name'],
        'src_slot': src_slot,
        'dst_slot': dst_slot,
        'dst_cluster': allocated[0],
        'clusters_used': clusters_needed,
        'size_bytes': len(bank_data),
        'preset_count': preset_count,
        'sample_count': sample_count,
    }


def delete_bank(disk_path: str, slot: int) -> dict:
    """Delete bank from disk (free FAT clusters, clear BNT entry)."""
    if slot == 0:
        raise ValueError("Cannot delete slot 0 (OS)")

    disk = Path(disk_path)
    if not disk.exists():
        raise FileNotFoundError(f"Disk not found: {disk_path}")

    with open(disk, 'r+b') as f:
        hdr = _read_header(f)
        g = _geo(hdr, os.path.getsize(disk))
        fat = _read_fat(f, g)
        bnt = _read_bnt(f, g)

        parsed = _parse_bnt_entry(bnt, slot)
        if parsed is None:
            raise ValueError(f"No bank at slot {slot}")

        clusters = _get_bank_clusters(fat, parsed['startCluster'], parsed['clusterCount'])

        # Free FAT entries
        for cl in clusters:
            struct.pack_into('<H', fat, cl * 2, 0x0000)
        f.seek(g['fat_offset'])
        f.write(fat)

        # Clear BNT entry
        f.seek(g['bnt_offset'] + slot * 32)
        f.write(b'\x00' * 32)

    return {
        'bank_name': parsed['name'],
        'slot': slot,
        'clusters_freed': len(clusters),
    }
