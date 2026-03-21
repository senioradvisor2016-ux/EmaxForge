#!/bin/bash
# Performance Test - Measure speed of operations

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "EmaxForge Performance Test"
echo "========================================"
echo ""

BANK_DIR="$HOME/clawd/Emax Drive/Emu Emax II [Sounds]/Sounds"
TEST_DIR="/tmp/emaxforge-perf-$$"
mkdir -p "$TEST_DIR"

# Find 20 banks for testing
BANKS=($(find "$BANK_DIR" -name "*.EB2" | head -20))
BANK_COUNT=${#BANKS[@]}

echo -e "${BLUE}Testing with $BANK_COUNT banks${NC}"
echo ""

# ========================================
# Test 1: Parse Speed
# ========================================
echo "========================================"
echo "TEST 1: Parse Speed"
echo "========================================"
echo ""

START=$(date +%s%N)

for bank in "${BANKS[@]}"; do
    swift cli-parse-bank.swift --bank "$bank" > /dev/null 2>&1
done

END=$(date +%s%N)
DURATION=$((($END - $START) / 1000000))  # Convert to milliseconds
PER_BANK=$(($DURATION / $BANK_COUNT))

echo -e "${GREEN}✅ Parsed $BANK_COUNT banks${NC}"
echo "  Total time: ${DURATION}ms"
echo "  Per bank: ${PER_BANK}ms"
echo "  Throughput: $(($BANK_COUNT * 1000 / $DURATION)) banks/sec"

echo ""

# ========================================
# Test 2: Extract Speed
# ========================================
echo "========================================"
echo "TEST 2: Extract Speed (10 samples)"
echo "========================================"
echo ""

TEST_BANK="${BANKS[0]}"
START=$(date +%s%N)

for i in {1..10}; do
    OUTPUT="$TEST_DIR/sample_$i.wav"
    swift cli-extract-sample.swift \
        --bank "$TEST_BANK" \
        --output "$OUTPUT" \
        --offset 7000 \
        --length 50000 \
        --rate 44100 > /dev/null 2>&1
done

END=$(date +%s%N)
DURATION=$((($END - $START) / 1000000))
PER_SAMPLE=$(($DURATION / 10))

echo -e "${GREEN}✅ Extracted 10 samples${NC}"
echo "  Total time: ${DURATION}ms"
echo "  Per sample: ${PER_SAMPLE}ms"
echo "  Throughput: $((10 * 1000 / $DURATION)) samples/sec"

echo ""

# ========================================
# Test 3: Trim Speed
# ========================================
echo "========================================"
echo "TEST 3: Trim Speed (10 samples)"
echo "========================================"
echo ""

START=$(date +%s%N)

for i in {1..10}; do
    INPUT="$TEST_DIR/sample_$i.wav"
    OUTPUT="$TEST_DIR/sample_${i}_trimmed.wav"
    
    if [ -f "$INPUT" ]; then
        swift cli-trim-sample.swift \
            --input "$INPUT" \
            --output "$OUTPUT" \
            --threshold 10 > /dev/null 2>&1
    fi
done

END=$(date +%s%N)
DURATION=$((($END - $START) / 1000000))
PER_SAMPLE=$(($DURATION / 10))

echo -e "${GREEN}✅ Trimmed 10 samples${NC}"
echo "  Total time: ${DURATION}ms"
echo "  Per sample: ${PER_SAMPLE}ms"
echo "  Throughput: $((10 * 1000 / $DURATION)) samples/sec"

echo ""

# ========================================
# Test 4: Build Speed
# ========================================
echo "========================================"
echo "TEST 4: Build Speed"
echo "========================================"
echo ""

cd ~/clawd/EmaxForge

echo "Clean build..."
START=$(date +%s%N)
rm -rf .build/EmaxForge.app
swift build -c release > /dev/null 2>&1 || true
END=$(date +%s%N)
DURATION=$((($END - $START) / 1000000))

echo -e "${GREEN}✅ Clean build completed${NC}"
echo "  Build time: ${DURATION}ms ($(($DURATION / 1000))s)"

echo ""

# Incremental build
touch EmaxForge/Sources/Views/InspectorPanel.swift

echo "Incremental build..."
START=$(date +%s%N)
swift build -c release > /dev/null 2>&1 || true
END=$(date +%s%N)
DURATION=$((($END - $START) / 1000000))

echo -e "${GREEN}✅ Incremental build completed${NC}"
echo "  Build time: ${DURATION}ms ($(($DURATION / 1000))s)"

echo ""

# ========================================
# Summary
# ========================================
echo "========================================"
echo "PERFORMANCE SUMMARY"
echo "========================================"
echo ""

echo -e "${BLUE}Parse Performance:${NC}"
echo "  $PER_BANK ms/bank"
echo ""

echo -e "${BLUE}Extract Performance:${NC}"
echo "  $PER_SAMPLE ms/sample"
echo ""

echo -e "${BLUE}Trim Performance:${NC}"
echo "  $PER_SAMPLE ms/sample"
echo ""

echo -e "${BLUE}Estimated for full library (2877 banks):${NC}"
TOTAL_PARSE_TIME=$((2877 * $PER_BANK / 1000))
echo "  Parse all: ${TOTAL_PARSE_TIME}s (~$(($TOTAL_PARSE_TIME / 60))min)"

echo ""
echo "✅ Performance test complete!"

# Cleanup
rm -rf "$TEST_DIR"
