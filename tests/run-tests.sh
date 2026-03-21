#!/bin/bash
# EmaxForge AppleScript Test Runner
# Runs all tests and generates report

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TESTS_DIR="$SCRIPT_DIR/applescript"
LOGS_DIR="$SCRIPT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$LOGS_DIR/test-report-$TIMESTAMP.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure logs directory exists
mkdir -p "$LOGS_DIR"

# Clear old test result log
rm -f "$LOGS_DIR/test-results.log"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   EmaxForge AppleScript Test Suite    ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo ""

# Initialize report
{
    echo "EmaxForge Test Report"
    echo "====================="
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "User: $(whoami)"
    echo "Host: $(hostname)"
    echo ""
} > "$REPORT_FILE"

# Test counter
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run a single test
run_test() {
    local test_file=$1
    local test_name=$(basename "$test_file" .scpt)
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "${BLUE}Running:${NC} $test_name"
    echo "----------------------------------------"
    
    # Run test and capture output
    TEST_START=$(date +%s)
    if output=$(osascript "$test_file" 2>&1); then
        TEST_END=$(date +%s)
        TEST_DURATION=$((TEST_END - TEST_START))
        
        if [[ "$output" == *"✅ PASS"* ]]; then
            echo -e "${GREEN}✅ PASS${NC} ($TEST_DURATION seconds)"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            {
                echo "[$test_name] PASS ($TEST_DURATION s)"
                echo "$output"
                echo ""
            } >> "$REPORT_FILE"
        else
            echo -e "${RED}❌ FAIL${NC} ($TEST_DURATION seconds)"
            echo "$output"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            {
                echo "[$test_name] FAIL ($TEST_DURATION s)"
                echo "$output"
                echo ""
            } >> "$REPORT_FILE"
        fi
    else
        TEST_END=$(date +%s)
        TEST_DURATION=$((TEST_END - TEST_START))
        echo -e "${RED}❌ FAIL${NC} (crashed/error after $TEST_DURATION seconds)"
        echo "$output"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        {
            echo "[$test_name] FAIL (crashed after $TEST_DURATION s)"
            echo "$output"
            echo ""
        } >> "$REPORT_FILE"
    fi
    
    echo ""
    sleep 2 # Cool-down between tests
}

# Run all tests
echo -e "${YELLOW}Discovering tests...${NC}"
echo ""

# Test discovery
TESTS=(
    "$TESTS_DIR/test-image-list.applescript"
    "$TESTS_DIR/test-boot-disk.applescript"
)

# Add any additional test-*.applescript files found
for test_file in "$TESTS_DIR"/test-*.applescript; do
    if [[ -f "$test_file" ]]; then
        # Check if not already in list
        if [[ ! " ${TESTS[@]} " =~ " ${test_file} " ]]; then
            TESTS+=("$test_file")
        fi
    fi
done

echo -e "${YELLOW}Found ${#TESTS[@]} tests${NC}"
echo ""

# Run each test
for test in "${TESTS[@]}"; do
    if [[ -f "$test" ]]; then
        run_test "$test"
    fi
done

# Summary
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Test Summary                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo "Total Tests:  $TOTAL_TESTS"
echo -e "Passed:       ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed:       ${RED}$FAILED_TESTS${NC}"
echo ""

# Write summary to report
{
    echo "SUMMARY"
    echo "======="
    echo "Total:  $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo ""
    echo "Detailed results logged to: $LOGS_DIR/test-results.log"
} >> "$REPORT_FILE"

echo -e "${BLUE}Report saved:${NC} $REPORT_FILE"
echo -e "${BLUE}Detailed log:${NC} $LOGS_DIR/test-results.log"
echo ""

# Exit code
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}All tests passed! 🎉${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed 😞${NC}"
    exit 1
fi
