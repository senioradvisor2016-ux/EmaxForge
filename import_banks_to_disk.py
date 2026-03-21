#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Import .EB2 bank files into an EMAX II disk image
"""

import struct
import sys
from pathlib import Path

def read_u16_le(data, offset):
    return struct.unpack('<H', data[offset:offset+2])[0]

def read_u32_le(data, offset):
    return struct.unpack('<I', data[offset:offset+4])[0]

def write_u16_le(data, offset, value):
    data[offset] = value & 0xFF
    data[offset + 1] = (value >> 8) & 0xFF

def import_bank(disk_path, bank_path):
    """Import a single .EB2 bank file into the disk image"""
    
    # Read bank file
    with open(bank_path, 'rb') as f:
        bank_data = f.read()
    
    if len(bank_data) < 512:
        raise ValueError(f"Bank file too small: {len(bank_data)} bytes")
    
    bank_name = bank_path.stem[:14]  # Max 14 chars
    
    # Read disk image
    with open(disk_path, 'r+b') as f:
        data = bytearray(f.read())
        
        # Parse header
        if data[0:4] != b'EMX2':
            raise ValueError("Not a valid EMAX II image")
        
        cluster_size = read_u32_le(data, 0x04)
        fat_sectors = read_u32_le(data, 0x1C)
        bnt_start_sector = read_u32_le(data, 0x10)
        max_banks = read_u32_le(data, 0x14)
        cluster_area_start_sector = read_u32_le(data, 0x20)
        total_clusters = read_u32_le(data, 0x24)
        
        fat_offset = 0x400
        fat_size = fat_sectors * 512
        bnt_offset = bnt_start_sector * 512
        cluster_area_offset = cluster_area_start_sector * 512
        
        # Read FAT
        fat = []
        for i in range(0, fat_size, 2):
            fat.append(read_u16_le(data, fat_offset + i))
        
        # Calculate clusters needed
        clusters_needed = (len(bank_data) + cluster_size - 1) // cluster_size
        
        # Find free clusters (skip 0=reserved, 1=OS)
        free_clusters = []
        for i in range(2, min(len(fat), total_clusters + 2)):
            if fat[i] == 0x0000:
                free_clusters.append(i)
                if len(free_clusters) >= clusters_needed:
                    break
        
        if len(free_clusters) < clusters_needed:
            total_free = sum(1 for i in range(2, min(len(fat), total_clusters + 2)) if fat[i] == 0x0000)
            raise ValueError(f"Not enough space: need {clusters_needed} clusters, only {total_free} free")
        
        allocated = free_clusters[:clusters_needed]
        
        # Write bank data to clusters
        # Formula: clusterAreaOffset + (cluster * clusterSize)
        for i, cluster in enumerate(allocated):
            data_start = i * cluster_size
            data_end = min(data_start + cluster_size, len(bank_data))
            chunk = bank_data[data_start:data_end]
            
            # Calculate cluster offset using NEW formula
            cluster_offset = cluster_area_offset + (cluster * cluster_size)
            
            # Ensure we have enough space in data array
            required_size = cluster_offset + cluster_size
            if len(data) < required_size:
                data.extend(b'\x00' * (required_size - len(data)))
            
            # Write chunk
            for j, byte in enumerate(chunk):
                if cluster_offset + j < len(data):
                    data[cluster_offset + j] = byte
            
            # Pad remaining with zeros
            remaining = cluster_size - len(chunk)
            for j in range(remaining):
                offset = cluster_offset + len(chunk) + j
                if offset < len(data):
                    data[offset] = 0
        
        # Update FAT chain
        for i in range(len(allocated)):
            cluster = allocated[i]
            if i < len(allocated) - 1:
                fat[cluster] = allocated[i + 1]
            else:
                fat[cluster] = 0x7FFF  # END marker
        
        # Write updated FAT
        for i in range(len(fat)):
            write_u16_le(data, fat_offset + (i * 2), fat[i])
        
        # Find free BNT slot
        bnt_total_size = (cluster_area_start_sector - bnt_start_sector) * 512
        max_slots = min(max_banks + 1, bnt_total_size // 32)
        
        slot_index = -1
        for i in range(1, max_slots):
            entry_offset = bnt_offset + (i * 32)
            entry = data[entry_offset:entry_offset + 32]
            if all(b == 0x00 for b in entry):
                slot_index = i
                break
        
        if slot_index == -1:
            raise ValueError("No free BNT slot")
        
        # Build BNT entry
        entry_offset = bnt_offset + (slot_index * 32)
        
        # [0-15]: name, ASCII space-padded
        name_bytes = bank_name.ljust(14, ' ').encode('ascii')[:14] + b'\x00\x00'
        for i, byte in enumerate(name_bytes[:16]):
            data[entry_offset + i] = byte
        
        # [16-17]: idx (increments by 0x0100 per slot)
        idx = (slot_index - 1) * 0x0100
        write_u16_le(data, entry_offset + 16, idx)
        
        # [18-19]: start cluster
        write_u16_le(data, entry_offset + 18, allocated[0])
        
        # [20-21]: cluster count
        write_u16_le(data, entry_offset + 20, len(allocated))
        
        # [22-23]: f22 (set to 0)
        write_u16_le(data, entry_offset + 22, 0x0000)
        
        # [24-25]: f24 (set to 0)
        write_u16_le(data, entry_offset + 24, 0x0000)
        
        # [26-27]: flags = 0x0081 (active)
        write_u16_le(data, entry_offset + 26, 0x0081)
        
        # [28-31]: zeros (already zero)
        
        # Write back to file
        f.seek(0)
        f.write(data)
        f.truncate()
        
        print(f"✅ Imported '{bank_name}': {len(allocated)} clusters ({len(bank_data):,} bytes) at BNT slot {slot_index}, cluster {allocated[0]}")
        return slot_index

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 import_banks_to_disk.py <disk.ez2> <bank1.eb2> [bank2.eb2 ...]")
        sys.exit(1)
    
    disk_path = Path(sys.argv[1])
    bank_paths = [Path(p) for p in sys.argv[2:]]
    
    if not disk_path.exists():
        print(f"❌ Disk image not found: {disk_path}")
        sys.exit(1)
    
    print(f"📀 Importing banks to: {disk_path.name}")
    print("=" * 60)
    
    imported = 0
    errors = []
    
    for bank_path in bank_paths:
        if not bank_path.exists():
            print(f"⚠️  Bank file not found: {bank_path}")
            errors.append((bank_path, "File not found"))
            continue
        
        if bank_path.suffix.lower() != '.eb2':
            print(f"⚠️  Skipping non-EB2 file: {bank_path}")
            continue
        
        try:
            import_bank(disk_path, bank_path)
            imported += 1
        except Exception as e:
            print(f"❌ Failed to import {bank_path.name}: {e}")
            errors.append((bank_path, str(e)))
    
    print("=" * 60)
    print(f"✅ Imported: {imported} banks")
    if errors:
        print(f"❌ Errors: {len(errors)} banks")
        for path, error in errors:
            print(f"   - {path.name}: {error}")

if __name__ == '__main__':
    main()
