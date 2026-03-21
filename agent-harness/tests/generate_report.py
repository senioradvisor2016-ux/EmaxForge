"""
Combine test result logs into a single TEST_REPORT.md.

Usage:
    python generate_report.py swift.txt cli.txt gui.txt edge.txt perf.txt compliance.txt
"""

import re
import sys
from datetime import datetime
from pathlib import Path


# ---------------------------------------------------------------------------
# Parsers
# ---------------------------------------------------------------------------

def parse_swift(log: str) -> dict:
    """Parse `swift test` output."""
    # Look for lines like: Test Suite 'All tests' passed/failed at ...
    # and: Executed N tests, with M failures
    passed = failed = skipped = 0
    total_match = re.search(r"Executed (\d+) test[s]?, with (\d+) failure", log)
    if total_match:
        total = int(total_match.group(1))
        failed = int(total_match.group(2))
        passed = total - failed
    # Also look for explicit "passed" and "failed" markers
    if re.search(r"Test Suite .* passed", log):
        status = "passed"
    elif re.search(r"Test Suite .* failed", log):
        status = "failed"
    else:
        status = "unknown"
    return {
        "name": "Swift XCTest",
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "status": status,
        "raw": log[:3000],
    }


def parse_pytest(log: str, name: str) -> dict:
    """Parse pytest output for pass/fail/skip counts."""
    passed = failed = errors = skipped = 0

    # Match: "5 passed, 2 failed, 1 error, 3 skipped"
    m = re.search(r"(\d+) passed", log)
    if m:
        passed = int(m.group(1))
    m = re.search(r"(\d+) failed", log)
    if m:
        failed = int(m.group(1))
    m = re.search(r"(\d+) error", log)
    if m:
        errors = int(m.group(1))
    m = re.search(r"(\d+) skipped", log)
    if m:
        skipped = int(m.group(1))

    if re.search(r"passed", log) and failed == 0 and errors == 0:
        status = "passed"
    elif failed > 0 or errors > 0:
        status = "failed"
    elif skipped > 0 and passed == 0:
        status = "skipped"
    else:
        status = "unknown"

    return {
        "name": name,
        "passed": passed,
        "failed": failed,
        "errors": errors,
        "skipped": skipped,
        "status": status,
        "raw": log[:3000],
    }


def parse_compliance(log: str) -> dict:
    """Parse compliance validator output."""
    pct = 0.0
    m = re.search(r"Compliance:\s*([\d.]+)%", log)
    if m:
        pct = float(m.group(1))
    # Also check JSON compliance output
    m2 = re.search(r'"compliance_percent":\s*([\d.]+)', log)
    if m2:
        pct = float(m2.group(1))

    return {
        "name": "Spec Compliance",
        "compliance_percent": pct,
        "status": "passed" if pct >= 100.0 else ("partial" if pct > 0 else "failed"),
        "raw": log[:2000],
    }


def extract_failures(log: str) -> list[str]:
    """Extract FAILED test lines from pytest output."""
    failures = []
    for line in log.splitlines():
        if line.startswith("FAILED ") or "FAILED" in line and "::" in line:
            failures.append(line.strip())
    return failures[:20]  # cap at 20


def extract_perf_metrics(log: str) -> list[str]:
    """Extract timing lines from performance test output."""
    lines = []
    for line in log.splitlines():
        if "too slow" in line.lower() or "s (limit" in line.lower():
            lines.append(line.strip())
        elif re.search(r"\d+\.\d+s", line):
            lines.append(line.strip())
    return lines[:30]


# ---------------------------------------------------------------------------
# Report generator
# ---------------------------------------------------------------------------

