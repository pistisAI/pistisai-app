#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DISCOVER_SCRIPT="$PROJECT_ROOT/scripts/deploy/discover_pistisai_vps_origin.sh"
WORKFLOW_FILE="$PROJECT_ROOT/.github/workflows/deploy-web.yml"
SYNC_SCRIPT="$PROJECT_ROOT/scripts/deploy/sync_cloudflare_install_redirects.py"

for file in "$DISCOVER_SCRIPT" "$SYNC_SCRIPT" "$WORKFLOW_FILE"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing required file: $file" >&2
    exit 1
  fi
done

python3 - <<'PY' "$WORKFLOW_FILE" "$DISCOVER_SCRIPT" "$SYNC_SCRIPT"
from pathlib import Path
import sys

workflow, discover, sync_script = map(Path, sys.argv[1:])
text = workflow.read_text()
checks = [
    "Discover Pistisai VPS origin IP",
    "discover_pistisai_vps_origin.sh",
    "sync_cloudflare_install_redirects.py",
    "Verify live install scripts",
    "PISTISAI_VPS_SSH_HOST",
    "secrets: write",
]
for needle in checks:
    if needle not in text:
        raise SystemExit(f"missing deploy-web workflow wiring: {needle}")

discover_text = discover.read_text()
for needle in [
    "origin_ip",
    "31.97.140.7",
    "cfd_tunnel",
    "/opt/Pistisai",
]:
    if needle not in discover_text:
        raise SystemExit(f"missing discover script marker: {needle}")

sync_text = sync_script.read_text()
for needle in [
    "/install.sh",
    "/install.ps1",
    "sync_dynamic_redirect_rules",
    "sync_page_rules",
]:
    if needle not in sync_text:
        raise SystemExit(f"missing redirect sync marker: {needle}")

print("[test_deploy_web_install_pipeline] Passed")
PY

bash -n "$DISCOVER_SCRIPT"
