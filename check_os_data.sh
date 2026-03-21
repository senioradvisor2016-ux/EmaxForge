#!/bin/bash

NEW="new boot/HD10.hda"
WORKING="SD_BOOT2/Funkar/HD10.hda"

echo "=== OS CLUSTER (0x83E00) - Working disk ==="
xxd -s 0x83E00 -l 128 "$WORKING" | head -8

echo -e "\n=== OS CLUSTER (0x83E00) - New disk ==="
xxd -s 0x83E00 -l 128 "$NEW" | head -8

echo -e "\n=== Search for 'EMAX' string in working disk ==="
strings "$WORKING" | grep -i emax | head -5

echo -e "\n=== Search for 'EMAX' string in new disk ==="
strings "$NEW" | grep -i emax | head -5
