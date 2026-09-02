#!/bin/bash

PID_FILE="/tmp/app_virtual_display.pid"

if [ -f "$PID_FILE" ]; then
    echo "Stopping virtual display and app..."
    while read pid; do
        [[ -n "$pid" ]] || continue
        kill -TERM $pid 2>/dev/null
        sleep 0.5
        kill -9 $pid 2>/dev/null || true
    done < "$PID_FILE"
    rm "$PID_FILE"
    echo "Done."
else
    echo "No PID file found. Cleaning up any remaining processes..."
    pkill -TERM -f pistisai 2>/dev/null || true
    pkill -TERM Xvfb 2>/dev/null || true
    pkill -TERM openbox 2>/dev/null || true
    pkill -TERM x11vnc 2>/dev/null || true
    pkill -TERM ffmpeg 2>/dev/null || true
    sleep 1
    pkill -9 -f pistisai 2>/dev/null || true
    pkill -9 Xvfb 2>/dev/null || true
    pkill -9 openbox 2>/dev/null || true
    pkill -9 x11vnc 2>/dev/null || true
    pkill -9 ffmpeg 2>/dev/null || true
fi
