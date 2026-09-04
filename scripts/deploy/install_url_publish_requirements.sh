#!/usr/bin/env bash
# Documents the GitHub secrets required to publish install.sh on pistisai.app.
set -euo pipefail

cat <<'EOF'
Pistisai install URL publish requirements
======================================

Production https://pistisai.app/install.sh is broken when BOTH are true:
1. PISTISAI_VPS_SSH_HOST is unset (CI cannot SSH through Cloudflare anycast)
2. CLOUDFLARE_CACHE_PURGE_TOKEN is cache-only (cannot sync redirect rules)

Required secrets (repo: pistisAI/pistisai-app)
----------------------------------------------
PISTISAI_VPS_SSH_HOST
  Origin VPS public IPv4 for cloudllm@<ip>:22
  Never 31.97.140.7 (Simon VPS)
  Discover locally: Cloudflare Zero Trust -> Tunnels -> connector origin IP

CLOUDFLARE_CACHE_PURGE_TOKEN (upgrade or replace)
  Current token: Zone.Cache Purge only
  Needed scopes for edge fallback:
    - Zone Rulesets Edit (dynamic redirect for /install.sh)
    - OR Page Rules Edit
    - Optional: Account Cloudflare Tunnel Read (auto-discovery in CI)

Already present:
  VM_SSH_PRIVATE_KEY, CLOUDFLARE_ZONE_ID

Set secrets:
  gh secret set PISTISAI_VPS_SSH_HOST --body '<origin-ip>'
  gh secret set CLOUDFLARE_CACHE_PURGE_TOKEN --body '<token-with-rulesets-edit>'

Verify after Web Deploy:
  curl -fsSL https://pistisai.app/install.sh | head -1
  # expected: #!/bin/bash

Workaround for users now:
  curl -fsSL https://github.com/pistisAI/pistisai-app/releases/latest/download/install.sh | bash
EOF
