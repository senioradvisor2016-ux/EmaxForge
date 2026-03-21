#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "🔍 EMXP vs EmaxForge Verification Suite"
echo "========================================"
echo ""

# 1. Exportera alla banker från EmaxII-02 via EmaxForge
echo "📦 Exporting all banks from EmaxII-02.EZ2..."
swift verification/export_all_banks.swift \
  ~/clawd/emxp/Images/EmaxII-02.EZ2 \
  verification/emaxforge-output

# 2. Jämför mot EMXP gold standard
echo ""
echo "🔬 Comparing EmaxForge output vs EMXP gold standard..."
swift verification/compare_banks.swift

echo ""
echo "✅ Verification complete!"
