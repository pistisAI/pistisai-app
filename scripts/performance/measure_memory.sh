#!/bin/bash
#
# measure_memory.sh — Monitor memory and CPU usage during active chat session
# Platforms: Linux, macOS
#
# Usage:
#   ./measure_memory.sh                    # Run for 60 seconds (default)
#   ./measure_memory.sh --duration 3600    # Run for 1 hour
#   ./measure_memory.sh --output report.csv

set -euo pipefail

SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

REPO_ROOT
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly REPO_ROOT

# Configuration
DURATION_SEC=60
OUTPUT_FILE="${REPO_ROOT}/memory_monitor.csv"
INTERVAL_SEC=2

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ============================================================================
# Utilities
# ============================================================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    exit 1
}

info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

# ============================================================================
# Platform Detection
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

# ============================================================================
# Measurement Functions
# ============================================================================

measure_linux() {
    local pid=$1
    local timestamp=$2

    # Get PID stats from /proc
    if [[ -f "/proc/${pid}/stat" && -f "/proc/${pid}/status" ]]; then
        local rss_kb
        rss_kb=$(grep "VmRSS:" "/proc/${pid}/status" | awk '{print $2}')
        
        local rss_mb=$((rss_kb / 1024))
        
        # Get CPU usage (requires /proc/stat comparison, simplified here)
        local cpu_pct
        cpu_pct=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ')
        
        echo "${timestamp},${rss_mb},${cpu_pct}"
    else
        echo "${timestamp},0,0"
    fi
}

measure_macos() {
    local pid=$1
    local timestamp=$2

    # Use ps for memory and CPU
    local line
    line=$(ps -p "$pid" -o rss=,"%cpu=" 2>/dev/null | tr -d ' ')
    
    if [[ -n "$line" ]]; then
        local rss_kb
        local cpu_pct
        read -r rss_kb cpu_pct <<< "$line"
        local rss_mb=$((rss_kb / 1024))
        echo "${timestamp},${rss_mb},${cpu_pct}"
    else
        echo "${timestamp},0,0"
    fi
}

# ============================================================================
# Main
# ============================================================================

main() {
    local platform
    platform=$(detect_platform)
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --duration)
                DURATION_SEC="$2"
                shift 2
                ;;
            --output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done

    info "Memory & CPU monitoring (Linux/macOS)"
    log "Platform: $platform"
    log "Duration: ${DURATION_SEC}s"
    log "Output: $OUTPUT_FILE"

    # Find pistisai process
    local pid
    pid=$(pgrep -f "pistisai" | head -1)
    
    if [[ -z "$pid" ]]; then
        error "PistisAI process not found. Start the app first."
    fi

    info "Monitoring PID $pid..."

    # Write CSV header
    echo "timestamp_unix,rss_mb,cpu_pct" > "$OUTPUT_FILE"

    # Monitoring loop
    local start_time
    start_time=$(date +%s)
    
    local max_rss=0
    local measurements=0

    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if (( elapsed >= DURATION_SEC )); then
            break
        fi

        # Get measurement
        local timestamp
        timestamp=$(date +%s)
        
        local measurement
        if [[ "$platform" == "linux" ]]; then
            measurement=$(measure_linux "$pid" "$timestamp")
        else
            measurement=$(measure_macos "$pid" "$timestamp")
        fi

        if [[ -n "$measurement" ]]; then
            echo "$measurement" >> "$OUTPUT_FILE"
            
            # Extract RSS for peak tracking
            local rss
            rss=$(echo "$measurement" | cut -d',' -f2)
            if (( rss > max_rss )); then
                max_rss=$rss
            fi
            
            measurements=$((measurements + 1))
            
            # Log current values
            local cpu
            cpu=$(echo "$measurement" | cut -d',' -f3)
            log "Elapsed: ${elapsed}s | RSS: ${rss}MB (peak: ${max_rss}MB) | CPU: ${cpu}%"
        fi

        sleep "$INTERVAL_SEC"
    done

    # Print summary
    info "Monitoring complete. Measurements collected: $measurements"
    info "Peak memory: ${max_rss}MB"
    info "Data saved to: $OUTPUT_FILE"

    # Basic analysis
    if (( max_rss > 500 )); then
        echo -e "${YELLOW}[WARN]${NC} Peak memory (${max_rss}MB) exceeds baseline 500MB threshold"
    else
        echo -e "${GREEN}[PASS]${NC} Peak memory (${max_rss}MB) within baseline 500MB threshold"
    fi
}

main "$@"
