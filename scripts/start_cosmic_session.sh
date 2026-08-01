#!/usr/bin/env bash
set -e

echo "[COSMIC] Starting COSMIC compositor (cosmic-comp)..."
cosmic-comp --no-xwayland &
COMP_PID=$!
echo "[COSMIC] COSMIC compositor started with PID $COMP_PID"
