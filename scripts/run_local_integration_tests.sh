#!/usr/bin/env bash
set -e

# PistisAI Local Integration Test Runner
# Runs the full test desktop stack locally using Docker Compose
# Usage: ./scripts/run_local_integration_tests.sh [options]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Defaults
FLUTTER_BIN="${FLUTTER_BIN:-/run/media/rightguy/data/flutter_sdk/flutter-sdk/bin/flutter}"
BUILD_FIRST=true
RUN_TESTS=true
KEEP_RUNNING=false
CLEANUP_ON_EXIT=true
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.test.yml"

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --no-build          Skip flutter build linux --release (use existing build)
  --no-tests          Start test desktop only, don't run integration tests
  --keep-running      Keep test desktop running after tests (for manual debugging)
  --no-cleanup        Don't stop containers on exit (use with --keep-running)
  --compose-file FILE Docker compose file (default: docker-compose.test.yml)
  --flutter-bin PATH  Flutter binary path (default: /run/media/rightguy/data/flutter_sdk/flutter-sdk/bin/flutter)
  --help              Show this help

Examples:
  $0                          # Full build + test + cleanup
  $0 --no-build --keep-running # Use existing build, keep desktop for VNC debugging
  $0 --no-tests               # Just start test desktop with app running
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-build)
            BUILD_FIRST=false
            shift
            ;;
        --no-tests)
            RUN_TESTS=false
            shift
            ;;
        --keep-running)
            KEEP_RUNNING=true
            shift
            ;;
        --no-cleanup)
            CLEANUP_ON_EXIT=false
            shift
            ;;
        --compose-file)
            COMPOSE_FILE="$2"
            shift 2
            ;;
        --flutter-bin)
            FLUTTER_BIN="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Cleanup function
cleanup() {
    if [[ "$CLEANUP_ON_EXIT" == "true" ]]; then
        log_info "Cleaning up test environment..."
        docker compose -f "$COMPOSE_FILE" down -v --remove-orphans 2>/dev/null || true
        log_success "Cleanup complete"
    fi
}

trap cleanup EXIT INT TERM

cd "$PROJECT_ROOT"

# Step 1: Build Flutter Linux app
if [[ "$BUILD_FIRST" == "true" ]]; then
    log_info "Building Flutter Linux release..."
    "$FLUTTER_BIN" build linux --release
    log_success "Build complete"
else
    log_info "Skipping build (using existing)"
    if [[ ! -f "build/linux/x64/release/bundle/pistisai" ]]; then
        log_error "No existing build found. Run without --no-build first."
        exit 1
    fi
fi

# Step 2: Start test desktop stack
log_info "Starting test desktop stack..."
docker compose -f "$COMPOSE_FILE" up -d --build test-desktop

# Step 3: Wait for health
log_info "Waiting for app health check..."
for i in {1..60}; do
    if docker compose -f "$COMPOSE_FILE" exec -T test-desktop curl -sf "http://127.0.0.1:1337/health" >/dev/null 2>&1; then
        log_success "App is healthy!"
        break
    fi
    if [[ $i -eq 60 ]]; then
        log_error "Health check timeout"
        docker compose -f "$COMPOSE_FILE" logs test-desktop
        exit 1
    fi
    sleep 2
done

# Step 4: Run integration tests
if [[ "$RUN_TESTS" == "true" ]]; then
    log_info "Running integration tests..."
    
    # Run tests inside the test-desktop container (has DISPLAY=:99)
    docker compose -f "$COMPOSE_FILE" exec -T test-desktop \
        /run/media/rightguy/data/flutter_sdk/flutter-sdk/bin/dart test test/integration/app_running_integration_test.dart --reporter expanded
    
    TEST_EXIT_CODE=$?
    
    if [[ $TEST_EXIT_CODE -eq 0 ]]; then
        log_success "All integration tests passed!"
    else
        log_error "Integration tests failed (exit code: $TEST_EXIT_CODE)"
        # Capture screenshot on failure
        log_info "Capturing failure screenshot..."
        docker compose -f "$COMPOSE_FILE" exec -T test-desktop \
            bash -c "DISPLAY=:99 import -window root /recordings/failure_screenshot.png" 2>/dev/null || true
        exit $TEST_EXIT_CODE
    fi
fi

# Step 5: Keep running or exit
if [[ "$KEEP_RUNNING" == "true" ]]; then
    log_success "Test desktop is running. Access via VNC: localhost:5900"
    log_info "App health: http://localhost:1337/health (inside container)"
    log_info "Recordings: ./recordings/ (mapped to container /recordings)"
    log_info "Press Ctrl+C to stop..."
    
    # Keep script alive
    while true; do sleep 1; done
else
    log_success "Test run complete!"
fi