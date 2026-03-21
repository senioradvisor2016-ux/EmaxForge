#!/bin/bash
# Swift Unit Test Runner for EmaxForge
# Token-efficient testing without UI automation

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
TESTS_DIR="$PROJECT_ROOT/Tests/EmaxForgeTests"
LOGS_DIR="$SCRIPT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$LOGS_DIR/swift-test-report-$TIMESTAMP.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

mkdir -p "$LOGS_DIR"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   EmaxForge Swift Test Suite          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Initialize report
{
    echo "EmaxForge Swift Test Report"
    echo "==========================="
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Host: $(hostname)"
    echo ""
} > "$REPORT_FILE"

# Run Swift tests
echo -e "${BLUE}Running Swift unit tests...${NC}"
echo ""

cd "$PROJECT_ROOT"

if swift test 2>&1 | tee -a "$REPORT_FILE"; then
    echo ""
    echo -e "${GREEN}✅ All Swift tests passed!${NC}"
    {
        echo ""
        echo "RESULT: PASS"
        echo "All unit tests passed successfully"
    } >> "$REPORT_FILE"
    TEST_STATUS=0
else
    echo ""
    echo -e "${RED}❌ Some Swift tests failed${NC}"
    {
        echo ""
        echo "RESULT: FAIL"
        echo "Some unit tests failed - see output above"
    } >> "$REPORT_FILE"
    TEST_STATUS=1
fi

# Run integration tests (file-based)
echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Integration Tests (File-based)      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

INTEGRATION_PASSED=0
INTEGRATION_TOTAL=0

# Test 1: Check for boot disk on Desktop
echo -e "${BLUE}Test: Boot Disk File Check${NC}"
INTEGRATION_TOTAL=$((INTEGRATION_TOTAL + 1))

DESKTOP="$HOME/Desktop"
BOOT_DISKS=("HD00.hda" "HD10.hda" "TEST_HD00.hda" "TEST_HD10.hda")
FOUND_BOOT_DISK=""

for disk in "${BOOT_DISKS[@]}"; do
    if [[ -f "$DESKTOP/$disk" ]]; then
        FOUND_BOOT_DISK="$DESKTOP/$disk"
        break
    fi
done

if [[ -n "$FOUND_BOOT_DISK" ]]; then
    echo -e "${GREEN}✅ Found boot disk: $(basename "$FOUND_BOOT_DISK")${NC}"
    INTEGRATION_PASSED=$((INTEGRATION_PASSED + 1))
    
    # Verify boot signature
    BOOT_SIG=$(xxd -l 2 -s 510 "$FOUND_BOOT_DISK" 2>/dev/null | awk '{print $2}')
    if [[ "$BOOT_SIG" == "7882" ]]; then
        echo -e "${GREEN}  ✓ Boot signature correct (0x78 0x82)${NC}"
    else
        echo -e "${RED}  ✗ Boot signature wrong: 0x$BOOT_SIG${NC}"
    fi
    
    # Verify FAT entry 0
    FAT_ENTRY=$(xxd -l 2 -s 1024 "$FOUND_BOOT_DISK" 2>/dev/null | awk '{print $2}')
    if [[ "$FAT_ENTRY" == "0f00" ]]; then
        echo -e "${GREEN}  ✓ FAT entry 0 correct (0x000F)${NC}"
    else
        echo -e "${YELLOW}  ⚠ FAT entry 0: 0x$FAT_ENTRY (expected 0x0F00)${NC}"
    fi
    
    # Check file size
    SIZE=$(stat -f%z "$FOUND_BOOT_DISK" 2>/dev/null || stat -c%s "$FOUND_BOOT_DISK" 2>/dev/null)
    SIZE_MB=$((SIZE / 1024 / 1024))
    echo -e "${GREEN}  ✓ Size: ${SIZE_MB} MB${NC}"
    
else
    echo -e "${YELLOW}⏭️  No boot disk found on Desktop${NC}"
    echo "  💡 Create a boot disk to run integration tests"
fi

# Test 2: Check for zuluscsi.ini
echo ""
echo -e "${BLUE}Test: ZuluSCSI Config Check${NC}"
INTEGRATION_TOTAL=$((INTEGRATION_TOTAL + 1))

if [[ -f "$DESKTOP/zuluscsi.ini" ]]; then
    echo -e "${GREEN}✅ Found zuluscsi.ini${NC}"
    INTEGRATION_PASSED=$((INTEGRATION_PASSED + 1))
    
    if grep -q "\[SCSI1\]" "$DESKTOP/zuluscsi.ini"; then
        echo -e "${GREEN}  ✓ Contains [SCSI1] section${NC}"
    fi
    
    if grep -q "HD10.hda" "$DESKTOP/zuluscsi.ini"; then
        echo -e "${GREEN}  ✓ References HD10.hda${NC}"
    fi
else
    echo -e "${YELLOW}⏭️  No zuluscsi.ini found${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Test Summary                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo "Swift Unit Tests:   $([ $TEST_STATUS -eq 0 ] && echo -e "${GREEN}PASS${NC}" || echo -e "${RED}FAIL${NC}")"
echo "Integration Tests:  $INTEGRATION_PASSED/$INTEGRATION_TOTAL passed"
echo ""

{
    echo ""
    echo "SUMMARY"
    echo "======="
    echo "Swift Unit Tests: $([ $TEST_STATUS -eq 0 ] && echo "PASS" || echo "FAIL")"
    echo "Integration Tests: $INTEGRATION_PASSED/$INTEGRATION_TOTAL"
} >> "$REPORT_FILE"

echo -e "${BLUE}Report saved:${NC} $REPORT_FILE"
echo ""

# Exit code
if [ $TEST_STATUS -eq 0 ]; then
    echo -e "${GREEN}All tests passed! 🎉${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi
