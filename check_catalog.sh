#!/bin/bash

NEW="new boot/HD10.hda"
WORKING="SD_BOOT2/Funkar/HD10.hda"

echo "=== CATALOG ENTRY 0 (OS) - Working disk ==="
xxd -s 0x8000 -l 64 "$WORKING"

echo -e "\n=== CATALOG ENTRY 0 (OS) - New disk ==="
xxd -s 0x8000 -l 64 "$NEW"

echo -e "\n=== CATALOG ENTRY 1 (Bank 1) - Working disk ==="
xxd -s 0x8040 -l 64 "$WORKING"

echo -e "\n=== CATALOG ENTRY 1 (Bank 1) - New disk ==="
xxd -s 0x8040 -l 64 "$NEW"