def generate_report(log_files: list[str]) -> str:
    logs = {}
    labels = [
        "swift", "cli_e2e", "applescript", "edge_cases",
        "performance", "compliance"
    ]

    for i, path in enumerate(log_files):
        label = labels[i] if i < len(labels) else f"log_{i}"
        try:
            logs[label] = Path(path).read_text(errors="replace")
        except FileNotFoundError:
            logs[label] = f"(log file not found: {path})"

    # Parse each section
    swift_r    = parse_swift(logs.get("swift", ""))
    cli_r      = parse_pytest(logs.get("cli_e2e", ""), "CLI E2E Tests")
    gui_r      = parse_pytest(logs.get("applescript", ""), "AppleScript / GUI")
    edge_r     = parse_pytest(logs.get("edge_cases", ""), "Edge Case Tests")
    perf_r     = parse_pytest(logs.get("performance", ""), "Performance Tests")
    comp_r     = parse_compliance(logs.get("compliance", ""))

    # Totals
    all_results = [swift_r, cli_r, gui_r, edge_r, perf_r]
    total_passed  = sum(r.get("passed", 0) for r in all_results)
    total_failed  = sum(r.get("failed", 0) + r.get("errors", 0) for r in all_results)
    total_skipped = sum(r.get("skipped", 0) for r in all_results)
    total_tests   = total_passed + total_failed + total_skipped
    overall = "PASS" if total_failed == 0 else "FAIL"

    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    lines = []

    # Header
    lines += [
        f"# EmaxForge v0.5 Beta - Test Report",
        f"",
        f"**Generated:** {now}",
        f"**Overall Status:** {'✅ PASS' if overall == 'PASS' else '❌ FAIL'}",
        f"",
        f"---",
        f"",
        f"## Executive Summary",
        f"",
        f"| Category | Tests | Passed | Failed | Skipped | Status |",
        f"|----------|-------|--------|--------|---------|--------|",
    ]

    def status_icon(r):
        if r["status"] == "passed":
            return "✅ Pass"
        elif r["status"] in ("failed", "error"):
            return "❌ Fail"
        elif r["status"] == "skipped":
            return "⏭ Skip"
        else:
            return "❓ Unknown"

    for r in [swift_r, cli_r, gui_r, edge_r, perf_r]:
        t = r.get("passed", 0) + r.get("failed", 0) + r.get("errors", 0) + r.get("skipped", 0)
        lines.append(
            f"| {r['name']} | {t} | {r.get('passed',0)} | "
            f"{r.get('failed',0) + r.get('errors',0)} | {r.get('skipped',0)} | {status_icon(r)} |"
        )

    # Compliance row
    comp_icon = "✅ Pass" if comp_r["compliance_percent"] >= 100.0 else f"⚠️ {comp_r['compliance_percent']:.0f}%"
    lines.append(f"| {comp_r['name']} | — | — | — | — | {comp_icon} |")

    lines += [
        f"",
        f"**Totals:** {total_passed} passed / {total_failed} failed / {total_skipped} skipped",
        f"**Spec Compliance:** {comp_r['compliance_percent']:.1f}%",
        f"",
        f"---",
        f"",
    ]

    # Swift tests section
    lines += [
        f"## Swift XCTest",
        f"",
        f"- Status: {status_icon(swift_r)}",
        f"- Passed: {swift_r['passed']}",
        f"- Failed: {swift_r['failed']}",
        f"",
    ]
    if swift_r["failed"] > 0:
        lines += [
            f"**Swift Failures:**",
            f"```",
        ]
        lines += extract_failures(swift_r["raw"])
        lines += ["```", ""]

    # CLI E2E section
    lines += [
        f"## CLI E2E Tests",
        f"",
        f"- Status: {status_icon(cli_r)}",
        f"- Passed: {cli_r['passed']}  Failed: {cli_r['failed']}  Skipped: {cli_r['skipped']}",
        f"",
    ]
    cli_failures = extract_failures(cli_r["raw"])
    if cli_failures:
        lines += [f"**Failures:**", "```"] + cli_failures + ["```", ""]

    # AppleScript section
    lines += [
        f"## AppleScript / GUI Tests",
        f"",
        f"- Status: {status_icon(gui_r)}",
        f"- Passed: {gui_r['passed']}  Failed: {gui_r['failed']}  Skipped: {gui_r['skipped']}",
        f"",
        f"> Note: GUI tests requiring EmaxForge.app are automatically skipped in headless environments.",
        f"",
    ]

    # Edge cases section
    lines += [
        f"## Edge Case Tests",
        f"",
        f"- Status: {status_icon(edge_r)}",
        f"- Passed: {edge_r['passed']}  Failed: {edge_r['failed']}  Skipped: {edge_r['skipped']}",
        f"",
    ]
    edge_failures = extract_failures(edge_r["raw"])
    if edge_failures:
        lines += [f"**Failures:**", "```"] + edge_failures + ["```", ""]

    # Performance section
    lines += [
        f"## Performance Benchmarks",
        f"",
        f"- Status: {status_icon(perf_r)}",
        f"- Passed: {perf_r['passed']}  Failed: {perf_r['failed']}  Skipped: {perf_r['skipped']}",
        f"",
    ]
    perf_lines = extract_perf_metrics(logs.get("performance", ""))
    if perf_lines:
        lines += ["**Timing highlights:**", "```"] + perf_lines + ["```", ""]
    perf_failures = extract_failures(perf_r["raw"])
    if perf_failures:
        lines += [f"**Performance Failures:**", "```"] + perf_failures + ["```", ""]

    # Compliance section
    lines += [
        f"## Spec Compliance",
        f"",
        f"- Compliance: {comp_r['compliance_percent']:.1f}%",
        f"- Status: {comp_icon}",
        f"",
    ]
    # Show compliance details from raw log
    for line in comp_r["raw"].splitlines():
        if any(kw in line for kw in ("PASS", "FAIL", "✓", "✗", "Compliance:", "MB")):
            lines.append(f"  {line}")

    # Recommendations
    lines += [
        f"",
        f"---",
        f"",
        f"## Recommendations",
        f"",
    ]
    recs = []
    if total_failed > 0:
        recs.append(f"- Fix {total_failed} failing test(s) before release")
    if comp_r["compliance_percent"] < 100.0:
        recs.append(f"- Investigate spec compliance gaps ({100.0 - comp_r['compliance_percent']:.0f}% non-compliant)")
    if gui_r["skipped"] > 5:
        recs.append("- Run GUI tests with EmaxForge.app running for full coverage")
    if perf_r["failed"] > 0:
        recs.append("- Performance regressions detected - profile slow operations")
    if not recs:
        recs.append("- All tests passing and 100% spec compliant. Ready for release.")
    lines += recs
    lines += ["", "---", "", "*Generated by EmaxForge test suite*"]

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: generate_report.py <log1> [log2] ... [logN]")
        sys.exit(1)

    report = generate_report(sys.argv[1:])
    print(report)
