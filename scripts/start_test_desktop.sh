#!/usr/bin/env bash
set -e

DISPLAY_NUM=":99"
RESOLUTION="1920x1080x24"

echo "[TestDesktop] Starting Xvfb on display $DISPLAY_NUM with resolution $RESOLUTION..."
Xvfb $DISPLAY_NUM -screen 0 $RESOLUTION &
XVFB_PID=$!
sleep 1

export DISPLAY=$DISPLAY_NUM

echo "[TestDesktop] Starting Openbox window manager..."
openbox &
OPENBOX_PID=$!
sleep 1

echo "[TestDesktop] Test desktop is ready on display $DISPLAY_NUM!"
echo "PID: Xvfb=$XVFB_PID, Openbox=$OPENBOX_PID"

# Keep running or wait if executed as daemon
if [[ "${1:-}" == "--wait" ]]; then
    wait $XVFB_PID
fi
