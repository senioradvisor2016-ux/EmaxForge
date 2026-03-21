#!/bin/bash

WORKING="SD_BOOT2/Funkar/HD10.hda"

echo "=== HEADER (first 512 bytes) ==="
xxd -l 512 "$WORKING" | head -32

echo -e "\n=== Search for boot code patterns (68000 opcodes) ==="
# Common 68000 boot sequences: RESET stack pointer, jump to init
# Pattern: 0x4e71 (NOP), 0x4ef9 (JMP), 0x4e75 (RTS)
hexdump -C "$WORKING" | grep -E "4e (71|f9|75)" | head -5

echo -e "\n=== Strings around offset 78323 ('Not EMAX2 drive') ==="
xxd -s 78300 -l 200 "$WORKING"
