#!/usr/bin/env bash
# Mock-HTTP coverage for scripts/ci/wait_for_served_version.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WAIT="$PROJECT_ROOT/scripts/ci/wait_for_served_version.sh"

if [[ ! -f "$WAIT" ]]; then
  echo "Missing $WAIT" >&2
  exit 1
fi

TMP="$(mktemp -d)"
SERVER_PID=""

cleanup() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

start_server() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -f "$TMP/port"
  printf '0' >"$TMP/index"
  RESPONSES="$TMP/responses.json" INDEX="$TMP/index" PORTFILE="$TMP/port" \
    python3 - <<'PY' &
import json, os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

responses = json.load(open(os.environ["RESPONSES"], encoding="utf-8"))
index_path = os.environ["INDEX"]

class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        with open(index_path, encoding="utf-8") as handle:
            index = int(handle.read() or "0")
        item = responses[min(index, len(responses) - 1)]
        with open(index_path, "w", encoding="utf-8") as handle:
            handle.write(str(index + 1))
        payload = item["body"].encode()
        self.send_response(int(item["status"]))
        self.send_header("Content-Type", item.get("type", "text/plain"))
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt, *args):
        return

server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(os.environ["PORTFILE"], "w", encoding="utf-8") as handle:
    handle.write(str(server.server_address[1]))
server.serve_forever()
PY
  SERVER_PID=$!
  for _ in $(seq 1 50); do
    if [[ -s "$TMP/port" ]]; then
      break
    fi
    sleep 0.05
  done
  [[ -s "$TMP/port" ]] || fail "mock server did not start"
  PORT="$(cat "$TMP/port")"
}

run_wait() {
  env -i PATH="$PATH" HOME="${HOME:-/tmp}" LANG="${LANG:-C}" "$@" bash "$WAIT"
}

echo "1. text poll succeeds when a later response contains the version marker"
python3 - "$TMP/responses.json" <<'PY'
import json, sys
json.dump([
    {"status": 200, "body": "<html>flutter_bootstrap.js?v=1.0.0.1</html>"},
    {"status": 200, "body": "<html>flutter_bootstrap.js?v=1.5.84.206</html>"},
], open(sys.argv[1], "w"))
PY
start_server
set +e
out="$(run_wait \
  SERVED_VERSION_URL="http://127.0.0.1:${PORT}/" \
  SERVED_VERSION='flutter_bootstrap.js?v=1.5.84.206' \
  SERVED_VERSION_MODE=text \
  SERVED_VERSION_TIMEOUT_SECONDS=5 \
  SERVED_VERSION_INTERVAL_SECONDS=0 \
  2>&1)"
status=$?
set -e
[[ "$status" -eq 0 ]] || fail "text poll exit $status: $out"
[[ "$out" == *"new version"* ]] || fail "missing success notice: $out"

echo "2. JSON poll matches release_version exactly"
python3 - "$TMP/responses.json" <<'PY'
import json, sys
json.dump([
    {"status": 200, "type": "application/json", "body": "{\"release_version\":\"build-1.5.84-old\"}"},
    {"status": 200, "type": "application/json", "body": "{\"release_version\":\"build-1.5.84-abc1234\",\"version\":\"10.1.187\"}"},
], open(sys.argv[1], "w"))
PY
start_server
set +e
out="$(run_wait \
  SERVED_VERSION_URL="http://127.0.0.1:${PORT}/service-version" \
  SERVED_VERSION='build-1.5.84-abc1234' \
  SERVED_VERSION_MODE=json \
  SERVED_VERSION_JSON_FIELD=release_version \
  SERVED_VERSION_TIMEOUT_SECONDS=5 \
  SERVED_VERSION_INTERVAL_SECONDS=0 \
  2>&1)"
status=$?
set -e
[[ "$status" -eq 0 ]] || fail "json poll exit $status: $out"

echo "3. a non-2xx body that contains the marker is not a match"
python3 - "$TMP/responses.json" <<'PY'
import json, sys
json.dump([
    {"status": 302, "body": "flutter_bootstrap.js?v=1.5.84.206"},
], open(sys.argv[1], "w"))
PY
start_server
set +e
out="$(run_wait \
  SERVED_VERSION_URL="http://127.0.0.1:${PORT}/" \
  SERVED_VERSION='flutter_bootstrap.js?v=1.5.84.206' \
  SERVED_VERSION_MODE=text \
  SERVED_VERSION_TIMEOUT_SECONDS=1 \
  SERVED_VERSION_INTERVAL_SECONDS=0 \
  2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]] || fail "redirect must not count as served: $out"
[[ "$out" == *"Timed out"* ]] || fail "missing timeout: $out"

echo "4. an empty expected version fails immediately"
set +e
out="$(run_wait \
  SERVED_VERSION_URL="http://127.0.0.1:${PORT}/" \
  SERVED_VERSION='' \
  SERVED_VERSION_MODE=text \
  2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]] || fail "empty version should fail: $out"
[[ "$out" == *"SERVED_VERSION"* ]] || fail "missing empty-version error: $out"

echo "5. a wrong JSON version times out"
python3 - "$TMP/responses.json" <<'PY'
import json, sys
json.dump([
    {"status": 200, "type": "application/json", "body": "{\"release_version\":\"old\"}"},
], open(sys.argv[1], "w"))
PY
start_server
set +e
out="$(run_wait \
  SERVED_VERSION_URL="http://127.0.0.1:${PORT}/service-version" \
  SERVED_VERSION='build-9.9.9-new' \
  SERVED_VERSION_MODE=json \
  SERVED_VERSION_TIMEOUT_SECONDS=1 \
  SERVED_VERSION_INTERVAL_SECONDS=0 \
  2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]] || fail "wrong version should time out: $out"
[[ "$out" == *"Timed out"* ]] || fail "missing timeout: $out"

echo "[test_wait_for_served_version] Passed"
