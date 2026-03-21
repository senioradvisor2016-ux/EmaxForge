"""
EMAX II Disk Catalog Parser
Parses catalog entries from disk images

Verified EMAX II disk layout (confirmed Mar 2026):
  Header sector 0 (512 bytes):
    0x04: clusterSize (U32LE, bytes directly — e.g. 489472 for 239 MB)
    0x08: fatSectors (U32LE)
    0x10: bntStartSector (U32LE)
    0x14: maxBanks (U32LE)
    0x20: caStartSector (U32LE)

  BNT: bntStartSector * 512, 32 bytes/entry:
    [0-11]:  name (ASCII, null/space-padded)
    [12-17]: padding
    [18-19]: startCluster (U16LE) — 1-based cluster index
    [20-21]: clusterCount (U16LE)
    [22-23]: f22 (U16LE)
    [24-25]: f24 (U16LE)
    [26-27]: flags (U16LE, 0x0081 = active bank, 0x7800 = OS)
    [28-31]: zeros

  Cluster addressing (1-based):
    byte_offset = caStartSector*512 + (cluster-1)*clusterSize
"""

import struct
from pathlib import Path
from typing import List, Dict, Any, Optional


def _read_emax_header(disk_path: str) -> dict:
    """Read and parse EMAX II disk header (sector 0)."""
    with open(disk_path, 'rb') as f:
        hdr = f.read(512)

    if len(hdr) < 0x28:
        raise ValueError("File too small for EMAX II header")

    return {
        'clusterSize':    struct.unpack_from('<I', hdr, 0x04)[0],
        'fatSectors':     struct.unpack_from('<I', hdr, 0x08)[0],
        'bntStartSector': struct.unpack_from('<I', hdr, 0x10)[0],
        'maxBanks':       struct.unpack_from('<I', hdr, 0x14)[0],
        'caStartSector':  struct.unpack_from('<I', hdr, 0x20)[0],
    }


class CatalogEntry:
    """Single BNT catalog entry (OS or bank) — 32 bytes."""

    def __init__(self, index: int, data: bytes, cluster_size: int = 489472):
        self.index = index
        self.raw_data = data
        self._cluster_size = cluster_size

        # Verified offsets (32-byte BNT entry)
        self.name          = data[0:12].rstrip(b'\x00 ').decode('ascii', errors='replace').strip()
        self.start_cluster = struct.unpack_from('<H', data, 18)[0]
        self.cluster_count = struct.unpack_from('<H', data, 20)[0]
        self.f22           = struct.unpack_from('<H', data, 22)[0]
        self.f24           = struct.unpack_from('<H', data, 24)[0]
        self.flags         = struct.unpack_from('<H', data, 26)[0]

        # Derived
        self.is_active = self.flags in (0x0081, 0x7800) and self.start_cluster > 0
        self.is_os     = self.flags == 0x7800
        self.is_empty  = self.start_cluster == 0 or all(b == 0 for b in data)

    def size_bytes(self, cluster_size: int = None) -> int:
        cs = cluster_size or self._cluster_size
        return self.cluster_count * cs

    def size_mb(self, cluster_size: int = None) -> float:
        return self.size_bytes(cluster_size) / (1024 * 1024)

    def to_dict(self, cluster_size: int = None) -> Dict[str, Any]:
        cs = cluster_size or self._cluster_size
        return {
            "index":         self.index,
            "name":          self.name,
            "start_cluster": self.start_cluster,
            "cluster_count": self.cluster_count,
            "size_bytes":    self.size_bytes(cs),
            "size_mb":       round(self.size_mb(cs), 2),
            "flags":         f"0x{self.flags:04X}",
            "is_active":     self.is_active,
            "is_os":         self.is_os,
            "is_empty":      self.is_empty,
        }


class CatalogParser:
    """Parse EMAX II disk catalog (BNT)."""

    ENTRY_SIZE = 32  # verified: 32 bytes per BNT slot

    @staticmethod
    def _get_geometry(disk_path: str) -> dict:
        hdr = _read_emax_header(disk_path)
        return {
            'cluster_size': hdr['clusterSize'],
            'bnt_offset':   hdr['bntStartSector'] * 512,
            'ca_offset':    hdr['caStartSector'] * 512,
            'max_slots':    hdr['maxBanks'] + 1,  # +1 for OS slot
        }

    @staticmethod
    def get_cluster_size(disk_path: str) -> int:
        """Get cluster size from header offset 0x04 (U32LE, bytes)."""
        hdr = _read_emax_header(disk_path)
        cs = hdr['clusterSize']
        if cs == 0 or cs > 0x200000:
            raise ValueError(f"Unexpected cluster size: {cs}")
        return cs

    @staticmethod
    def parse(disk_path: str) -> List[CatalogEntry]:
        """Parse all BNT entries from disk."""
        path = Path(disk_path)
        if not path.exists():
            raise FileNotFoundError(f"Disk not found: {disk_path}")

        geo = CatalogParser._get_geometry(disk_path)
        cs  = geo['cluster_size']
        entries = []

        with open(path, 'rb') as f:
            f.seek(geo['bnt_offset'])
            for i in range(geo['max_slots']):
                data = f.read(CatalogParser.ENTRY_SIZE)
                if len(data) < CatalogParser.ENTRY_SIZE:
                    break
                entries.append(CatalogEntry(i, data, cs))

        return entries

    @staticmethod
    def list_banks(disk_path: str, include_os: bool = False,
                   include_empty: bool = False) -> List[CatalogEntry]:
        """List bank entries with optional filters."""
        entries = CatalogParser.parse(disk_path)
        result = []
        for e in entries:
            if e.is_empty and not include_empty:
                continue
            if e.is_os and not include_os:
                continue
            if not e.is_active:
                continue
            result.append(e)
        return result

    @staticmethod
    def get_os_entry(disk_path: str) -> Optional[CatalogEntry]:
        """Return OS BNT entry (flags == 0x7800) or None."""
        for e in CatalogParser.parse(disk_path):
            if e.is_os and e.is_active:
                return e
        return None

    @staticmethod
    def summary(disk_path: str) -> Dict[str, Any]:
        """Return full catalog summary dict."""
        geo      = CatalogParser._get_geometry(disk_path)
        cs       = geo['cluster_size']
        all_ents = CatalogParser.parse(disk_path)

        active   = [e for e in all_ents if e.is_active and not e.is_empty]
        banks    = [e for e in active   if not e.is_os]
        os_entry = next((e for e in active if e.is_os), None)

        return {
            "total_entries":  len(all_ents),
            "active_entries": len(active),
            "bank_count":     len(banks),
            "cluster_size":   cs,
            "os_entry":       os_entry.to_dict(cs) if os_entry else None,
            "entries":        [e.to_dict(cs) for e in active],
        }
