#!/usr/bin/env bash
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run_pc_integration_test_rig.sh" "$@"
