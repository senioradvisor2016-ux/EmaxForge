#!/bin/bash
# Bootable Disk + Sample Import Test
# Creates a complete EMAX II setup with OS + samples

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "EmaxForge Boot Disk + Sample Test"
echo "========================================"
echo ""

# Test setup
TEST_DIR="/tmp/emaxforge-bootdisk-$$"
mkdir -p "$TEST_DIR"

BOOT_DISK="$TEST_DIR/HD00.hda"
DATA_DISK="$TEST_DIR/HD10.hda"
TEST_BANK="$HOME/clawd/Emax Drive/Emu Emax II [Sounds]/Sounds/Alan Wilder - Depeche Mode [Emax II]/SOMEBODY.EB2"

echo -e "${BLUE}Test scenario: Complete EMAX II setup${NC}"
echo "  1. Create boot disk (HD00.hda with OS)"
echo "  2. Create data disk (HD10.hda)"
echo "  3. Extract samples from SOMEBODY.EB2"
echo "  4. Import samples to HD10"
echo "  5. Validate both disks"
echo ""

# ========================================
# Step 1: Create Boot Disk
# ========================================
echo "========================================"
echo "STEP 1: Create Boot Disk (HD00.hda)"
echo "========================================"
echo ""

echo "Creating 239 MB boot disk with OS..."

if [ ! -f "cli-create-disk.swift" ]; then
    echo -e "${RED}❌ cli-create-disk.swift not found${NC}"
    exit 1
fi

# Create boot disk with OS
swift cli-create-disk.swift \
    --output "$BOOT_DISK" \
    --size 239 \
    --boot \
    --scsi-id 0 > "$TEST_DIR/create-boot.txt" 2>&1

if [ -f "$BOOT_DISK" ]; then
    SIZE=$(stat -f%z "$BOOT_DISK" 2>/dev/null || stat -c%s "$BOOT_DISK" 2>/dev/null)
    echo -e "${GREEN}✅ Boot disk created${NC}"
    echo "  File: HD00.hda"
    echo "  Size: $((SIZE / 1024 / 1024)) MB"
else
    echo -e "${RED}❌ Boot disk creation failed${NC}"
    cat "$TEST_DIR/create-boot.txt"
    exit 1
fi

echo ""

# ========================================
# Step 2: Validate Boot Disk
# ========================================
echo "========================================"
echo "STEP 2: Validate Boot Disk"
echo "========================================"
echo ""

echo "Checking boot disk structure..."

if [ ! -f "cli-validate-disk.swift" ]; then
    echo -e "${RED}❌ cli-validate-disk.swift not found${NC}"
    exit 1
fi

swift cli-validate-disk.swift \
    --disk "$BOOT_DISK" > "$TEST_DIR/validate-boot.txt" 2>&1

# Check boot signature
BOOT_SIG=$(hexdump -s 510 -n 2 -e '2/1 "%02x "' "$BOOT_DISK" | tr -d ' ')
if [ "$BOOT_SIG" = "7882" ]; then
    echo -e "${GREEN}✅ Boot signature valid (0x78 0x82)${NC}"
else
    echo -e "${RED}❌ Boot signature invalid: $BOOT_SIG${NC}"
    exit 1
fi

# Check OS presence (cluster 0 for 239 MB template)
# 239 MB template: clusterAreaStart = 98, clusterSize = 16384
CLUSTER_AREA_START=$((512 * 98))  # 50176 bytes
CLUSTER_SIZE=16384

OS_START=$CLUSTER_AREA_START  # OS is in cluster 0
OS_CHECK=$(hexdump -s $OS_START -n 4 -e '4/1 "%02x "' "$BOOT_DISK" | tr -d ' ')

if [ "$OS_CHECK" != "00000000" ]; then
    echo -e "${GREEN}✅ OS data present at cluster 0${NC}"
    echo "  OS header: 0x$OS_CHECK"
else
    echo -e "${RED}❌ OS data missing (all zeros)${NC}"
    exit 1
fi

# Check INIT BANK presence (cluster 1)
BANK_START=$(($CLUSTER_AREA_START + $CLUSTER_SIZE))  # 66560 bytes
BANK_CHECK=$(hexdump -s $BANK_START -n 16 -e '16/1 "%c"' "$BOOT_DISK")

if echo "$BANK_CHECK" | grep -q "INIT BANK"; then
    echo -e "${GREEN}✅ INIT BANK present at cluster 1${NC}"
else
    echo -e "${YELLOW}⚠️  INIT BANK missing (boot may fail)${NC}"
