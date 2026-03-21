#!/usr/bin/env python3
"""
standard tools Disk Format Reverse Engineering
Analyzes .EZ2 disk images to understand standard tools's internal format
"""

import struct
import sys
from pathlib import Path

def analyze_header(data):
    """Analyze disk header (first 512 bytes)"""
    print("\n" + "="*60)
    print("HEADER ANALYSIS (0x0000-0x01FF)")
    print("="*60)
    
    # Boot signature at 0x1FE-0x1FF
    boot_sig = data[0x1FE:0x200]
    print(f"Boot signature (0x1FE): {boot_sig.hex(' ')}")
    if boot_sig == bytes([0x78, 0x82]):
        print("  ✅ Valid EMAX-II boot signature")
    else:
        print(f"  ⚠️  Expected: 78 82, got: {boot_sig.hex(' ')}")
    
    # Common header fields (guesses based on EmaxForge)
    print(f"\nHeader hex dump (first 64 bytes):")
    for i in range(0, 64, 16):
        hex_str = ' '.join(f"{b:02x}" for b in data[i:i+16])
        ascii_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in data[i:i+16])
        print(f"  {i:04x}: {hex_str:48s} {ascii_str}")

def analyze_fat(data):
    """Analyze FAT (File Allocation Table) at 0x400"""
    print("\n" + "="*60)
    print("FAT ANALYSIS (0x0400-0x07FF)")
    print("="*60)
    
    fat_start = 0x400
    fat_size = 1024  # 512 entries x 2 bytes
    
    # Read first 10 FAT entries
    print(f"\nFirst 20 FAT entries:")
    for i in range(20):
        offset = fat_start + (i * 2)
        entry = struct.unpack("<H", data[offset:offset+2])[0]
        
        # Decode entry
        if entry == 0x0000:
            status = "FREE"
        elif entry == 0x7FFF:
            status = "END"
        elif entry == 0x8000:
            status = "OS/SYSTEM"
        elif entry >= 0x8000:
            status = f"SPECIAL (0x{entry:04x})"
        else:
            status = f"→ cluster {entry}"
        
        print(f"  FAT[{i:3d}] = 0x{entry:04x}  ({status})")
    
    # Count FAT entry types
    free_count = 0
    used_count = 0
    end_count = 0
    
    for i in range(512):
        offset = fat_start + (i * 2)
        entry = struct.unpack("<H", data[offset:offset+2])[0]
        
        if entry == 0x0000:
            free_count += 1
        elif entry == 0x7FFF:
            end_count += 1
        elif entry > 0 and entry < 0x7FFF:
            used_count += 1
    
    print(f"\nFAT Summary:")
    print(f"  Free clusters: {free_count}")
    print(f"  Used clusters: {used_count}")
    print(f"  End markers:   {end_count}")

def analyze_catalog(data):
    """Analyze Catalog at 0x1000"""
    print("\n" + "="*60)
    print("CATALOG ANALYSIS (0x1000+)")
    print("="*60)
    
    catalog_start = 0x1000
    entry_size = 64
    
    print(f"\nCatalog entries:")
    
    bank_count = 0
    for i in range(20):  # Check first 20 entries
        offset = catalog_start + (i * entry_size)
        entry = data[offset:offset+entry_size]
        
        # Parse entry
        name_bytes = entry[0:16]
        name = name_bytes.decode('ascii', errors='ignore').strip('\x00').strip()
        
        cluster = struct.unpack("<H", entry[0x12:0x14])[0]
        size = struct.unpack("<H", entry[0x14:0x16])[0]
        flags = struct.unpack("<H", entry[0x1A:0x1C])[0]
        
        if not name:
            continue
        
        bank_count += 1
        
        # Decode flags
        flag_str = ""
        if flags & 0x0001:
            flag_str += "BANK "
        if flags & 0x0080:
            flag_str += "SYSTEM "
        if flags & 0x8000:
            flag_str += "BOOTABLE "
        
        size_kb = (size * 956) / 1024.0
        
        print(f"  [{i:2d}] {name:20s} cluster={cluster:4d} size={size:4d} ({size_kb:6.1f} KB) flags=0x{flags:04x} {flag_str}")
    
    print(f"\nFound {bank_count} catalog entries")

def analyze_cluster_area(data):
    """Analyze cluster data area"""
    print("\n" + "="*60)
    print("CLUSTER AREA ANALYSIS")
    print("="*60)
    
    # Cluster area starts at sector 98 (0xC400)
    cluster_start = 98 * 512
    cluster_size = 956 * 512  # 489,472 bytes per cluster
    
    print(f"Cluster area start: 0x{cluster_start:X} (sector 98)")
    print(f"Cluster size: {cluster_size:,} bytes (956 sectors)")
    
    # Analyze first cluster (should be OS)
    print(f"\nCluster 0 (OS) first 64 bytes:")
    cluster0 = data[cluster_start:cluster_start+64]
    for i in range(0, 64, 16):
        hex_str = ' '.join(f"{b:02x}" for b in cluster0[i:i+16])
        ascii_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in cluster0[i:i+16])
        print(f"  {i:04x}: {hex_str:48s} {ascii_str}")

def find_patterns(data):
    """Find repeating patterns in disk"""
    print("\n" + "="*60)
    print("PATTERN DETECTION")
    print("="*60)
    
    # Search for "EMAX" string
    emax_positions = []
    search_bytes = b"EMAX"
    pos = 0
    while True:
        pos = data.find(search_bytes, pos)
        if pos == -1:
            break
        emax_positions.append(pos)
        pos += 1
    
    print(f"\nFound 'EMAX' at {len(emax_positions)} positions:")
    for pos in emax_positions[:10]:
        context = data[max(0, pos-8):pos+20]
        hex_str = ' '.join(f"{b:02x}" for b in context)
        print(f"  0x{pos:06X}: {hex_str}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_emax2_disk.py <disk.ez2>")
        sys.exit(1)
    
    disk_path = Path(sys.argv[1])
    
    if not disk_path.exists():
        print(f"❌ File not found: {disk_path}")
        sys.exit(1)
    
    print(f"🔍 Analyzing disk: {disk_path}")
    print(f"   Size: {disk_path.stat().st_size:,} bytes ({disk_path.stat().st_size / (1024*1024):.1f} MB)")
    
    data = disk_path.read_bytes()
    
    analyze_header(data)
    analyze_fat(data)
    analyze_catalog(data)
    analyze_cluster_area(data)
    find_patterns(data)
    
    print("\n" + "="*60)
    print("✅ Analysis complete!")
    print("="*60)

if __name__ == '__main__':
    main()
