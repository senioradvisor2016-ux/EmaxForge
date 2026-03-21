#!/bin/bash

# Extract OS from working disk
# OS is at offset 0x83E00 (539,136 bytes) for 239 MB disk
# OS size = one cluster = 489,472 bytes

WORKING="SD_BOOT2/Funkar/HD10.hda"
OUTPUT="EmaxForge/Resources/emax2_os_GOOD.bin"

# Calculate offset for 239 MB disk:
# clusterAreaStart = sector 98 = 50,176 bytes
# clusterSize = 489,472 bytes  
# OS cluster offset = clusterAreaStart + clusterSize = 539,648 bytes = 0x83E00

dd if="$WORKING" of="$OUTPUT" bs=1 skip=539648 count=489472 2>/dev/null

echo "Extracted OS from working disk:"
ls -lh "$OUTPUT"
strings "$OUTPUT" | grep -i emax | head -5