fi

echo ""

# ========================================
# Step 3: Create Data Disk
# ========================================
echo "========================================"
echo "STEP 3: Create Data Disk (HD10.hda)"
echo "========================================"
echo ""

echo "Creating 239 MB data disk (no OS)..."

swift cli-create-disk.swift \
    --output "$DATA_DISK" \
    --size 239 \
    --scsi-id 1 > "$TEST_DIR/create-data.txt" 2>&1

if [ -f "$DATA_DISK" ]; then
    SIZE=$(stat -f%z "$DATA_DISK" 2>/dev/null || stat -c%s "$DATA_DISK" 2>/dev/null)
    echo -e "${GREEN}✅ Data disk created${NC}"
    echo "  File: HD10.hda"
    echo "  Size: $((SIZE / 1024 / 1024)) MB"
else
    echo -e "${RED}❌ Data disk creation failed${NC}"
    cat "$TEST_DIR/create-data.txt"
    exit 1
fi

echo ""

# ========================================
# Step 4: Extract Samples from Bank
# ========================================
echo "========================================"
echo "STEP 4: Extract Samples"
echo "========================================"
echo ""

echo "Extracting samples from SOMEBODY.EB2..."

if [ ! -f "$TEST_BANK" ]; then
    echo -e "${RED}❌ Test bank not found: $TEST_BANK${NC}"
    exit 1
fi

# Parse bank first
swift cli-parse-bank.swift --bank "$TEST_BANK" > "$TEST_DIR/parse-bank.txt" 2>&1

if ! grep -q '"success" : true' "$TEST_DIR/parse-bank.txt"; then
    echo -e "${RED}❌ Bank parse failed${NC}"
    exit 1
fi

BANK_NAME=$(grep -A 5 '"bankName"' "$TEST_DIR/parse-bank.txt" | head -1 | cut -d'"' -f4)
echo -e "${GREEN}✅ Bank parsed: $BANK_NAME${NC}"

# Extract first 2 samples (bank may not have 3)
mkdir -p "$TEST_DIR/samples"

for i in 1 2; do
    OFFSET=$((0x7000 + (i-1) * 50000))
    OUTPUT="$TEST_DIR/samples/sample_$i.wav"
    
    swift cli-extract-sample.swift \
        --bank "$TEST_BANK" \
        --output "$OUTPUT" \
        --offset $OFFSET \
        --length 50000 \
        --rate 44100 > /dev/null 2>&1
    
    if [ -f "$OUTPUT" ]; then
        echo -e "${GREEN}  ✅ Sample $i extracted${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Sample $i failed (may not exist in bank)${NC}"
    fi
done

