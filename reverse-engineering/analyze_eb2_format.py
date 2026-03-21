#!/usr/bin/env python3
"""
standard tools .EB2 Format Reverse Engineering
Analyzes .EB2 bank files to understand compression/encoding
"""

import struct
import sys
from pathlib import Path

def analyze_eb2(path):
    """Full .EB2 analysis"""
    print(f"🔍 Analyzing .EB2: {path.name}")
    print(f"   Size: {path.stat().st_size:,} bytes ({path.stat().st_size / 1024:.1f} KB)")
    
    data = path.read_bytes()
    
    print("\n" + "="*60)
    print("HEADER ANALYSIS")
    print("="*60)
    
    # First 256 bytes
    print("\nFirst 256 bytes (hex dump):")
    for i in range(0, min(256, len(data)), 16):
        hex_str = ' '.join(f"{b:02x}" for b in data[i:i+16])
        ascii_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in data[i:i+16])
        print(f"  {i:04x}: {hex_str:48s} {ascii_str}")
    
    # Look for magic numbers
    print("\n" + "="*60)
    print("MAGIC NUMBER SEARCH")
    print("="*60)
    
    # Common compression signatures
    magic_patterns = {
        b'RIFF': 'RIFF container',
        b'PK\x03\x04': 'ZIP archive',
        b'\x1f\x8b': 'GZIP',
        b'BZh': 'BZIP2',
        b'7z\xbc\xaf': '7-Zip',
        b'EMAX': 'EMAX marker',
        b'EMU': 'EMU marker',
    }
    
    for magic, desc in magic_patterns.items():
        if data.startswith(magic):
            print(f"✅ Found: {desc} ({magic.hex(' ')})")
    
    # Search in first 1KB
    print("\nSearching first 1KB for patterns:")
    search_area = data[:1024]
    
    for magic, desc in magic_patterns.items():
        pos = search_area.find(magic)
        if pos >= 0:
            print(f"  Found '{desc}' at offset 0x{pos:04X}")
    
    # Entropy analysis (simple)
    print("\n" + "="*60)
    print("ENTROPY ANALYSIS")
    print("="*60)
    
    # Byte frequency
    freq = [0] * 256
    for b in data[:1024]:
        freq[b] += 1
    
    # Most common bytes
    sorted_freq = sorted(enumerate(freq), key=lambda x: x[1], reverse=True)
    print("\nTop 10 most frequent bytes (first 1KB):")
    for byte, count in sorted_freq[:10]:
        if count > 0:
            pct = (count / 1024) * 100
            print(f"  0x{byte:02X} ({byte:3d}) : {count:4d} times ({pct:5.1f}%)")
    
    # Check for repetition (compression indicator)
    zeros = data.count(b'\x00', 0, 1024)
    print(f"\nNull bytes in first 1KB: {zeros} ({zeros/1024*100:.1f}%)")
    
    if zeros > 512:
        print("  ⚠️  High null byte count - likely uncompressed or has padding")
    
    # Structure guessing
    print("\n" + "="*60)
    print("STRUCTURE GUESSING")
    print("="*60)
    
    # Try to find sections
    if len(data) >= 4:
        # Check for header size field
        possible_header_size = struct.unpack("<I", data[0:4])[0]
        print(f"\nByte 0-3 as uint32 (little-endian): {possible_header_size}")
        if possible_header_size < len(data):
            print(f"  Could be header size: {possible_header_size} bytes")
    
    # Look for repeating patterns
    print("\nSearching for repeating 4-byte patterns:")
    pattern_count = {}
    for i in range(0, min(1024, len(data)) - 4, 4):
        pattern = data[i:i+4]
        pattern_count[pattern] = pattern_count.get(pattern, 0) + 1
    
    common_patterns = sorted(pattern_count.items(), key=lambda x: x[1], reverse=True)[:5]
    for pattern, count in common_patterns:
        if count > 2:
            hex_str = pattern.hex(' ')
            print(f"  {hex_str:12s} : {count} times")

def compare_eb2_vs_disk(eb2_path, disk_path):
    """Compare .EB2 with same bank extracted from disk"""
    print("\n" + "="*60)
    print("COMPARISON: .EB2 vs Disk-extracted bank")
    print("="*60)
    
    # This would require:
    # 1. Extract bank from disk (we already have code for this!)
    # 2. Compare byte-by-byte
    # 3. Find compression algorithm
    
    print("\n⚠️  Comparison requires disk image - implement later")

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_eb2_format.py <file.EB2>")
        sys.exit(1)
    
    eb2_path = Path(sys.argv[1])
    
    if not eb2_path.exists():
        print(f"❌ File not found: {eb2_path}")
        sys.exit(1)
    
    analyze_eb2(eb2_path)
    
    print("\n" + "="*60)
    print("✅ Analysis complete!")
    print("="*60)
    print("\nNext steps:")
    print("  1. Compare with disk-extracted bank")
    print("  2. Identify compression algorithm")
    print("  3. Implement Swift decoder")

if __name__ == '__main__':
    main()
