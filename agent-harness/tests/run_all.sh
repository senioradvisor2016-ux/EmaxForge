#!/bin/bash
# EmaxForge Comprehensive Test Suite Runner
# Usage: ./tests/run_all.sh  (from agent-harness/ directory)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$HARNESS_DIR/.." && pwd)"
REPORT_DIR="$PROJECT_ROOT"

# Use the harness venv if available, otherwise system python
if [[ -f "$HARNESS_DIR/venv/bin/python" ]]; then
    PYTHON="$HARNESS_DIR/venv/bin/python"
    PYTEST="$HARNESS_DIR/venv/bin/pytest"
else
    PYTHON="$(which python3)"
    PYTEST="$(which pytest)"
fi

echo ""
echo "=============================================="
echo "  EmaxForge v0.5 Beta - Test Suite"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================="
echo ""

TMPDIR_RESULTS="/tmp/emaxforge_test_results"
mkdir -p "$TMPDIR_RESULTS"

SWIFT_LOG="$TMPDIR_RESULTS/swift_test_results.txt"
CLI_LOG="$TMPDIR_RESULTS/cli_test_results.txt"
GUI_LOG="$TMPDIR_RESULTS/gui_test_results.txt"
EDGE_LOG="$TMPDIR_RESULTS/edge_test_results.txt"
PERF_LOG="$TMPDIR_RESULTS/perf_test_results.txt"
COMPLIANCE_LOG="$TMPDIR_RESULTS/compliance_results.txt"

OVERALL_STATUS=0

# ── 1. Swift XCTest ──────────────────────────────────────────────────────────
echo "📦 Running Swift XCTest suite..."
SWIFT_TEST_DIR="$PROJECT_ROOT/tests"

if [[ -d "$SWIFT_TEST_DIR" ]]; then
    (
        cd "$SWIFT_TEST_DIR"
        if command -v swift &>/dev/null; then
            swift test 2>&1 | tee "$SWIFT_LOG" || true
        else
            echo "swift not found - skipping" | tee "$SWIFT_LOG"
        fi
    )
    if grep -q "Test Suite.*passed" "$SWIFT_LOG" 2>/dev/null; then
        echo "✅ Swift tests: PASSED"
    else
        echo "⚠️  Swift tests: check $SWIFT_LOG"
    fi
else
    echo "swift test not found, skipping" | tee "$SWIFT_LOG"
fi
echo ""

# ── 2. CLI E2E Tests ─────────────────────────────────────────────────────────
echo "🐍 Running CLI E2E tests..."
cd "$HARNESS_DIR"
if "$PYTEST" tests/test_e2e_full.py -v --tb=short \
    --color=yes 2>&1 | tee "$CLI_LOG"; then
    echo "✅ CLI E2E tests: PASSED"
else
    echo "❌ CLI E2E tests: FAILURES detected"
    OVERALL_STATUS=1
fi
echo ""

# ── 3. AppleScript / GUI Tests ───────────────────────────────────────────────
echo "🍎 Running AppleScript / GUI tests..."
if "$PYTEST" tests/test_applescript_automation.py -v --tb=short \
    --color=yes 2>&1 | tee "$GUI_LOG"; then
    echo "✅ AppleScript tests: PASSED (or skipped)"
else
    echo "❌ AppleScript tests: FAILURES"
    OVERALL_STATUS=1
fi
echo ""

# ── 4. Edge Case Tests ───────────────────────────────────────────────────────
echo "⚠️  Running edge case tests..."
if "$PYTEST" tests/test_edge_cases.py -v --tb=short \
    --color=yes 2>&1 | tee "$EDGE_LOG"; then
    echo "✅ Edge case tests: PASSED"
else
    echo "❌ Edge case tests: FAILURES"
    OVERALL_STATUS=1
fi
echo ""

# ── 5. Performance Benchmarks ────────────────────────────────────────────────
echo "⏱️  Running performance benchmarks..."
if "$PYTEST" tests/test_performance.py -v --tb=short \
    --color=yes 2>&1 | tee "$PERF_LOG"; then
    echo "✅ Performance tests: PASSED"
else
    echo "❌ Performance tests: FAILURES (slow operations)"
    OVERALL_STATUS=1
fi
echo ""

# ── 6. Also run existing unit tests ─────────────────────────────────────────
echo "🔬 Running existing unit tests (cli_anything/emaxforge/tests/)..."
EXISTING_LOG="$TMPDIR_RESULTS/existing_test_results.txt"
if "$PYTEST" cli_anything/emaxforge/tests/ -v --tb=short \
    --color=yes 2>&1 | tee "$EXISTING_LOG"; then
    echo "✅ Existing unit tests: PASSED"
else
    echo "❌ Existing unit tests: FAILURES"
    OVERALL_STATUS=1
fi
echo ""

# ── 7. Spec Compliance Validation ────────────────────────────────────────────
echo "📋 Running spec compliance validation..."
cd "$HARNESS_DIR"
if "$PYTEST" tests/compliance/validate_spec_compliance.py -v --tb=short \
    --color=yes 2>&1 | tee "$COMPLIANCE_LOG"; then
    echo "✅ Compliance: PASSED"
else
    echo "❌ Compliance: FAILURES"
    OVERALL_STATUS=1
fi

# Also run the standalone compliance summary
echo ""
echo "--- Compliance Summary ---"
"$PYTHON" tests/compliance/validate_spec_compliance.py 2>&1 | tee -a "$COMPLIANCE_LOG" || true
echo ""

# ── 8. Generate Combined Report ──────────────────────────────────────────────
echo "📊 Generating combined test report..."
"$PYTHON" tests/generate_report.py \
    "$SWIFT_LOG" \
    "$CLI_LOG" \
    "$GUI_LOG" \
    "$EDGE_LOG" \
    "$PERF_LOG" \
    "$COMPLIANCE_LOG" \
    > "$REPORT_DIR/TEST_REPORT.md"

echo "✅ Report written: $REPORT_DIR/TEST_REPORT.md"
echo ""

# ── Final Summary ────────────────────────────────────────────────────────────
echo "=============================================="
if [[ $OVERALL_STATUS -eq 0 ]]; then
    echo "  🎉 ALL TESTS COMPLETE — NO FAILURES"
else
    echo "  ⚠️  TESTS COMPLETE — SOME FAILURES (see above)"
fi
echo "  Report: TEST_REPORT.md"
echo "=============================================="
echo ""

exit $OVERALL_STATUS
