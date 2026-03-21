#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import struct
import sys
from pathlib import Path

def read_u32_le(data, offset):
    return struct.unpack('<I', data[offset:offset+4])[0]

def read_u16_le(data, offset):
    return struct.unpack('<H', data[offset:offset+2])[0]

image_path = Path("/Users/senioradvisor/clawd/EmaxForge/EMAXII_IMAGE_Malmo.EZ2")

print(f"📀 Analyserar: {image_path.name}")
print("=" * 60)

# Read file
with open(image_path, 'rb') as f:
    data = f.read()

file_size = len(data)
print(f"📏 Storlek: {file_size / (1024*1024):.2f} MB ({file_size:,} bytes)")

# Read header
if len(data) < 512:
    print("❌ Filen är för liten")
    sys.exit(1)

magic = data[0:4].decode('ascii', errors='ignore')
print(f"🔍 Magic: {magic}")

if magic != "EMX2":
    print("❌ Inte en giltig EMAX II image (förväntade 'EMX2')")
    sys.exit(1)

# Parse header
cluster_size = read_u32_le(data, 4)
cluster_area_start_sector = read_u32_le(data, 0x20)
bank_count_header = read_u32_le(data, 0x14)

print(f"💾 Cluster Size: {cluster_size:,} bytes ({cluster_size / 1024:.1f} KB)")
print(f"📍 Cluster Area Start Sector: {cluster_area_start_sector}")
print(f"📊 Bank Count (header): {bank_count_header}")

# Read FAT (1024 bytes at offset 0x400)
if len(data) < 0x400 + 1024:
    print("❌ Filen är för liten för FAT")
    sys.exit(1)

fat_data = data[0x400:0x400+1024]
fat = []
for i in range(0, 1024, 2):
    fat.append(read_u16_le(fat_data, i))

used_clusters = sum(1 for x in fat if x != 0x7FFF and x != 0 and x != 0x8000)
free_clusters = sum(1 for x in fat if x == 0)
print(f"📈 Använda clusters: {used_clusters}")
print(f"📉 Lediga clusters: {free_clusters}")

# Read catalog (starts at 0x1000)
if len(data) < 0x1000:
    print("❌ Filen är för liten för catalog")
    sys.exit(1)

print("\n📚 Banks på disken:")
print("-" * 60)

banks = []

for i in range(500):
    offset = 0x1000 + (i * 32)
    if offset + 32 > len(data):
        break
    
    entry = data[offset:offset+32]
    name_bytes = entry[0:16]
    
    # End of catalog (all zeros or all 0xFF)
    if all(b == 0 or b == 0xFF for b in name_bytes):
        break
    
    # Decode name
    name = name_bytes.decode('ascii', errors='ignore').rstrip('\x00').strip()
    if not name:
        break
    
    bank_index = read_u16_le(entry, 16)
    start_cluster = read_u16_le(entry, 18)
    num_presets = read_u16_le(entry, 20)
    
    # Follow cluster chain to calculate size
    cluster_chain = []
    current = start_cluster
    visited = set()
    
    while current != 0 and current < 512 and current not in visited:
        visited.add(current)
        cluster_chain.append(current)
        
        if current < len(fat):
            next_cluster = fat[current]
            if next_cluster == 0x7FFF or next_cluster == 0x8000:
                break  # END marker or reserved
            current = next_cluster
        else:
            break
    
    size_bytes = len(cluster_chain) * cluster_size
    is_os = start_cluster == 1 or "Software" in name or "OS" in name or name == "EMAX2 Software"
    
    banks.append({
        'name': name,
        'bank_index': bank_index,
        'presets': num_presets,
        'size': size_bytes,
        'is_os': is_os,
        'start_cluster': start_cluster
    })

# Sort: OS first, then by bank index
banks.sort(key=lambda x: (not x['is_os'], x['bank_index']))

for idx, bank in enumerate(banks, 1):
    icon = "💻" if bank['is_os'] else "🎵"
    type_label = " (OS)" if bank['is_os'] else ""
    print(f"{idx:2d}. {icon} {bank['name']}{type_label}")
    print(f"    Bank Index: {bank['bank_index']}")
    print(f"    Start Cluster: {bank['start_cluster']}")
    print(f"    Presets: {bank['presets']}")
    print(f"    Storlek: {bank['size'] / 1024:.1f} KB ({bank['size']:,} bytes)")
    print()

print("=" * 60)
print("📊 Sammanfattning:")
print(f"   Totala banks: {len(banks)}")
print(f"   OS banks: {sum(1 for b in banks if b['is_os'])}")
print(f"   Sample banks: {sum(1 for b in banks if not b['is_os'])}")
total_size = sum(b['size'] for b in banks)
print(f"   Total använt: {total_size / (1024*1024):.2f} MB ({total_size:,} bytes)")
