#!/bin/bash

WORKING="SD_BOOT2/Funkar/HD10.hda"

# Search for all EMAX-related strings and their offsets
echo "=== All EMAX/diagnostic strings ==="
grep -abo "EMAX\|Enter Code\|Not.*drive\|Diagnostics" "$WORKING" | head -10

# Check what's at clusterAreaStart (sector 98 = 50176 bytes)
echo -e "\n=== Data at clusterAreaStart (0xC400 = 50176) ==="
xxd -s 50176 -l 128 "$WORKING" | head -8

# Check cluster 1 (clusterAreaStart + clusterSize)
# For 239MB: sector 98 + 956 sectors = sector 1054
# 1054 * 512 = 539,648 = 0x83E00
echo -e "\n=== Data at cluster 1 (0x83E00 = 539648) ==="
xxd -s 539648 -l 128 "$WORKING" | head -8
