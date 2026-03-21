#!/bin/bash

WORKING="SD_BOOT2/Funkar/HD10.hda"

# 68000 programs start with:
# 0x00000000-0x00000003: Initial Stack Pointer (ISP)
# 0x00000004-0x00000007: Initial Program Counter (IPC)
# These are typically high addresses (ROM at 0x00F00000+ or RAM at 0x00010000+)

echo "=== Sector 1 (offset 512 = potential boot loader) ==="
xxd -s 512 -l 128 "$WORKING"

echo -e "\n=== Sector 2 (offset 1024) ==="
xxd -s 1024 -l 128 "$WORKING"

echo -e "\n=== clusterAreaStart (offset 50176 = 0xC400, sector 98) ==="
xxd -s 50176 -l 128 "$WORKING"

# Check for 68000 code signature: MOVE.L, JMP, BSR, etc.
# Common boot sequence would be at a sector boundary
echo -e "\n=== Search for potential 68000 bootloader (sectors 1-10) ==="
for sector in {1..10}; do
  offset=$((sector * 512))
  first_long=$(xxd -s $offset -l 4 -p "$WORKING")
  if [[ ! "$first_long" =~ ^0+$ ]]; then
    echo "Sector $sector (offset $offset): $first_long"
  fi
done
