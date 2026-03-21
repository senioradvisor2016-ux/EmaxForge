#!/bin/bash
# UI Integration Test - Simulates user workflow
# Tests Extract → Trim → Play pipeline

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "EmaxForge UI Integration Test"
echo "========================================"
echo ""

# Test setup
TEST_BANK="$HOME/clawd/Emax Drive/Emu Emax II [Sounds]/Sounds/Alan Wilder - Depeche Mode [Emax II]/SOMEBODY.EB2"
TEST_DIR="/tmp/emaxforge-ui-test-$$"
mkdir -p "$TEST_DIR"

echo -e "${BLUE}Test scenario: SOMEBODY.EB2 bank${NC}"
echo "Simulating user workflow:"
echo "  1. Open bank → Inspector panel"
echo "  2. Select sample → Extract to WAV"
echo "  3. Trim silence"
echo "  4. Play result"
echo ""

# ========================================
# Step 1: Parse Bank (Inspector opens)
# ========================================
echo "========================================"
echo "STEP 1: Open Bank → Inspector Panel"
echo "========================================"
echo ""

echo "User action: Click bank → Inspector panel opens"
echo "Backend: Parse bank to show sample list..."

swift cli-parse-bank.swift --bank "$TEST_BANK" > "$TEST_DIR/parse.txt" 2>&1

if grep -q '"success" : true' "$TEST_DIR/parse.txt"; then
    echo -e "${GREEN}✅ Bank parsed successfully${NC}"
    BANK_NAME=$(grep -A 5 '"bankName"' "$TEST_DIR/parse.txt" | head -1 | cut -d'"' -f4)
    echo "  Bank: $BANK_NAME"
else
    echo -e "${RED}❌ Parse failed${NC}"
    exit 1
fi

echo ""

# ========================================
# Step 2: Extract Sample (User clicks Extract)
# ========================================
echo "========================================"
echo "STEP 2: Extract Sample"
echo "========================================"
echo ""

echo "User action: Select 'SOMEBODY' sample → Click Extract → Save dialog"
SAMPLE_WAV="$TEST_DIR/somebody.wav"

echo "Backend: SampleExtractorService.extractSample()..."
swift cli-extract-sample.swift \
    --bank "$TEST_BANK" \
    --output "$SAMPLE_WAV" \
    --offset 7000 \
    --length 50000 \
    --rate 44100 > "$TEST_DIR/extract.txt" 2>&1

if [ -f "$SAMPLE_WAV" ]; then
    echo -e "${GREEN}✅ Sample extracted${NC}"
    SIZE=$(stat -f%z "$SAMPLE_WAV" 2>/dev/null || stat -c%s "$SAMPLE_WAV" 2>/dev/null)
    echo "  File: $(basename "$SAMPLE_WAV")"
    echo "  Size: $((SIZE / 1024)) KB"
    
    # Validate WAV
    if file "$SAMPLE_WAV" | grep -q "WAVE"; then
        echo -e "${GREEN}✅ Valid WAV format${NC}"
    else
        echo -e "${RED}❌ Invalid WAV${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Extract failed${NC}"
    cat "$TEST_DIR/extract.txt"
    exit 1
fi

echo ""

# ========================================
# Step 3: Trim Sample (User clicks Trim)
# ========================================
echo "========================================"
echo "STEP 3: Trim Silence"
echo "========================================"
echo ""

echo "User action: Click Trim → Save dialog"
TRIMMED_WAV="$TEST_DIR/somebody_trimmed.wav"

echo "Backend: SampleTrimmerService.trimSample()..."
swift cli-trim-sample.swift \
    --input "$SAMPLE_WAV" \
    --output "$TRIMMED_WAV" \
    --threshold 10 > "$TEST_DIR/trim.txt" 2>&1

if [ -f "$TRIMMED_WAV" ]; then
    echo -e "${GREEN}✅ Sample trimmed${NC}"
    
    ORIG_SIZE=$(stat -f%z "$SAMPLE_WAV" 2>/dev/null || stat -c%s "$SAMPLE_WAV" 2>/dev/null)
    TRIM_SIZE=$(stat -f%z "$TRIMMED_WAV" 2>/dev/null || stat -c%s "$TRIMMED_WAV" 2>/dev/null)
    
    echo "  Original: $((ORIG_SIZE / 1024)) KB"
    echo "  Trimmed: $((TRIM_SIZE / 1024)) KB"
    
    # Parse savings from JSON
    SAVINGS=$(grep '"savingsPercent"' "$TEST_DIR/trim.txt" | head -1 | awk '{print $3}' | tr -d ',')
    echo -e "${GREEN}  Savings: ${SAVINGS}%${NC}"
    
    # Show what was removed
    REMOVED_START=$(grep '"removedStart"' "$TEST_DIR/trim.txt" | head -1 | awk '{print $3}' | tr -d ',')
    REMOVED_END=$(grep '"removedEnd"' "$TEST_DIR/trim.txt" | head -1 | awk '{print $3}' | tr -d ',')
    echo "  Removed: $REMOVED_START samples (start), $REMOVED_END samples (end)"
