"""
EMAX II Disk Catalog Parser
Parses catalog entries from disk images
"""

import struct
from pathlib import Path
from typing import List, Dict, Any, Optional


class CatalogEntry:
    """Single catalog entry (OS or bank)"""
    
    def __init__(self, index: int, data: bytes):
        self.index = index
        self.raw_data = data
        
        # Parse fields (64-byte entry)
        self.name = self._parse_name(data[0:16])
        self.cluster = struct.unpack('<H', data[16:18])[0]
        self.size_clusters = struct.unpack('<H', data[18:20])[0]
        self.flags = struct.unpack('<H', data[26:28])[0]
        self.preset_count = data[28] if len(data) > 28 else 0
        
        # Computed
        self.is_active = (self.flags & 0x0001) != 0
        self.is_os = "EMAX" in self.name.upper() or "SOFTWARE" in self.name.upper()
        self.is_empty = self.cluster == 0 or self.cluster == 0xFFFF
    
    def _parse_name(self, name_bytes: bytes) -> str:
        """Parse name from catalog entry (null-terminated ASCII)"""
        try:
            # Find null terminator
            null_idx = name_bytes.find(b'\x00')
            if null_idx != -1:
                name_bytes = name_bytes[:null_idx]
            return name_bytes.decode('ascii', errors='ignore').strip()
        except:
            return ""
    
    def size_bytes(self, cluster_size: int) -> int:
        """Calculate size in bytes"""
        return self.size_clusters * cluster_size
    
    def size_mb(self, cluster_size: int) -> float:
        """Calculate size in MB"""
        return self.size_bytes(cluster_size) / (1024 * 1024)
    
    def to_dict(self, cluster_size: int = 8192) -> Dict[str, Any]:
        """Convert to dictionary"""
        return {
            "index": self.index,
            "name": self.name,
            "cluster": self.cluster,
            "size_clusters": self.size_clusters,
            "size_bytes": self.size_bytes(cluster_size),
            "size_mb": round(self.size_mb(cluster_size), 2),
            "flags": hex(self.flags),
            "preset_count": self.preset_count,
            "is_active": self.is_active,
            "is_os": self.is_os,
            "is_empty": self.is_empty
        }


class CatalogParser:
    """Parse EMAX II disk catalog"""
    
    CATALOG_OFFSET = 0x600  # 1536 bytes from start
    ENTRY_SIZE = 64
    MAX_ENTRIES = 90  # standard (239 MB disk)
    
    @staticmethod
    def parse(disk_path: str, max_entries: int = MAX_ENTRIES) -> List[CatalogEntry]:
        """Parse all catalog entries from disk
        
        Args:
            disk_path: Path to disk image
            max_entries: Maximum entries to parse (default: 90)
        
        Returns:
            List of CatalogEntry objects
        """
        path = Path(disk_path)
        if not path.exists():
            raise FileNotFoundError(f"Disk not found: {disk_path}")
        
        entries = []
        
        with open(path, 'rb') as f:
            f.seek(CatalogParser.CATALOG_OFFSET)
            
            for i in range(max_entries):
                entry_data = f.read(CatalogParser.ENTRY_SIZE)
                if len(entry_data) < CatalogParser.ENTRY_SIZE:
                    break
                
                entry = CatalogEntry(i, entry_data)
                entries.append(entry)
        
        return entries
    
    @staticmethod
    def list_banks(disk_path: str, include_os: bool = False, 
                   include_empty: bool = False) -> List[CatalogEntry]:
        """List only bank entries (filter OS and empty)
        
        Args:
            disk_path: Path to disk image
            include_os: Include OS entries (default: False)
            include_empty: Include empty entries (default: False)
        
        Returns:
            Filtered list of CatalogEntry objects
        """
        entries = CatalogParser.parse(disk_path)
        filtered = []
        
        for entry in entries:
            # Skip empty
            if not include_empty and entry.is_empty:
                continue
            
            # Skip OS
            if not include_os and entry.is_os:
                continue
            
            # Skip inactive
            if not entry.is_active:
                continue
            
            filtered.append(entry)
        
        return filtered
    
    @staticmethod
    def get_os_entry(disk_path: str) -> Optional[CatalogEntry]:
        """Get OS catalog entry
        
        Args:
            disk_path: Path to disk image
        
        Returns:
            CatalogEntry for OS or None
        """
        entries = CatalogParser.parse(disk_path)  # Parse all entries
        
        for entry in entries:
            if entry.is_os and entry.is_active and not entry.is_empty:
                return entry
        
        return None
    
    @staticmethod
    def get_cluster_size(disk_path: str) -> int:
        """Get cluster size from disk header
        
        Args:
            disk_path: Path to disk image
        
        Returns:
            Cluster size in bytes
        """
        with open(disk_path, 'rb') as f:
            f.seek(0x0C)
            blocks = struct.unpack('<I', f.read(4))[0]
            return int(blocks) * 8192
    
    @staticmethod
    def summary(disk_path: str) -> Dict[str, Any]:
        """Get catalog summary
        
        Args:
            disk_path: Path to disk image
        
        Returns:
            {
                "total_entries": int,
                "active_entries": int,
                "bank_count": int,
                "os_entry": dict or None,
                "cluster_size": int,
                "entries": [dict]
            }
        """
        cluster_size = CatalogParser.get_cluster_size(disk_path)
        all_entries = CatalogParser.parse(disk_path)
        
        active = [e for e in all_entries if e.is_active and not e.is_empty]
        banks = [e for e in active if not e.is_os]
        os_entry = CatalogParser.get_os_entry(disk_path)
        
        return {
            "total_entries": len(all_entries),
            "active_entries": len(active),
            "bank_count": len(banks),
            "os_entry": os_entry.to_dict(cluster_size) if os_entry else None,
            "cluster_size": cluster_size,
            "entries": [e.to_dict(cluster_size) for e in active]
        }
