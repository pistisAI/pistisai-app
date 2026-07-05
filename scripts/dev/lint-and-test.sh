#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo '## Flutter analyze'
flutter analyze lib/

echo '## Flutter tests'
flutter test

echo '## Root lint/test'
npm run lint
npm test
