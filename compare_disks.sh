#!/bin/bash

NEW="new boot/HD10.hda"
WORKING="SD_BOOT2/Funkar/HD10.hda"

echo "=== HEADER (first 512 bytes) ==="
diff <(xxd -l 512 "$NEW") <(xxd -l 512 "$WORKING") || echo "✅ Headers identical"

echo -e "\n=== FAT (0x4000-0x8000) ==="
diff <(xxd -s 0x4000 -l 16384 "$NEW") <(xxd -s 0x8000 -l 16384 "$WORKING") || echo "✅ FAT identical"

echo -e "\n=== CATALOG (0x8000-0xC000) ==="
diff <(xxd -s 0x8000 -l 16384 "$NEW") <(xxd -s 0xC000 -l 16384 "$WORKING") || echo "✅ Catalog identical"

echo -e "\n=== OS CLUSTER (starts at 0x83E00) ==="
diff <(xxd -s 0x83E00 -l 1024 "$NEW") <(xxd -s 0x83E00 -l 1024 "$WORKING") || echo "✅ OS cluster identical"

echo -e "\n=== File sizes ==="
ls -lh "$NEW" "$WORKING"
