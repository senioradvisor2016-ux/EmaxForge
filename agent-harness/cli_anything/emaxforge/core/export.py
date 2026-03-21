"""
Export banks from EMAX-II hard disk images
"""
import struct
import sys

def export_bank(disk_path, bank_name, output_path):
    """
    Export a single bank from disk image to .EB2 file
    
    Args:
        disk_path: Path to hard disk image (.hda)
        bank_name: Name of bank to export
        output_path: Output .EB2 file path
        
    Returns:
        dict: Export result with bank info
    """
    with open(disk_path, 'rb') as f:
        # Read header
        header = f.read(512)
        
        # Get cluster size
        cluster_size_blocks = struct.unpack('<I', header[0x0C:0x10])[0]
        cluster_size = cluster_size_blocks * 8192
        
        # Read FAT (up to 32KB should be enough for any disk)
        f.seek(0x400)
        fat_data = f.read(65536)
        
        # Find bank in catalog
        f.seek(0x600)  # Catalog starts after FAT
        catalog_data = f.read(65536)  # Read enough catalog entries
        
        bank_entry = None
        entry_offset = 0
        
        while entry_offset < len(catalog_data):
            entry = catalog_data[entry_offset:entry_offset + 64]
            if len(entry) < 64:
                break
                
            # Read bank name (first 16 bytes)
            name = entry[0:16].decode('ascii', errors='ignore').rstrip('\x00 ')
            
            if name == bank_name:
                # Found it!
                bank_entry = entry
                break
            
            # Check if empty (all zeros or 0xFF)
            if entry[0] == 0x00 or entry[0] == 0xFF:
                break
                
            entry_offset += 64
        
        if not bank_entry:
            return {
                'error': f'Bank "{bank_name}" not found on disk'
            }
        
        # Parse bank entry
        flags = struct.unpack('<H', bank_entry[0x1A:0x1C])[0]
        start_cluster = struct.unpack('<H', bank_entry[0x1C:0x1E])[0]
        presets = struct.unpack('<H', bank_entry[0x1E:0x20])[0]
        
        # Follow FAT chain to get all clusters
        clusters = []
        current = start_cluster
        
        while True:
            clusters.append(current)
            
            # Read next cluster from FAT
            fat_offset = current * 2
            if fat_offset >= len(fat_data):
                break
            
            next_cluster = struct.unpack('<H', fat_data[fat_offset:fat_offset+2])[0]
            
            # End of chain?
            if next_cluster == 0x7FFF or next_cluster == 0xFFFF:
                break
            if next_cluster == 0x8080:  # Free cluster
                break
            if next_cluster == current:  # Loop
                break
            if next_cluster < 2:  # Invalid
                break
                
            current = next_cluster
            
            if len(clusters) > 10000:  # Safety
                break
        
        # Calculate cluster area start
        cluster_area_start = 98 * 512  # Standard EMAX-II
        
        # Read all bank data
        bank_data = bytearray()
        for cluster_num in clusters:
            cluster_offset = cluster_area_start + (cluster_num - 2) * cluster_size
            f.seek(cluster_offset)
            bank_data.extend(f.read(cluster_size))
        
        # Write to .EB2 file
        with open(output_path, 'wb') as out:
            out.write(bank_data)
        
        return {
            'bank_name': bank_name,
            'output_path': output_path,
            'size_bytes': len(bank_data),
            'clusters': len(clusters),
            'presets': presets,
            'start_cluster': start_cluster
        }
