#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Analyserar en .EZ2 fil och kontrollerar om den innehåller ett OS (operativsystem).
"""

import struct
import sys
from pathlib import Path

def read_u32_le(data, offset):
    return struct.unpack('<I', data[offset:offset+4])[0]

def read_u16_le(data, offset):
    return struct.unpack('<H', data[offset:offset+2])[0]

def analyze_ez2_file(image_path):
    """Analyserar en .EZ2 fil och returnerar information om OS."""
    
    path = Path(image_path)
    if not path.exists():
        print(f"❌ Filen finns inte: {image_path}")
        return None
    
    print(f"📀 Analyserar: {path.name}")
    print("=" * 60)
    
    # Read file
    try:
        with open(path, 'rb') as f:
            data = f.read()
    except Exception as e:
        print(f"❌ Kunde inte läsa filen: {e}")
        return None
    
    file_size = len(data)
    print(f"📏 Storlek: {file_size / (1024*1024):.2f} MB ({file_size:,} bytes)")
    
    # Read header
    if len(data) < 512:
        print("❌ Filen är för liten (måste vara minst 512 bytes)")
        return None
    
    magic = data[0:4].decode('ascii', errors='ignore')
    print(f"🔍 Magic: {magic}")
    
    if magic != "EMX2":
        print("❌ Inte en giltig EMAX II image (förväntade 'EMX2')")
        return None
    
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
        return None
    
    fat_data = data[0x400:0x400+1024]
    fat = []
    for i in range(0, 1024, 2):
        fat.append(read_u16_le(fat_data, i))
    
    # Check FAT entry 1 (OS location)
    fat_entry_1 = fat[1] if len(fat) > 1 else 0
    print(f"\n🔍 FAT Entry 1 (OS cluster): 0x{fat_entry_1:04X}")
    
    if fat_entry_1 == 0x7FFF:
        print("   ✅ OS END marker finns (indikerar OS på cluster 1)")
    elif fat_entry_1 == 0:
        print("   ⚠️  FAT Entry 1 är tom (inget OS)")
    else:
        print(f"   ⚠️  Oväntat värde: 0x{fat_entry_1:04X}")
    
    used_clusters = sum(1 for x in fat if x != 0x7FFF and x != 0 and x != 0x8000)
    free_clusters = sum(1 for x in fat if x == 0)
    print(f"📈 Använda clusters: {used_clusters}")
    print(f"📉 Lediga clusters: {free_clusters}")
    
    # Read catalog (starts at 0x1000)
    if len(data) < 0x1000:
        print("❌ Filen är för liten för catalog")
        return None
    
    print("\n📚 Banks på disken:")
    print("-" * 60)
    
    banks = []
    os_found = False
    
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
        field_c = read_u16_le(entry, 22)  # Field C (OS flag)
        
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
        
        # Check if OS: start_cluster == 1, or name contains "Software"/"OS", or field_c == 0x0081
        is_os = (start_cluster == 1 or 
                "Software" in name or 
                "OS" in name or 
                name == "EMAX2 Software" or
                field_c == 0x0081)
        
        if is_os:
            os_found = True
        
        banks.append({
            'name': name,
            'bank_index': bank_index,
            'presets': num_presets,
            'size': size_bytes,
            'is_os': is_os,
            'start_cluster': start_cluster,
            'field_c': field_c
        })
    
    # Sort: OS first, then by bank index
    banks.sort(key=lambda x: (not x['is_os'], x['bank_index']))
    
    for idx, bank in enumerate(banks, 1):
        icon = "💻" if bank['is_os'] else "🎵"
        type_label = " (OS)" if bank['is_os'] else ""
        print(f"{idx:2d}. {icon} {bank['name']}{type_label}")
        print(f"    Bank Index: {bank['bank_index']}")
        print(f"    Start Cluster: {bank['start_cluster']}")
        print(f"    Field C: 0x{bank['field_c']:04X}")
        print(f"    Presets: {bank['presets']}")
        print(f"    Storlek: {bank['size'] / 1024:.1f} KB ({bank['size']:,} bytes)")
        print()
    
    print("=" * 60)
    print("📊 Sammanfattning:")
    print(f"   Totala banks: {len(banks)}")
    os_banks = sum(1 for b in banks if b['is_os'])
    print(f"   OS banks: {os_banks}")
    print(f"   Sample banks: {sum(1 for b in banks if not b['is_os'])}")
    total_size = sum(b['size'] for b in banks)
    print(f"   Total använt: {total_size / (1024*1024):.2f} MB ({total_size:,} bytes)")
    
    print("\n" + "=" * 60)
    print("🎯 OS-KONTROLL:")
    print("=" * 60)
    
    if os_found:
        os_bank = next((b for b in banks if b['is_os']), None)
        if os_bank:
            print("✅ OS HITTAT!")
            print(f"   Namn: {os_bank['name']}")
            print(f"   Start Cluster: {os_bank['start_cluster']}")
            print(f"   Storlek: {os_bank['size'] / 1024:.1f} KB")
            print(f"   Field C: 0x{os_bank['field_c']:04X}")
            
            # Check OS data location
            cluster_area_start = cluster_area_start_sector * 512
            os_offset = cluster_area_start + (os_bank['start_cluster'] * cluster_size)
            print(f"   OS Offset: 0x{os_offset:X} ({os_offset:,} bytes)")
            
            # Check if OS data exists at that location
            if os_offset + os_bank['size'] <= len(data):
                os_data = data[os_offset:os_offset+min(16, os_bank['size'])]
                print(f"   OS Data (första 16 bytes): {os_data.hex(' ').upper()}")
                
                # Check for boot signature (at offset 0x1FE-0x1FF in header)
                boot_sig = data[0x1FE:0x200]
                if len(boot_sig) == 2:
                    boot_sig_val = (boot_sig[1] << 8) | boot_sig[0]
                    print(f"   Boot Signature (0x1FE-0x1FF): 0x{boot_sig_val:04X}")
                    if boot_sig_val == 0x8278:  # 0x78 0x82 in little-endian
                        print("   ✅ Boot signature korrekt (0x78 0x82)")
                    else:
                        print(f"   ⚠️  Boot signature oväntat: {boot_sig.hex(' ').upper()}")
    else:
        print("❌ INGET OS HITTAT!")
        print("   Filen innehåller inget operativsystem.")
        print("   För att boota EMAX II behöver du ett OS på cluster 1.")
    
    return {
        'has_os': os_found,
        'os_bank': next((b for b in banks if b['is_os']), None) if os_found else None,
        'total_banks': len(banks)
    }

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Användning: python3 analyze_ez2_os.py <sökväg_till_ez2_fil>")
        print("\nExempel:")
        print("  python3 analyze_ez2_os.py zulu_test_512.EZ2")
        print("  python3 analyze_ez2_os.py /path/to/file.EZ2")
        sys.exit(1)
    
    result = analyze_ez2_file(sys.argv[1])
    
    if result:
        sys.exit(0 if result['has_os'] else 1)
    else:
        sys.exit(1)
