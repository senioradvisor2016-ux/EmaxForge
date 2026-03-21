#!/bin/bash

NEW="new boot/HD10.hda"
WORKING="SD_BOOT2/Funkar/HD10.hda"

echo "=== FAT ENTRY 0-1 (OS pointers) - Working disk ==="
xxd -s 0x4000 -l 16 "$WORKING"

echo -e "\n=== FAT ENTRY 0-1 (OS pointers) - New disk ==="
xxd -s 0x4000 -l 16 "$NEW"

echo -e "\n=== FAT ENTRY 0-10 - Working disk ==="
xxd -s 0x4000 -l 64 "$WORKING"

echo -e "\n=== FAT ENTRY 0-10 - New disk ==="
xxd -s 0x4000 -l 64 "$NEW"
