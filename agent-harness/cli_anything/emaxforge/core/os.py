"""
Operating System handling for EMAX-II disks
"""
import struct
import os

def install_os(disk_path, os_path=None):
    """
    Install EMAX-II OS to cluster 1 of disk image
    
    Args:
        disk_path: Path to hard disk image (.hda)
        os_path: Path to OS file (.EMX), or None to auto-detect
        
    Returns:
        dict: Installation result
    """
    # Auto-detect OS file if not provided
    if os_path is None:
        # Try common locations
        possible_paths = [
            '~/clawd/EmaxForge/EmaxForge/Resources/Emax II rev 2.14.EMX',
            '~/clawd/EmaxForge/EmaxForge/Resources/WORKING.EMX',
            '~/clawd/WORKING.EMX',
            '~/clawd/Emax II rev 2.14.EMX'
        ]
        
        for path in possible_paths:
            expanded = os.path.expanduser(path)
            if os.path.exists(expanded):
                os_path = expanded
                break
        
        if os_path is None:
            return {'error': 'No OS file found. Provide --os-file parameter.'}
    
    # Read OS file
    try:
        with open(os_path, 'rb') as f:
            os_data = f.read()
    except Exception as e:
        return {'error': f'Failed to read OS file: {e}'}
    
    os_size = len(os_data)
    
    # Open disk image
    with open(disk_path, 'r+b') as f:
        # Read header to get cluster size
        header = f.read(512)
        cluster_size_blocks = struct.unpack('<I', header[0x0C:0x10])[0]
        cluster_size = cluster_size_blocks * 8192
        
        # Validate OS fits in one cluster
        if os_size > cluster_size:
            return {
                'error': f'OS too large ({os_size} bytes) for cluster size ({cluster_size} bytes)'
            }
        
        # Calculate cluster 1 offset
        cluster_area_start = 98 * 512  # Standard EMAX-II
        cluster_1_offset = cluster_area_start
        
        # Write OS to cluster 1
        f.seek(cluster_1_offset)
        f.write(os_data)
        
        # Pad rest of cluster with zeros
        padding_size = cluster_size - os_size
        if padding_size > 0:
            f.write(b'\x00' * padding_size)
        
        # Update FAT entry 1 (mark as end-of-chain)
        f.seek(0x400 + 2)  # FAT[1]
        f.write(struct.pack('<H', 0x7FFF))
        
        # Update catalog entry 0 (OS entry)
        f.seek(0x600)  # Catalog start
        
        # Create OS catalog entry
        os_entry = bytearray(64)
        
        # Bank name: "EMAX2 Software" + padding
        os_name = b'EMAX2 Software\x00\x00'
        os_entry[0:16] = os_name
        
        # Index (unknown purpose, use 0x7800 from templates)
        struct.pack_into('<H', os_entry, 0x18, 0x7800)
        
        # FLAGS: 0x0081
        struct.pack_into('<H', os_entry, 0x1A, 0x0081)
        
        # Start cluster: 1
        struct.pack_into('<H', os_entry, 0x1C, 1)
        
        # Presets: 1 (OS is treated as one "preset")
        struct.pack_into('<H', os_entry, 0x1E, 1)
        
        f.write(os_entry)
    
    return {
        'os_path': os_path,
        'os_size': os_size,
        'cluster_size': cluster_size,
        'cluster': 1,
        'message': 'OS installed successfully'
    }


def has_os(disk_path):
    """
    Check if disk has OS installed
    
    Returns:
        bool: True if OS detected in catalog entry 0
    """
    with open(disk_path, 'rb') as f:
        # Read catalog entry 0
        f.seek(0x600)
        entry = f.read(64)
        
        # Check if entry 0 has "EMAX2" in name
        name = entry[0:16].decode('ascii', errors='ignore')
        
        return 'EMAX' in name.upper()
