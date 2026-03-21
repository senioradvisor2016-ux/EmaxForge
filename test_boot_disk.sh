#!/bin/bash

echo "🧪 EmaxForge Boot Disk Test - Mar 16, 2026"
echo "==========================================="

WORKING="SD_BOOT2/Funkar/HD10.hda"
TEST_DIR="test_boot_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$TEST_DIR"

echo -e "\n📝 Creating boot disk via CLI..."
# TODO: EmaxForge doesn't have CLI yet - need to use app wizard
echo "⚠️  CLI not available - use app wizard (File → Create Bootable Disk)"
echo ""
echo "Manual steps:"
echo "1. Open EmaxForge.app"
echo "2. File → Create Bootable Disk (⌘B)"
echo "3. Select 239 MB"
echo "4. Save as: $TEST_DIR/HD10.hda"
echo ""
read -p "Press ENTER when disk is created..."

NEW_DISK="$TEST_DIR/HD10.hda"

if [ ! -f "$NEW_DISK" ]; then
    echo "❌ Disk not found: $NEW_DISK"
    exit 1
fi

echo -e "\n🔍 Verifying boot disk structure..."

# 1. Header comparison (first 512 bytes)
echo -e "\n=== Header (sector 0) ==="
if diff <(xxd -l 512 "$WORKING") <(xxd -l 512 "$NEW_DISK") > /dev/null; then
    echo "✅ Header IDENTICAL"
else
    echo "❌ Header DIFFERS"
    diff <(xxd -l 512 "$WORKING") <(xxd -l 512 "$NEW_DISK") | head -10
fi

# 2. Status byte (0x200)
echo -e "\n=== Status Byte (0x200) ==="
WORKING_STATUS=$(xxd -s 0x200 -l 1 -p "$WORKING")
NEW_STATUS=$(xxd -s 0x200 -l 1 -p "$NEW_DISK")
if [ "$WORKING_STATUS" == "$NEW_STATUS" ]; then
    echo "✅ Status byte: 0x$NEW_STATUS (bootable)"
else
    echo "❌ Status byte mismatch: working=0x$WORKING_STATUS, new=0x$NEW_STATUS"
fi

# 3. FAT comparison (0x400-0x1000)
echo -e "\n=== FAT (0x400-0x1000) ==="
if diff <(xxd -s 0x400 -l 3072 "$WORKING") <(xxd -s 0x400 -l 3072 "$NEW_DISK") > /dev/null; then
    echo "✅ FAT IDENTICAL"
else
    echo "❌ FAT DIFFERS"
    diff <(xxd -s 0x400 -l 3072 "$WORKING") <(xxd -s 0x400 -l 3072 "$NEW_DISK") | head -15
fi

# 4. Catalog comparison (0x1000-0x8000)
echo -e "\n=== Catalog (0x1000-0x8000) ==="
if diff <(xxd -s 0x1000 -l 28672 "$WORKING") <(xxd -s 0x1000 -l 28672 "$NEW_DISK") > /dev/null; then
    echo "✅ Catalog IDENTICAL"
else
    echo "⚠️  Catalog DIFFERS (expected - new disk has fewer banks)"
    echo "First catalog entry (OS):"
    xxd -s 0x1000 -l 64 "$NEW_DISK"
fi

# 5. CRITICAL: OS data at cluster 0 (0xC400)
echo -e "\n=== OS Data at Cluster 0 (0xC400) ==="
NEW_OS_START=$(xxd -s 0xC400 -l 16 -p "$NEW_DISK" | head -1)
WORKING_OS_START=$(xxd -s 0xC400 -l 16 -p "$WORKING" | head -1)

echo "Working disk: $WORKING_OS_START"
echo "New disk:     $NEW_OS_START"

if strings -n 10 "$NEW_DISK" | grep -q "Not EMAX2 drive"; then
    echo "✅ OS strings found (Diagnostics, Not EMAX2 drive, etc.)"
else
    echo "❌ OS strings NOT found - OS missing or wrong location!"
fi

# Check if cluster 0 contains OS (not waveforms)
xxd -s 0xC400 -l 128 "$NEW_DISK" | head -8
if xxd -s 0xC400 -l 128 "$NEW_DISK" | grep -q "00f0 0000"; then
    echo "✅ Cluster 0 starts with catalog metadata (expected)"
else
    echo "⚠️  Cluster 0 content unexpected"
fi

# 6. Size check
echo -e "\n=== File Size ==="
WORKING_SIZE=$(stat -f%z "$WORKING")
NEW_SIZE=$(stat -f%z "$NEW_DISK")
if [ "$WORKING_SIZE" == "$NEW_SIZE" ]; then
    echo "✅ Size identical: $WORKING_SIZE bytes"
else
    echo "⚠️  Size differs: working=$WORKING_SIZE, new=$NEW_SIZE"
fi

# Final verdict
echo -e "\n=========================================="
echo "🏁 VERDICT:"
echo "=========================================="
if diff <(xxd -l 50176 "$WORKING") <(xxd -l 50176 "$NEW_DISK") > /dev/null; then
    echo "✅ BOOT AREA (0x0000-0xC400) IDENTICAL!"
    echo "✅ This disk SHOULD boot on EMAX II!"
else
    echo "❌ Boot area differs - disk may not boot"
    echo ""
    echo "Detailed diff:"
    diff <(xxd -l 50176 "$WORKING") <(xxd -l 50176 "$NEW_DISK") | head -30
fi

echo -e "\n📁 Test disk location: $NEW_DISK"
echo "Next: Copy to SD card and test on EMAX II"
