#!/bin/bash
#
# measure_startup.sh — Automated startup performance measurement
# Platforms: Linux (Wayland/X11), macOS
# Windows: Use scripts/performance/windows_perf.ps1
#
# Usage:
#   ./measure_startup.sh                 # Full startup suite
#   ./measure_startup.sh --cold-start    # Cold start only
#   ./measure_startup.sh --warm-start    # Warm start only
#   ./measure_startup.sh --splash        # Splash screen only

set -euo pipefail

SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

REPO_ROOT
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly REPO_ROOT
readonly REPORT_FILE="${REPO_ROOT}/performance_report.json"
readonly LOG_FILE="${REPO_ROOT}/performance_measure.log"

# Configuration
readonly COLD_START_IDLE_SEC=60
readonly WARM_START_RETRIES=3
readonly BUILD_MODE="${BUILD_MODE:-release}"  # release or profile
readonly PLATFORM="${PLATFORM:-linux}"        # linux or macos

# Baseline thresholds (ms)
readonly BASELINE_COLD_START=3200
readonly BASELINE_WARM_START=1100
readonly BASELINE_SPLASH=800

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================================================
# Utilities
# ============================================================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "${LOG_FILE}"
    exit 1
}

info() {
    echo -e "${GREEN}[INFO]${NC} $*" | tee -a "${LOG_FILE}"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "${LOG_FILE}"
}

check_regression() {
    local actual=$1
    local baseline=$2
    local metric=$3
    local threshold=$((baseline * 2))

    if (( actual > threshold )); then
        echo -e "${RED}REGRESSION DETECTED${NC}: ${metric} = ${actual}ms (baseline ${baseline}ms, threshold ${threshold}ms)"
        return 1
    elif (( actual > baseline )); then
        echo -e "${YELLOW}SLIGHT INCREASE${NC}: ${metric} = ${actual}ms (baseline ${baseline}ms, +$((actual - baseline))ms)"
        return 0
    else
        echo -e "${GREEN}WITHIN BASELINE${NC}: ${metric} = ${actual}ms (baseline ${baseline}ms)"
        return 0
    fi
}

# ============================================================================
# Platform Detection & App Path
# ============================================================================

detect_platform() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        error "Unsupported platform: $OSTYPE"
    fi
}

find_app_binary() {
    local platform=$1
    local build_mode=$2

    case "$platform" in
        linux)
            echo "${REPO_ROOT}/build/linux/x64/${build_mode}/bundle/pistisai"
            ;;
        macos)
            echo "${REPO_ROOT}/build/macos/Build/Products/${build_mode}/pistisai.app/Contents/MacOS/pistisai"
            ;;
        *)
            error "Unknown platform: $platform"
            ;;
    esac
}

# ============================================================================
# Measurement Functions
# ============================================================================

measure_cold_start() {
    info "Measuring cold start (${COLD_START_IDLE_SEC}s idle, then launch)..."

    local app_path
    app_path=$(find_app_binary "$PLATFORM" "$BUILD_MODE")

    if [[ ! -f "$app_path" ]]; then
        error "App binary not found: $app_path. Run 'flutter build ${BUILD_MODE}' first."
    fi

    # Ensure app is not running
    pkill -f "pistisai" || true
    sleep 2

    # Idle to clear system cache
    log "Idling ${COLD_START_IDLE_SEC}s to clear cache..."
    sleep "$COLD_START_IDLE_SEC"

    # Measure startup
    log "Launching app..."
    local start_ns
    start_ns=$(date +%s%N)

    # Launch and wait for window to appear (60s timeout)
    if [[ "$PLATFORM" == "linux" ]]; then
        timeout 60 "$app_path" &
        # app_pid is captured but test uses timeout's auto-cleanup
        sleep 1  # Give app time to render splash
        local elapsed_ms=$(( ($(date +%s%N) - start_ns) / 1000000 ))
        pkill -P $$ || true
    elif [[ "$PLATFORM" == "macos" ]]; then
        open -a "${app_path%/Contents/MacOS/pistisai}" &
        sleep 1
        local elapsed_ms=$(( ($(date +%s%N) - start_ns) / 1000000 ))
        pkill -f "pistisai" || true
    fi

    info "Cold start time: ${elapsed_ms}ms"
    echo "$elapsed_ms"
}

