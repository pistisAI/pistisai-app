#!/bin/bash
# Pi Watcher Install Script
# Sets up the Pi observer extension and systemd service.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCHER_DIR="/dev/pistisai/watcher"

echo "=== Pi Watcher Installer ==="

# Create watcher directory
mkdir -p "$WATCHER_DIR/systemd"
mkdir -p "$WATCHER_DIR/logs"

# Copy extension
echo "[1/4] Installing observer extension..."
cp "$SCRIPT_DIR/../observer-extension.ts" "$WATCHER_DIR/"

# Copy systemd unit
echo "[2/4] Installing systemd service..."
sudo cp "$SCRIPT_DIR/../systemd/pi-watcher.service" /etc/systemd/system/
sudo systemctl daemon-reload

# Create notification log file
echo "[3/4] Creating notification log..."
touch "$WATCHER_DIR/notifications.jsonl"

# Enable and start
echo "[4/4] Enabling and starting Pi Watcher..."
sudo systemctl enable --now pi-watcher

echo ""
echo "=== Pi Watcher installed ==="
echo "Status:"
sudo systemctl status pi-watcher --no-pager || true
echo ""
echo "Logs: journalctl -u pi-watcher -f"
echo "Notifications: tail -f $WATCHER_DIR/notifications.jsonl"
