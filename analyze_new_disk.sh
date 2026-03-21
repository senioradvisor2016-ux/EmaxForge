#!/bin/bash

WORKING="SD_BOOT2/Funkar/HD10.hda"
NEW="/Volumes/ZULUSCI/HD10.hda"

echo "🔍 Analyzing NEW boot disk vs WORKING disk"
echo "=========================================="

echo -e "\n=== 1. Status Byte (0x200) ==="
echo "Working: $(xxd -s 0x200 -l 1 -p $WORKING)"
echo "New:     $(xxd -s 0x200 -l 1 -p $NEW)"

echo -e "\n=== 2. FAT Entry 0 (0x400) ==="
echo "Working: $(xxd -s 0x400 -l 4 -p $WORKING)"
echo "New:     $(xxd -s 0x400 -l 4 -p $NEW)"

echo -e "\n=== 3. Catalog Entry 0 (0x1000) ==="
echo "Working:"
xxd -s 0x1000 -l 32 "$WORKING"
echo -e "\nNew:"
xxd -s 0x1000 -l 32 "$NEW"

echo -e "\n=== 4. OS at Cluster 0 (0xC400) ==="
echo "Working:"
xxd -s 0xC400 -l 64 "$WORKING" | head -4
echo -e "\nNew:"
xxd -s 0xC400 -l 64 "$NEW" | head -4

echo -e "\n=== 5. OS Strings Check ==="
echo "Working:"
strings "$WORKING" | grep -i "not emax2 drive" | head -1
echo "New:"
strings "$NEW" | grep -i "not emax2 drive" | head -1

echo -e "\n=== 6. Boot Signature (0x1FE) ==="
echo "Working: $(xxd -s 0x1FE -l 2 -p $WORKING)"
echo "New:     $(xxd -s 0x1FE -l 2 -p $NEW)"

echo -e "\n=== 7. First Difference ==="
diff <(xxd -l 100000 "$WORKING") <(xxd -l 100000 "$NEW") | head -20
