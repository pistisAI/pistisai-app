#!/bin/bash

# CI Gate: N+1 Query Detection
# Runs detector and validates no NEW N+1 issues are introduced

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
REPORT_FILE="$BACKEND_DIR/n1-detection-report.json"

echo "======================================"
echo "N+1 Query Detection (CI Gate)"
echo "======================================"
echo ""

# Run detector
echo "→ Scanning for N+1 query patterns..."
node "$SCRIPT_DIR/n1-detector.js" "$BACKEND_DIR"

# Check report
if [ ! -f "$REPORT_FILE" ]; then
  echo "ERROR: Report file not generated"
  exit 1
fi

# Parse JSON report
PASSED=$(jq -r '.summary.passed' "$REPORT_FILE")
HIGH_RISK=$(jq -r '.stats.highRisk' "$REPORT_FILE")
MEDIUM_RISK=$(jq -r '.stats.mediumRisk' "$REPORT_FILE")
TOTAL_ISSUES=$(jq -r '.stats.riskiesFound' "$REPORT_FILE")

echo ""
echo "Report summary:"
echo "  Passed: $PASSED"
echo "  High risk: $HIGH_RISK"
echo "  Medium risk: $MEDIUM_RISK"
echo "  Total issues: $TOTAL_ISSUES"
echo ""

# Run Jest test gate
echo "→ Running test gate..."
cd "$BACKEND_DIR"
npm run test:n1

echo ""
echo "✓ N+1 detection gate PASSED"
echo ""
