#!/usr/bin/env bash
set -e

# Parse arguments
WITH_APP=false
WAIT_MODE=false
DISPLAY_NUM=":99"
RESOLUTION="1920x1080x24"
APP_PATH="/app/bundle/pistisai"
LOG_FILE="/tmp/app_virtual_display.log"
PID_FILE="/tmp/app_virtual_display.pid"
XVFB_LOG="/tmp/xvfb.log"
VNC_PORT=5900
RECORD_VIDEO=false
VIDEO_FILE="/tmp/test_recording.mp4"

while [[ $# -gt 0 ]]; do
    case $1 in
        --with-app)
            WITH_APP=true
            shift
            ;;
        --wait)
            WAIT_MODE=true
            shift
            ;;
        --display)
            DISPLAY_NUM="$2"
            shift 2
            ;;
        --resolution)
            RESOLUTION="$2"
            shift 2
            ;;
        --app-path)
            APP_PATH="$2"
            shift 2
            ;;
        --record-video)
            RECORD_VIDEO=true
            shift
            ;;
        --video-file)
            VIDEO_FILE="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --with-app        Launch the Flutter app after starting Xvfb/Openbox"
            echo "  --wait            Wait for processes (daemon mode)"
            echo "  --display NUM     X display number (default: :99)"
            echo "  --resolution RES  Screen resolution (default: 1920x1080x24)"
            echo "  --app-path PATH   Path to Flutter app binary"
            echo "  --record-video    Record screen to MP4 via ffmpeg"
            echo "  --video-file FILE Output video file path"
            echo "  --help            Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "[TestDesktop] Starting Xvfb on display $DISPLAY_NUM with resolution $RESOLUTION..."
Xvfb $DISPLAY_NUM -screen 0 $RESOLUTION > "$XVFB_LOG" 2>&1 &
XVFB_PID=$!
sleep 1

# Verify Xvfb started
if ! kill -0 $XVFB_PID 2>/dev/null; then
    echo "[TestDesktop] ERROR: Xvfb failed to start"
    cat "$XVFB_LOG"
    exit 1
fi

export DISPLAY=$DISPLAY_NUM

echo "[TestDesktop] Starting Openbox window manager..."
openbox &
OPENBOX_PID=$!
sleep 1

# Start x11vnc for remote debugging
echo "[TestDesktop] Starting x11vnc on port $VNC_PORT..."
x11vnc -display $DISPLAY_NUM -nopw -listen localhost -xkb -forever -shared > "/tmp/x11vnc.log" 2>&1 &
VNC_PID=$!
sleep 1

# Start screen recording if requested
if [[ "$RECORD_VIDEO" == "true" ]]; then
    echo "[TestDesktop] Starting screen recording to $VIDEO_FILE..."
    ffmpeg -y -f x11grab -video_size ${RESOLUTION%x*} -framerate 15 -i $DISPLAY_NUM -c:v libx264 -preset ultrafast -pix_fmt yuv420p "$VIDEO_FILE" > "/tmp/ffmpeg.log" 2>&1 &
    FFMPEG_PID=$!
    sleep 1
fi

# Launch the Flutter app if requested
if [[ "$WITH_APP" == "true" ]]; then
    if [[ ! -f "$APP_PATH" ]]; then
        echo "[TestDesktop] ERROR: App binary not found at $APP_PATH"
        exit 1
    fi
    
    echo "[TestDesktop] Launching Flutter app from $APP_PATH..."
    $APP_PATH > "$LOG_FILE" 2>&1 &
    APP_PID=$!
    sleep 3
    
    # Wait for app health endpoint
    echo "[TestDesktop] Waiting for app health endpoint..."
    for i in {1..30}; do
        if curl -sf "http://127.0.0.1:1337/health" >/dev/null 2>&1; then
            echo "[TestDesktop] App health check passed!"
            break
        fi
        if ! kill -0 $APP_PID 2>/dev/null; then
            echo "[TestDesktop] ERROR: App process died"
            cat "$LOG_FILE"
            exit 1
        fi
        sleep 1
    done
    
    if ! curl -sf "http://127.0.0.1:1337/health" >/dev/null 2>&1; then
        echo "[TestDesktop] ERROR: App health check timed out"
        cat "$LOG_FILE"
        exit 1
    fi
    
    # Save app PID
    echo $APP_PID >> "$PID_FILE"
fi

# Save PIDs
echo $XVFB_PID > "$PID_FILE"
echo $OPENBOX_PID >> "$PID_FILE"
echo $VNC_PID >> "$PID_FILE"
[[ "$RECORD_VIDEO" == "true" ]] && echo $FFMPEG_PID >> "$PID_FILE"

echo "[TestDesktop] Test desktop is ready on display $DISPLAY_NUM!"
echo "PIDs saved to $PID_FILE"
echo "  Xvfb: $XVFB_PID"
echo "  Openbox: $OPENBOX_PID"
echo "  x11vnc: $VNC_PID (port $VNC_PORT)"
[[ "$RECORD_VIDEO" == "true" ]] && echo "  ffmpeg: $FFMPEG_PID (recording to $VIDEO_FILE)"
[[ "$WITH_APP" == "true" ]] && echo "  App: $APP_PID (health: http://127.0.0.1:1337/health)"

# Keep running or wait if executed as daemon
if [[ "$WAIT_MODE" == "true" ]]; then
    wait $XVFB_PID
fi