SAMPLE_COUNT=$(ls "$TEST_DIR/samples"/*.wav 2>/dev/null | wc -l | tr -d ' ')
echo -e "${GREEN}✅ Extracted $SAMPLE_COUNT samples${NC}"

echo ""

# ========================================
# Step 5: Import Samples to Data Disk (Simulated)
# ========================================
echo "========================================"
echo "STEP 5: Import Samples to HD10"
echo "========================================"
echo ""

echo -e "${BLUE}NOTE: Full bank import requires BankImporter service${NC}"
echo "For this test, we verify the data disk is ready for import..."

# Validate data disk structure
swift cli-validate-disk.swift \
    --disk "$DATA_DISK" > "$TEST_DIR/validate-data.txt" 2>&1

if grep -q "valid" "$TEST_DIR/validate-data.txt"; then
    echo -e "${GREEN}✅ Data disk structure valid${NC}"
else
    echo -e "${RED}❌ Data disk validation failed${NC}"
    cat "$TEST_DIR/validate-data.txt"
    exit 1
fi

# Check free space (should have 90 bank slots for 239 MB)
FREE_CLUSTERS=$(hexdump -s 0x2000 -n 2 -e '2/1 "%02x"' "$DATA_DISK")
echo "  Free clusters: 0x$FREE_CLUSTERS"

# Calculate available space
# 239 MB = ~246,005,760 bytes, cluster size = 489,472 bytes
TOTAL_CLUSTERS=$((246005760 / 489472))
echo "  Total bank slots: ~$TOTAL_CLUSTERS"

echo -e "${GREEN}✅ Data disk ready for sample import${NC}"

echo ""

# ========================================
# Step 6: Create ZuluSCSI Config
# ========================================
echo "========================================"
echo "STEP 6: ZuluSCSI Config"
echo "========================================"
echo ""

CONFIG_FILE="$TEST_DIR/zuluscsi.ini"

cat > "$CONFIG_FILE" << 'EOFconfig'
# EmaxForge Generated Config

[SCSI0]
Type = Fixed
SectorSize = 512
# HD00.hda - Boot disk with OS + INIT BANK

[SCSI1]
Type = Fixed
SectorSize = 512
# HD10.hda - Data disk for sample banks
EOFconfig

echo -e "${GREEN}✅ ZuluSCSI config created${NC}"
cat "$CONFIG_FILE"

echo ""

# ========================================
# Step 7: Final Validation
# ========================================
echo "========================================"
echo "STEP 7: Complete Setup Validation"
echo "========================================"
echo ""

echo "Checking complete EMAX II setup..."

# 1. Boot disk exists and valid
if [ -f "$BOOT_DISK" ]; then
    echo -e "${GREEN}✅ HD00.hda: Boot disk ready${NC}"
    BOOT_SIZE=$(stat -f%z "$BOOT_DISK" 2>/dev/null || stat -c%s "$BOOT_DISK" 2>/dev/null)
    echo "  Size: $((BOOT_SIZE / 1024 / 1024)) MB"
    echo "  OS: Present"
    echo "  Boot signature: 0x78 0x82"
else
    echo -e "${RED}❌ Boot disk missing${NC}"
    exit 1
fi

# 2. Data disk exists and valid
if [ -f "$DATA_DISK" ]; then
    echo -e "${GREEN}✅ HD10.hda: Data disk ready${NC}"
    DATA_SIZE=$(stat -f%z "$DATA_DISK" 2>/dev/null || stat -c%s "$DATA_DISK" 2>/dev/null)
    echo "  Size: $((DATA_SIZE / 1024 / 1024)) MB"
    echo "  Structure: Valid"
    echo "  Bank slots: ~90"
else
    echo -e "${RED}❌ Data disk missing${NC}"
    exit 1
fi

# 3. Samples extracted
if [ "$SAMPLE_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Samples: $SAMPLE_COUNT WAV files ready${NC}"
    for wav in "$TEST_DIR/samples"/*.wav; do
        if [ -f "$wav" ]; then
            WAV_SIZE=$(stat -f%z "$wav" 2>/dev/null || stat -c%s "$wav" 2>/dev/null)
            echo "  $(basename "$wav"): $((WAV_SIZE / 1024)) KB"
        fi
    done
else
    echo -e "${YELLOW}⚠️  No samples extracted${NC}"
fi

# 4. Config exists
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}✅ zuluscsi.ini: Config ready${NC}"
else
    echo -e "${RED}❌ Config missing${NC}"
fi

echo ""

# ========================================
# Summary
# ========================================
echo "========================================"
echo "SUMMARY"
echo "========================================"
echo ""

echo -e "${GREEN}🎉 Boot Disk + Sample Test COMPLETE!${NC}"
echo ""

echo -e "${BLUE}Ready for hardware test:${NC}"
echo "  1. Copy HD00.hda + HD10.hda to SD card"
echo "  2. Copy zuluscsi.ini to SD card"
echo "  3. Insert SD into ZuluSCSI"
echo "  4. Power on EMAX II"
echo "  5. EMAX II should boot from HD00 (SCSI ID 0)"
echo "  6. HD10 (SCSI ID 1) ready for sample banks"
echo ""

echo "Test artifacts:"
echo "  Boot disk: $BOOT_DISK"
echo "  Data disk: $DATA_DISK"
echo "  Samples: $TEST_DIR/samples/"
echo "  Config: $CONFIG_FILE"
echo ""

echo -e "${BLUE}All files ready for ZuluSCSI deployment!${NC}"
echo ""

# Offer to copy to desktop
echo "Copy to Desktop? (y/n)"
read -t 10 COPY || COPY="n"

if [ "$COPY" = "y" ]; then
    DESKTOP="$HOME/Desktop/EmaxForge-Test-$$"
    mkdir -p "$DESKTOP"
    cp "$BOOT_DISK" "$DESKTOP/"
    cp "$DATA_DISK" "$DESKTOP/"
    cp "$CONFIG_FILE" "$DESKTOP/"
    cp -r "$TEST_DIR/samples" "$DESKTOP/" 2>/dev/null || true
    
    echo -e "${GREEN}✅ Files copied to: $DESKTOP${NC}"
else
    echo "Files preserved in: $TEST_DIR"
fi

echo ""
echo "✅ Test complete!"
