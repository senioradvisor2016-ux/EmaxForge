#!/bin/bash
# EmaxForge Developer Loop - NO HARDWARE NEEDED!
# Validates EmaxForge disks against validator + working reference

set -e

echo "🔧 EmaxForge Developer Loop"
echo "==========================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

FORGE_DIR=~/clawd/EmaxForge
TEST_DIR=~/Desktop/emaxforge-devloop
WORKING_DISK=~/clawd/SD_BOOT/Funkar/HD10.hda

mkdir -p "$TEST_DIR"

echo -e "${BOLD}📍 Test directory:${NC} $TEST_DIR"
echo -e "${BOLD}📍 Reference disk:${NC} $WORKING_DISK"
echo ""

# Check if EmaxForge is built
if [ ! -f "$FORGE_DIR/.build/EmaxForge.app/Contents/MacOS/EmaxForge" ]; then
    echo -e "${YELLOW}⚙️  Building EmaxForge...${NC}"
    cd "$FORGE_DIR"
    ./build.sh
    echo ""
fi

echo -e "${BLUE}${BOLD}Step 1: Create test disk with EmaxForge${NC}"
echo "----------------------------------------"
echo ""
echo "Opening EmaxForge..."
open "$FORGE_DIR/.build/EmaxForge.app"
echo ""
echo -e "${BOLD}🎯 Instructions:${NC}"
echo "  1. Click 'Create Bootable Disk' wizard"
echo "  2. Select size: ${BOLD}239 MB${NC}"
echo "  3. Include OS: ${BOLD}✓ YES${NC}"
echo "  4. Save as: ${BOLD}$TEST_DIR/test-boot.hda${NC}"
echo ""
echo "Waiting for test-boot.hda to appear..."

# Wait for file
while [ ! -f "$TEST_DIR/test-boot.hda" ]; do
    sleep 1
done

echo -e "${GREEN}✅ File created!${NC}"
echo ""

echo -e "${BLUE}${BOLD}Step 2: Validate disk${NC}"
echo "--------------------"
echo ""

python3 "$FORGE_DIR/validate-boot.py" "$TEST_DIR/test-boot.hda"
VALIDATOR_EXIT=$?
echo ""

if [ $VALIDATOR_EXIT -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✅ VALIDATION PASSED!${NC}"
    echo ""
    echo "EmaxForge disk is byte-perfect compatible!"
    echo ""
    echo "Next steps:"
    echo "  - Test on real EMAX II hardware"
    echo "  - Or continue with UI improvements"
    exit 0
else
    echo -e "${RED}${BOLD}❌ VALIDATION FAILED!${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}🔍 Debug mode${NC}"
    echo ""
    
    # Generate hex diff report
    echo "Generating detailed hex comparison..."
    echo ""
    
    # Compare boot sector
    echo "Boot sector (first 512 bytes):"
    xxd "$WORKING_DISK" | head -32 > "$TEST_DIR/working-boot-sector.txt"
    xxd "$TEST_DIR/test-boot.hda" | head -32 > "$TEST_DIR/test-boot-sector.txt"
    
    if diff -u "$TEST_DIR/working-boot-sector.txt" "$TEST_DIR/test-boot-sector.txt" > "$TEST_DIR/boot-sector-diff.txt"; then
        echo -e "${GREEN}  ✅ Boot sector IDENTICAL${NC}"
    else
        echo -e "${RED}  ❌ Boot sector DIFFERS${NC}"
        echo "     Diff saved to: boot-sector-diff.txt"
    fi
    
    # Compare FAT
    echo "FAT (offsets 0x400-0x800):"
    xxd -s 0x400 -l 0x400 "$WORKING_DISK" > "$TEST_DIR/working-fat.txt"
    xxd -s 0x400 -l 0x400 "$TEST_DIR/test-boot.hda" > "$TEST_DIR/test-fat.txt"
    
    if diff -u "$TEST_DIR/working-fat.txt" "$TEST_DIR/test-fat.txt" > "$TEST_DIR/fat-diff.txt"; then
        echo -e "${GREEN}  ✅ FAT IDENTICAL${NC}"
    else
        echo -e "${RED}  ❌ FAT DIFFERS${NC}"
        echo "     Diff saved to: fat-diff.txt"
    fi
    
    # Compare Catalog
    CATALOG_OFFSET=$(python3 -c "
import struct
with open('$WORKING_DISK', 'rb') as f:
    data = f.read(512)
    cas = struct.unpack_from('<I', data, 0x20)[0]
    print(cas * 512)
")
    
    echo "Catalog (offset 0x$(printf '%X' $CATALOG_OFFSET)):"
    xxd -s "$CATALOG_OFFSET" -l 4896 "$WORKING_DISK" > "$TEST_DIR/working-catalog.txt"
    xxd -s "$CATALOG_OFFSET" -l 4896 "$TEST_DIR/test-boot.hda" > "$TEST_DIR/test-catalog.txt"
    
    if diff -u "$TEST_DIR/working-catalog.txt" "$TEST_DIR/test-catalog.txt" > "$TEST_DIR/catalog-diff.txt"; then
        echo -e "${GREEN}  ✅ Catalog IDENTICAL${NC}"
    else
        echo -e "${RED}  ❌ Catalog DIFFERS${NC}"
        echo "     Diff saved to: catalog-diff.txt"
    fi
    
    echo ""
    echo -e "${BOLD}📂 Debug files created in:${NC}"
    echo "   $TEST_DIR/"
    echo ""
    echo -e "${BOLD}🔧 Next steps:${NC}"
    echo "   1. Review diff files (boot-sector-diff.txt, fat-diff.txt, catalog-diff.txt)"
    echo "   2. Fix ImageCreator.swift based on differences"
    echo "   3. Rebuild EmaxForge: cd $FORGE_DIR && ./build.sh"
    echo "   4. Run this script again: $0"
    echo ""
    
    exit 1
fi
