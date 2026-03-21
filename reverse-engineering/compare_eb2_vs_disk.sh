#!/bin/bash
# Compare .EB2 file with disk-extracted bank data
# Goal: Find compression algorithm

set -e

EB2_FILE="$HOME/clawd/emxp/Banks_Sorted/HD50_CLASSIC/TR909 Drums.EB2"
DISK_FILE="$HOME/clawd/EMAXII_EMULOTION.EZ2"
OUTPUT_DIR="$HOME/clawd/EmaxForge/reverse-engineering/comparison"

mkdir -p "$OUTPUT_DIR"

echo "🔬 Comparing .EB2 vs Disk-extracted bank"
echo "============================================"
echo ""
echo "EB2 file:  $EB2_FILE"
echo "Disk file: $DISK_FILE"
echo ""

# Extract bank from disk using Python
python3 << 'PYTHON'
import struct
import sys
from pathlib import Path

disk_path = Path("$DISK_FILE".replace('$HOME', str(Path.home())))
output_dir = Path("$OUTPUT_DIR".replace('$HOME', str(Path.home())))

print("📀 Reading disk image...")
data = disk_path.read_bytes()

# Find "TR909 Drums" in catalog
catalog_start = 0x1000
entry_size = 64

print("🔍 Searching for 'TR909 Drums' in catalog...")

for i in range(320):
    offset = catalog_start + (i * entry_size)
    entry = data[offset:offset+entry_size]
    
    name_bytes = entry[0:16]
    name = name_bytes.decode('ascii', errors='ignore').strip('\x00').strip()
    
    if "TR909" in name or "909" in name:
        print(f"✅ Found: '{name}' at catalog entry {i}")
        
        cluster = struct.unpack("<H", entry[0x12:0x14])[0]
        size = struct.unpack("<H", entry[0x14:0x16])[0]
        flags = struct.unpack("<H", entry[0x1A:0x1C])[0]
        
        print(f"   Cluster: {cluster}")
        print(f"   Size: {size} clusters ({size * 956 * 512} bytes)")
        print(f"   Flags: 0x{flags:04x}")
        
        # Extract bank data
        cluster_area_start = 98 * 512
        cluster_size = 956 * 512
        offset = cluster_area_start + (cluster * cluster_size)
        
        bank_data = data[offset:offset + (size * cluster_size)]
        
        output_file = output_dir / "TR909_from_disk.raw"
        output_file.write_bytes(bank_data)
        
        print(f"💾 Extracted {len(bank_data)} bytes to: {output_file}")
        break
else:
    print("❌ Bank not found on disk!")
    sys.exit(1)
PYTHON

echo ""
echo "📊 Comparing files..."
echo ""

EB2_SIZE=$(stat -f%z "$EB2_FILE")
DISK_SIZE=$(stat -f%z "$OUTPUT_DIR/TR909_from_disk.raw")

echo "File sizes:"
echo "  .EB2 file:       $EB2_SIZE bytes"
echo "  Disk-extracted:  $DISK_SIZE bytes"
echo ""

if [ "$EB2_SIZE" -eq "$DISK_SIZE" ]; then
    echo "✅ SAME SIZE - files might be identical!"
    echo ""
    echo "Byte-by-byte comparison:"
    if diff "$EB2_FILE" "$OUTPUT_DIR/TR909_from_disk.raw" > /dev/null 2>&1; then
        echo "✅✅✅ FILES ARE IDENTICAL! NO COMPRESSION!"
        echo ""
        echo "🎉 DISCOVERY: .EB2 format = RAW disk bank data!"
    else
        echo "❌ Files differ - analyzing differences..."
        xxd "$EB2_FILE" > "$OUTPUT_DIR/eb2.hex"
        xxd "$OUTPUT_DIR/TR909_from_disk.raw" > "$OUTPUT_DIR/disk.hex"
        
        diff "$OUTPUT_DIR/eb2.hex" "$OUTPUT_DIR/disk.hex" > "$OUTPUT_DIR/diff.txt" || true
        
        echo "First 20 differences:"
        head -20 "$OUTPUT_DIR/diff.txt"
    fi
else
    echo "⚠️  DIFFERENT SIZES - compression or header present"
    
    RATIO=$(python3 -c "print(f'{($EB2_SIZE / $DISK_SIZE * 100):.1f}%')")
    echo "Compression ratio: $RATIO"
    
    echo ""
    echo "Analyzing header (first 256 bytes):"
    xxd -l 256 "$EB2_FILE" > "$OUTPUT_DIR/eb2_header.hex"
    xxd -l 256 "$OUTPUT_DIR/TR909_from_disk.raw" > "$OUTPUT_DIR/disk_header.hex"
    
    diff "$OUTPUT_DIR/eb2_header.hex" "$OUTPUT_DIR/disk_header.hex" || true
fi

echo ""
echo "✅ Comparison complete! Check: $OUTPUT_DIR/"