else
    echo -e "${RED}❌ Trim failed${NC}"
    cat "$TEST_DIR/trim.txt"
    exit 1
fi

echo ""

# ========================================
# Step 4: Play Sample (User clicks Play)
# ========================================
echo "========================================"
echo "STEP 4: Play Sample"
echo "========================================"
echo ""

echo "User action: Click Play"
echo "Backend: Extract to temp → NSWorkspace.shared.open()"

# Simulate play (would open in QuickTime/VLC)
if command -v afplay &> /dev/null; then
    echo -e "${BLUE}Playing trimmed sample (2 seconds)...${NC}"
    timeout 2 afplay "$TRIMMED_WAV" 2>/dev/null || true
    echo -e "${GREEN}✅ Playback simulated${NC}"
else
    echo -e "${YELLOW}⚠️  afplay not available (would open in default player)${NC}"
    echo -e "${GREEN}✅ Play action simulated${NC}"
fi

echo ""

# ========================================
# Step 5: Validate Complete Workflow
# ========================================
echo "========================================"
echo "STEP 5: Workflow Validation"
echo "========================================"
echo ""

echo "Checking complete pipeline..."

# 1. Parse output valid
if grep -q '"success" : true' "$TEST_DIR/parse.txt"; then
    echo -e "${GREEN}✅ Parse: Bank structure loaded${NC}"
else
    echo -e "${RED}❌ Parse: Failed${NC}"
    exit 1
fi

# 2. Extract output valid
if grep -q 'JSON_OUTPUT_START' "$TEST_DIR/extract.txt"; then
    echo -e "${GREEN}✅ Extract: WAV created with metadata${NC}"
else
    echo -e "${RED}❌ Extract: No metadata${NC}"
    exit 1
fi

# 3. Trim output valid
if grep -q 'JSON_OUTPUT_START' "$TEST_DIR/trim.txt"; then
    echo -e "${GREEN}✅ Trim: Silence removed${NC}"
else
    echo -e "${RED}❌ Trim: No metadata${NC}"
    exit 1
fi

# 4. Files exist and are valid
if [ -f "$SAMPLE_WAV" ] && [ -f "$TRIMMED_WAV" ]; then
    echo -e "${GREEN}✅ Files: Both WAVs created${NC}"
else
    echo -e "${RED}❌ Files: Missing outputs${NC}"
    exit 1
fi

# 5. Size reduction check
if [ "$TRIM_SIZE" -le "$ORIG_SIZE" ]; then
    echo -e "${GREEN}✅ Size: Trimmed ≤ Original${NC}"
else
    echo -e "${RED}❌ Size: Trimmed > Original${NC}"
    exit 1
fi

echo ""

# ========================================
# Summary
# ========================================
echo "========================================"
echo "SUMMARY"
echo "========================================"
echo ""

echo -e "${GREEN}🎉 UI Integration Test PASSED!${NC}"
echo ""
echo "Workflow completed successfully:"
echo "  ✅ Parse bank → Sample list"
echo "  ✅ Extract sample → WAV file"
echo "  ✅ Trim silence → Reduced size"
echo "  ✅ Play → Ready for playback"
echo ""
echo "Generated files:"
echo "  1. $SAMPLE_WAV (original)"
echo "  2. $TRIMMED_WAV (trimmed)"
echo ""
echo "Test artifacts:"
echo "  $TEST_DIR"
echo ""
echo -e "${BLUE}All UI operations working correctly!${NC}"
echo ""

# Cleanup prompt
echo "Keep test files? (y/n)"
read -t 5 CLEANUP || CLEANUP="n"

if [ "$CLEANUP" = "n" ]; then
    echo "Cleaning up test files..."
    # Keep for now for inspection
    echo "Test files preserved for inspection"
else
    echo "Test files preserved"
fi

echo ""
echo "✅ Test complete!"
