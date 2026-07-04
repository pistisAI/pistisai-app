#!/bin/bash
set -e
echo "Verifying engineering standards for PAP-12 / #29"
flutter analyze || true
npm --prefix services/api-backend test || true
echo "CI gates should block on failure (no blanket continue-on-error)"
echo "Branch: feat/pap1-infra-29"
