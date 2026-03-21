"""
EMAX II FAT Chain Analyzer
Analyze File Allocation Table structure and detect errors
"""

import struct
from pathlib import Path
from typing import List, Dict, Any, Set, Optional, Tuple


class FATChain:
    """Single FAT chain (represents one file/bank)"""
    
    def __init__(self, start_cluster: int, clusters: List[int]):
        self.start_cluster = start_cluster
        self.clusters = clusters
        self.length = len(clusters)
        self.is_circular = False
        self.is_broken = False
        self.orphaned_clusters: List[int] = []
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "start_cluster": self.start_cluster,
            "clusters": self.clusters,
            "length": self.length,
            "is_circular": self.is_circular,
            "is_broken": self.is_broken,
            "orphaned_clusters": self.orphaned_clusters
        }


class FATAnalyzer:
    """Analyze EMAX II FAT structure"""
    
    FAT_OFFSET = 512  # FAT starts at sector 1
    FAT_ENTRY_SIZE = 2  # 16-bit entries
    
    # FAT markers
    END_OF_CHAIN = 0x7FFF
    END_OF_CHAIN_ALT = 0xFFFF
    FREE_CLUSTER = 0x8080
    RESERVED = 0x8000
    
    def __init__(self, disk_path: str):
        self.disk_path = Path(disk_path)
        if not self.disk_path.exists():
            raise FileNotFoundError(f"Disk not found: {disk_path}")
        
        self.fat: List[int] = []
        self.cluster_size = 0
        self.total_clusters = 0
        self._load_fat()
    
    def _load_fat(self):
        """Load FAT from disk"""
        with open(self.disk_path, 'rb') as f:
            # Get cluster size from header
            f.seek(0x0C)
            blocks = struct.unpack('<I', f.read(4))[0]
            self.cluster_size = int(blocks) * 8192
            
            # Get total clusters (estimate from disk size)
            f.seek(0, 2)  # End of file
            disk_size = f.tell()
            self.total_clusters = disk_size // self.cluster_size
            
            # Read FAT
            f.seek(self.FAT_OFFSET)
            fat_size = min(self.total_clusters * 2, 10000)  # Max 10KB FAT read
            fat_data = f.read(fat_size)
            
            # Parse FAT entries
            for i in range(0, len(fat_data), 2):
                if i + 2 <= len(fat_data):
                    entry = struct.unpack('<H', fat_data[i:i+2])[0]
                    self.fat.append(entry)
    
    def is_end_marker(self, value: int) -> bool:
        """Check if value is end-of-chain marker"""
        return value in [self.END_OF_CHAIN, self.END_OF_CHAIN_ALT]
    
    def is_free(self, value: int) -> bool:
        """Check if cluster is free"""
        return value in [0, self.FREE_CLUSTER]
    
    def follow_chain(self, start_cluster: int, max_length: int = 1000) -> FATChain:
        """Follow FAT chain from start cluster
        
        Args:
            start_cluster: Starting cluster number
            max_length: Maximum chain length (detect circular)
        
        Returns:
            FATChain object
        """
        clusters = [start_cluster]
        visited: Set[int] = {start_cluster}
        current = start_cluster
        is_circular = False
        is_broken = False
        
        while len(clusters) < max_length:
            if current >= len(self.fat):
                is_broken = True
                break
            
            next_cluster = self.fat[current]
            
            # End of chain
            if self.is_end_marker(next_cluster):
                break
            
            # Free cluster (shouldn't happen in valid chain)
            if self.is_free(next_cluster):
                is_broken = True
                break
            
            # Circular reference
            if next_cluster in visited:
                is_circular = True
                clusters.append(next_cluster)
                break
            
            clusters.append(next_cluster)
            visited.add(next_cluster)
            current = next_cluster
        
        chain = FATChain(start_cluster, clusters)
        chain.is_circular = is_circular
        chain.is_broken = is_broken
        
        return chain
    
    def find_all_chains(self) -> List[FATChain]:
        """Find all FAT chains in disk
        
        Returns:
            List of FATChain objects
        """
        chains: List[FATChain] = []
        allocated: Set[int] = set()
        
        # Start from cluster 1 (cluster 0 is reserved)
        for i in range(1, len(self.fat)):
            if i in allocated:
                continue
            
            if self.is_free(self.fat[i]) or i == 0:
                continue
            
            # Found chain start
            chain = self.follow_chain(i)
            chains.append(chain)
            allocated.update(chain.clusters)
        
        return chains
    
    def find_orphaned_clusters(self) -> List[int]:
        """Find clusters allocated but not referenced by any chain
        
        Returns:
            List of orphaned cluster numbers
        """
        chains = self.find_all_chains()
        allocated_in_chains: Set[int] = set()
        
        for chain in chains:
            allocated_in_chains.update(chain.clusters)
        
        orphaned: List[int] = []
        
        for i in range(1, len(self.fat)):
            if i in allocated_in_chains:
                continue
            
            if not self.is_free(self.fat[i]) and not self.is_end_marker(self.fat[i]):
                orphaned.append(i)
        
        return orphaned
    
    def analyze(self) -> Dict[str, Any]:
        """Complete FAT analysis
        
        Returns:
            {
                "cluster_size": int,
                "total_clusters": int,
                "fat_entries": int,
                "chains": [FATChain.to_dict()],
                "chain_count": int,
                "circular_chains": int,
                "broken_chains": int,
                "orphaned_clusters": [int],
                "orphaned_count": int,
                "allocated_clusters": int,
                "free_clusters": int,
                "usage_percent": float
            }
        """
        chains = self.find_all_chains()
        orphaned = self.find_orphaned_clusters()
        
        allocated = sum(chain.length for chain in chains)
        free = sum(1 for entry in self.fat if self.is_free(entry))
        
        circular = sum(1 for chain in chains if chain.is_circular)
        broken = sum(1 for chain in chains if chain.is_broken)
        
        usage_percent = (allocated / len(self.fat)) * 100 if len(self.fat) > 0 else 0
        
        return {
            "cluster_size": self.cluster_size,
            "total_clusters": self.total_clusters,
            "fat_entries": len(self.fat),
            "chains": [chain.to_dict() for chain in chains],
            "chain_count": len(chains),
            "circular_chains": circular,
            "broken_chains": broken,
            "orphaned_clusters": orphaned,
            "orphaned_count": len(orphaned),
            "allocated_clusters": allocated,
            "free_clusters": free,
            "usage_percent": round(usage_percent, 2)
        }
    
    def visualize_chain(self, start_cluster: int) -> str:
        """Visualize single FAT chain as ASCII art
        
        Args:
            start_cluster: Starting cluster
        
        Returns:
            ASCII visualization string
        """
        chain = self.follow_chain(start_cluster)
        
        if chain.is_circular:
            viz = " → ".join(str(c) for c in chain.clusters[:10])
            viz += " → ⭮ CIRCULAR"
        elif chain.is_broken:
            viz = " → ".join(str(c) for c in chain.clusters)
            viz += " → ✗ BROKEN"
        else:
            viz = " → ".join(str(c) for c in chain.clusters)
            viz += " → ■ END"
        
        return viz
