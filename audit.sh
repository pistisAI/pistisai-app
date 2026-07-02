#!/bin/bash
echo "=== AUDIT ==="
echo ""
echo "--- 1. Dead imports / unused files ---"
echo ""
echo "=== Dead Code: unused imports ==="
cd /c/Users/rightguy/CloudToLocalLLM

# Count dart files
echo "Dart files: $(find . -name '*.dart' -not -path '*/\.*' | wc -l)"

# Find old CloudToLocalLLM references that might have been missed
echo ""
echo "=== Missed brand references ==="
grep -rn "CloudToLocal" --include="*.dart" --include="*.yaml" --include="*.json" --include="*.md" --include="*.bat" --include="*.sh" --include="*.iss" --include="*.txt" --include="*.html" --include="*.yml" . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" | grep -v "build/" | grep -v ".pub-cache/" | grep -v "version.json" | head -30

echo ""
echo "=== Missed old domain references ==="
grep -rn "cloudtolocalllm\.online\|cloud-to-local-llm\|cloud_to_local_llm\|CloudToLocalLLM\|cloudToLocalLLM" --include="*.dart" --include="*.yaml" --include="*.json" --include="*.md" --include="*.bat" --include="*.sh" --include="*.iss" --include="*.html" --include="*.yml" . 2>/dev/null | grep -v ".git/" | grep -v "node_modules/" | grep -v "build/" | head -30

echo ""
echo "=== Dead export files ==="
find . -name "*.dart" -path "*/exports/*" -not -path "*/\.*" 2>/dev/null | head -20

echo ""
echo "=== Setup wizard dead steps ==="
find . -name "*.dart" -path "*/wizard/*" -not -path "*/\.*" 2>/dev/null | head -20

echo ""
echo "=== Files with TODO or FIXME ==="
grep -rn "TODO\|FIXME\|HACK\|XXX" --include="*.dart" . 2>/dev/null | grep -v ".git/" | grep -v "build/" | head -40

echo ""
echo "=== Files with print() or debug statements ==="
grep -rn "print(" --include="*.dart" . 2>/dev/null | grep -v ".git/" | grep -v "build/" | grep -v "// print" | head -30

echo ""
echo "=== Lint check (first 40 issues) ==="
cd /c/Users/rightguy/CloudToLocalLLM
dart analyze lib/ 2>&1 | head -60

echo ""
echo "=== Unused files in lib/ top level ==="
find lib/ -name "*.dart" -not -path "*/\.*" | sort

echo ""
echo "=== Test files ==="
find . -name "*test*" -path "*/test/*" -name "*.dart" -not -path "*/\.*" | sort

echo ""
echo "=== pubspec outdated ==="
cd /c/Users/rightguy/CloudToLocalLLM && dart pub outdated --json 2>/dev/null | head -40