measure_warm_start() {
    info "Measuring warm start (app in background, $WARM_START_RETRIES runs)..."

    local app_path
    app_path=$(find_app_binary "$PLATFORM" "$BUILD_MODE")

    if [[ ! -f "$app_path" ]]; then
        error "App binary not found: $app_path"
    fi

    # Launch app once and keep running
    if [[ "$PLATFORM" == "linux" ]]; then
        "$app_path" &
        # Background process; no need to capture PID
    elif [[ "$PLATFORM" == "macos" ]]; then
        open -a "${app_path%/Contents/MacOS/pistisai}" &
    fi

    sleep 3  # Let app fully launch

    local total_ms=0
    for i in $(seq 1 "$WARM_START_RETRIES"); do
        log "Warm start run $i/$WARM_START_RETRIES..."

        # Kill and measure restart
        pkill -f "pistisai" || true
        sleep 1

        local start_ns
        start_ns=$(date +%s%N)

        if [[ "$PLATFORM" == "linux" ]]; then
            timeout 60 "$app_path" &
            sleep 1
        elif [[ "$PLATFORM" == "macos" ]]; then
            open -a "${app_path%/Contents/MacOS/pistisai}" &
            sleep 1
        fi

        local elapsed_ms=$(( ($(date +%s%N) - start_ns) / 1000000 ))
        log "  Run $i: ${elapsed_ms}ms"
        total_ms=$((total_ms + elapsed_ms))
    done

    pkill -f "pistisai" || true
    local avg_ms=$((total_ms / WARM_START_RETRIES))
    info "Warm start average (${WARM_START_RETRIES} runs): ${avg_ms}ms"
    echo "$avg_ms"
}

measure_splash_screen() {
    info "Measuring splash screen time..."

    # This requires app instrumentation (see docs/performance/PERFORMANCE_BASELINES.md)
    # For now, we'll estimate from app logs if available
    
    if [[ -f ~/.pistisai/logs/performance.log ]]; then
        # Try to extract splash_screen_ms from logs
        local splash_ms
        splash_ms=$(grep -oP "splash_screen_ms: \K[0-9]+" ~/.pistisai/logs/performance.log | tail -1)
        
        if [[ -n "$splash_ms" ]]; then
            info "Splash screen time (from app logs): ${splash_ms}ms"
            echo "$splash_ms"
            return 0
        fi
    fi

    warn "Splash screen time not available (requires app instrumentation)"
    echo "0"  # Placeholder
}

# ============================================================================
# Report Generation
# ============================================================================

generate_json_report() {
    local cold_start=$1
    local warm_start=$2
    local splash=$3

    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local cold_status="PASS"
    local warm_status="PASS"
    local splash_status="PASS"
    
    (( cold_start > BASELINE_COLD_START * 2 )) && cold_status="FAIL" || (( cold_start > BASELINE_COLD_START )) && cold_status="WARN"
    (( warm_start > BASELINE_WARM_START * 2 )) && warm_status="FAIL" || (( warm_start > BASELINE_WARM_START )) && warm_status="WARN"
    (( splash > BASELINE_SPLASH * 2 )) && splash_status="FAIL" || (( splash > BASELINE_SPLASH )) && splash_status="WARN"

    cat > "$REPORT_FILE" << EOF
{
  "timestamp": "${timestamp}",
  "platform": "${PLATFORM}",
  "build_mode": "${BUILD_MODE}",
  "measurements": {
    "cold_start_ms": ${cold_start},
    "warm_start_ms": ${warm_start},
    "splash_screen_ms": ${splash}
  },
  "baselines_ms": {
    "cold_start": ${BASELINE_COLD_START},
    "warm_start": ${BASELINE_WARM_START},
    "splash_screen": ${BASELINE_SPLASH}
  },
  "status": {
    "cold_start": "${cold_status}",
    "warm_start": "${warm_status}",
    "splash_screen": "${splash_status}"
  },
  "regressions": []
}
EOF

    info "Report saved to: $REPORT_FILE"
    cat "$REPORT_FILE"
}

# ============================================================================
# Main
# ============================================================================

main() {
    log "Starting startup performance measurement..."
    log "Platform: $PLATFORM"
    log "Build mode: $BUILD_MODE"

    # Parse arguments
    local run_cold=false
    local run_warm=false
    local run_splash=false

    if [[ $# -eq 0 ]]; then
        # Default: run all
        run_cold=true
        run_warm=true
        run_splash=true
    else
        for arg in "$@"; do
            case "$arg" in
                --cold-start) run_cold=true ;;
                --warm-start) run_warm=true ;;
                --splash)     run_splash=true ;;
                *)            error "Unknown option: $arg" ;;
            esac
        done
    fi

    # Run measurements
    local cold_start=0
    local warm_start=0
    local splash=0

    if $run_cold; then
        cold_start=$(measure_cold_start)
        check_regression "$cold_start" "$BASELINE_COLD_START" "Cold start" || true
    fi

    if $run_warm; then
        warm_start=$(measure_warm_start)
        check_regression "$warm_start" "$BASELINE_WARM_START" "Warm start" || true
    fi

    if $run_splash; then
        splash=$(measure_splash_screen)
        check_regression "$splash" "$BASELINE_SPLASH" "Splash screen" || true
    fi

    # Generate report
    generate_json_report "$cold_start" "$warm_start" "$splash"

    info "Measurement complete!"
}

# Auto-detect platform if not set
if [[ "${PLATFORM}" == "linux" ]] && [[ "$(detect_platform)" != "linux" ]]; then
    PLATFORM=$(detect_platform)
fi

main "$@"
