#!/usr/bin/env bash
# Runtime smoke for Cloudflare Access on the tailscale relay.
set -euo pipefail
cd "$(dirname "$0")/../.."
cd services/tailscale-relay
if [ ! -d node_modules/jsonwebtoken ]; then
  npm install
fi
node --test test/cloudflare-access-jwt.test.js
node test/access-relay-smoke.mjs
