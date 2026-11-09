#!/usr/bin/env bash
# PistisAI Linux integration tests (wrapper around the unified test rig).
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run_integration_test_rig.sh" --desktop-only "$@"
