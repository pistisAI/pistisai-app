#!/usr/bin/env bash
# Android client + desktop hub rig (wrapper around the unified test rig).
RIG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run_integration_test_rig.sh"
ARGS=(--android-only)
while [[ $# -gt 0 ]]; do
  case $1 in
    --no-build)
      ARGS+=(--no-docker-build)
      shift
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done
exec "$RIG" "${ARGS[@]}"
