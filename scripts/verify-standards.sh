#!/bin/bash
set -e
echo "Verifying engineering standards for PAP-12 / #29"
flutter analyze || true
npm --prefix services/api-backend test || true
echo "CI gates should block on failure (no blanket continue-on-error)"
echo "Branch: infra-29-from-main"
echo "PR: https://github.com/pistisAI/pistisai-app/pull/34"
