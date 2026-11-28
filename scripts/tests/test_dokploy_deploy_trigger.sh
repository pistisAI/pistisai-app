#!/usr/bin/env bash
# Mock-HTTP coverage for scripts/ci/trigger_dokploy_deploy.sh.
# The script must never print a Dokploy URL or token.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TRIGGER="$PROJECT_ROOT/scripts/ci/trigger_dokploy_deploy.sh"

if [[ ! -f "$TRIGGER" ]]; then
  echo "Missing $TRIGGER" >&2
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
  local status="${1:-200}"
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  : >"$TMP/capture.jsonl"
  rm -f "$TMP/port"
  CAPTURE="$TMP/capture.jsonl" PORTFILE="$TMP/port" MOCK_STATUS="$status" \
    python3 - <<'PY' &
import json, os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

capture = os.environ["CAPTURE"]
status = int(os.environ.get("MOCK_STATUS", "200"))

class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)
        record = {
            "path": self.path.split("?", 1)[0],
            "api_key": self.headers.get("x-api-key"),
            "user_agent": self.headers.get("User-Agent"),
            "content_type": self.headers.get("Content-Type"),
            "body": raw.decode(),
        }
        with open(capture, "a", encoding="utf-8") as handle:
            handle.write(json.dumps(record) + "\n")
        payload = b'{"ok":true}'
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
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

requests() {
  python3 - "$TMP/capture.jsonl" <<'PY'
import json, sys
path = sys.argv[1]
rows = []
with open(path, encoding="utf-8") as handle:
    for line in handle:
        line = line.strip()
        if line:
            rows.append(json.loads(line))
print(len(rows))
for row in rows:
    print(json.dumps(row, sort_keys=True))
PY
}

run_trigger() {
  # env -i keeps a developer shell from forwarding real Dokploy credentials.
  env -i PATH="$PATH" HOME="${HOME:-/tmp}" LANG="${LANG:-C}" "$@" bash "$TRIGGER"
}

assert_clean() {
  local output="$1"
  local secret
  for secret in "$@"; do
    :
  done
  shift
  for secret in "$@"; do
    if [[ "$output" == *"$secret"* ]]; then
      fail "output leaked secret material: $secret"
    fi
  done
}

echo "1. nothing configured warns and exits 0"
set +e
out="$(run_trigger DOKPLOY_TARGET_LABEL=web 2>&1)"
status=$?
set -e
[[ "$status" -eq 0 ]] || fail "unconfigured exit $status: $out"
[[ "$out" == *"Dokploy (web)"* ]] || fail "missing label: $out"
[[ "$out" == *"not configured"* ]] || fail "missing warning: $out"

echo "2. DOKPLOY_REQUIRED=true fails when nothing is configured"
set +e
out="$(run_trigger DOKPLOY_TARGET_LABEL=backend DOKPLOY_REQUIRED=true 2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]] || fail "required mode should fail: $out"
[[ "$out" == *"Dokploy (backend)"* ]] || fail "missing label: $out"
[[ "$out" == *"DOKPLOY_REQUIRED"* ]] || fail "missing required notice: $out"

echo "3. DOKPLOY_REQUIRED=false still skips"
set +e
out="$(run_trigger DOKPLOY_TARGET_LABEL=web DOKPLOY_REQUIRED=false 2>&1)"
status=$?
set -e
[[ "$status" -eq 0 ]] || fail "false required should skip: $out"

echo "4. webhook posts a registry payload whose tag matches"
start_server 200
SECRET_PATH="hook/super-secret-path"
WEBHOOK_URL="http://127.0.0.1:${PORT}/${SECRET_PATH}"
: >"$TMP/capture.jsonl"
set +e
out="$(run_trigger \
  DOKPLOY_TARGET_LABEL=web \
  DOKPLOY_IMAGE_TAG=latest \
  DOKPLOY_IMAGE_NAME=ghcr.io/pistisai/pistisai-app-web \
  DOKPLOY_WEBHOOK_URL="$WEBHOOK_URL" \
  2>&1)"
status=$?
set -e
[[ "$status" -eq 0 ]] || fail "webhook exit $status: $out"
assert_clean "$out" "$SECRET_PATH" "super-secret"
mapfile -t rows < <(requests)
[[ "${rows[0]}" == "1" ]] || fail "expected 1 webhook request, got ${rows[0]}"
python3 - "${rows[1]}" <<'PY'
import json, sys
row = json.loads(sys.argv[1])
assert row["path"] == "/hook/super-secret-path", row
assert row["content_type"].startswith("application/json"), row
assert "Go-http-client" in (row["user_agent"] or ""), row
assert row["api_key"] in (None, ""), row
body = json.loads(row["body"])
assert body["push_data"]["tag"] == "latest", body
assert body["repository"]["repo_name"] == "ghcr.io/pistisai/pistisai-app-web", body
PY

echo "5. optional x-api-key is sent and never printed"
API_KEY="super-secret-key"
: >"$TMP/capture.jsonl"
set +e
out="$(run_trigger \
  DOKPLOY_TARGET_LABEL=web \
  DOKPLOY_IMAGE_TAG=latest \
  DOKPLOY_WEBHOOK_URL="$WEBHOOK_URL" \
  DOKPLOY_API_KEY="$API_KEY" \
  2>&1)"
status=$?
set -e
[[ "$status" -eq 0 ]] || fail "webhook with key exit $status: $out"
assert_clean "$out" "$SECRET_PATH" "$API_KEY"
python3 - "$(requests | tail -n 1)" "$API_KEY" <<'PY'
import json, sys
row = json.loads(sys.argv[1])
assert row["api_key"] == sys.argv[2], row
body = json.loads(row["body"])
assert body["push_data"]["tag"] == "latest", body
PY

echo "6. non-2xx fails without printing the webhook URL"
start_server 500
WEBHOOK_URL="http://127.0.0.1:${PORT}/${SECRET_PATH}"
set +e
out="$(run_trigger \
  DOKPLOY_TARGET_LABEL=web \
  DOKPLOY_IMAGE_TAG=latest \
  DOKPLOY_WEBHOOK_URL="$WEBHOOK_URL" \
  2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]] || fail "HTTP 500 should fail: $out"
[[ "$out" == *"HTTP 500"* ]] || fail "missing status: $out"
assert_clean "$out" "$SECRET_PATH" "$WEBHOOK_URL"

echo "7. API mode deploys an application"
start_server 200
API_URL="http://127.0.0.1:${PORT}"
APP_ID="app-id-secret"
: >"$TMP/capture.jsonl"
set +e
out="$(run_trigger \
  DOKPLOY_TARGET_LABEL=web \
  DOKPLOY_API_URL="$API_URL" \
  DOKPLOY_API_KEY="$API_KEY" \
  DOKPLOY_APPLICATION_ID="$APP_ID" \
  2>&1)"
status=$?
set -e
[[ "$status" -eq 0 ]] || fail "application deploy exit $status: $out"
assert_clean "$out" "$API_URL" "$API_KEY" "$APP_ID"
python3 - "$(requests | tail -n 1)" "$API_KEY" "$APP_ID" <<'PY'
import json, sys
row = json.loads(sys.argv[1])
assert row["path"] == "/api/application.deploy", row
assert row["api_key"] == sys.argv[2], row
body = json.loads(row["body"])
assert body == {"applicationId": sys.argv[3]}, body
PY

echo "8. API mode deploys compose, including a base URL that already ends in /api"
API_URL="http://127.0.0.1:${PORT}/api"
COMPOSE_ID="compose-id-secret"
: >"$TMP/capture.jsonl"
set +e
out="$(run_trigger \
  DOKPLOY_TARGET_LABEL=backend \
  DOKPLOY_API_URL="$API_URL" \
  DOKPLOY_API_KEY="$API_KEY" \
  DOKPLOY_COMPOSE_ID="$COMPOSE_ID" \
  2>&1)"
status=$?
set -e
[[ "$status" -eq 0 ]] || fail "compose deploy exit $status: $out"
assert_clean "$out" "$API_KEY" "$COMPOSE_ID" "$API_URL"
python3 - "$(requests | tail -n 1)" "$API_KEY" "$COMPOSE_ID" <<'PY'
import json, sys
row = json.loads(sys.argv[1])
assert row["path"] == "/api/compose.deploy", row
assert row["api_key"] == sys.argv[2], row
body = json.loads(row["body"])
assert body == {"composeId": sys.argv[3]}, body
PY

echo "9. API URL without a key or id fails closed"
set +e
out="$(run_trigger \
  DOKPLOY_TARGET_LABEL=backend \
  DOKPLOY_API_URL="http://127.0.0.1:${PORT}" \
  2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]] || fail "missing key should fail: $out"
[[ "$out" == *"DOKPLOY_API_KEY"* ]] || fail "should name the missing key: $out"

set +e
out="$(run_trigger \
  DOKPLOY_TARGET_LABEL=backend \
  DOKPLOY_API_URL="http://127.0.0.1:${PORT}" \
  DOKPLOY_API_KEY="$API_KEY" \
  2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]] || fail "missing id should fail: $out"
assert_clean "$out" "$API_KEY"
[[ "$out" == *"DOKPLOY_APPLICATION_ID"* ]] || fail "should name the missing id: $out"

echo "10. a webhook URL wins over a configured API, so deploy runs once"
start_server 200
WEBHOOK_URL="http://127.0.0.1:${PORT}/${SECRET_PATH}"
: >"$TMP/capture.jsonl"
set +e
out="$(run_trigger \
  DOKPLOY_TARGET_LABEL=web \
  DOKPLOY_IMAGE_TAG=latest \
  DOKPLOY_WEBHOOK_URL="$WEBHOOK_URL" \
  DOKPLOY_API_URL="http://127.0.0.1:${PORT}" \
  DOKPLOY_API_KEY="$API_KEY" \
  DOKPLOY_APPLICATION_ID="$APP_ID" \
  2>&1)"
status=$?
set -e
[[ "$status" -eq 0 ]] || fail "precedence exit $status: $out"
assert_clean "$out" "$SECRET_PATH" "$API_KEY" "$APP_ID"
count="$(requests | head -n 1)"
[[ "$count" == "1" ]] || fail "webhook precedence made $count requests"
python3 - "$(requests | tail -n 1)" <<'PY'
import json, sys
row = json.loads(sys.argv[1])
assert row["path"] == "/hook/super-secret-path", row
body = json.loads(row["body"])
assert "push_data" in body, body
PY

echo "11. a non-http endpoint fails without echoing it"
set +e
out="$(run_trigger \
  DOKPLOY_TARGET_LABEL=web \
  DOKPLOY_WEBHOOK_URL="ftp://secret.example/hook" \
  2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]] || fail "bad scheme should fail: $out"
assert_clean "$out" "ftp://secret.example/hook" "secret.example"

echo "12. application and compose ids both deploy when no webhook is set"
start_server 200
: >"$TMP/capture.jsonl"
set +e
out="$(run_trigger \
  DOKPLOY_TARGET_LABEL=backend \
  DOKPLOY_API_URL="http://127.0.0.1:${PORT}" \
  DOKPLOY_API_KEY="$API_KEY" \
  DOKPLOY_APPLICATION_ID="$APP_ID" \
  DOKPLOY_COMPOSE_ID="$COMPOSE_ID" \
  2>&1)"
status=$?
set -e
[[ "$status" -eq 0 ]] || fail "dual deploy exit $status: $out"
assert_clean "$out" "$API_KEY" "$APP_ID" "$COMPOSE_ID"
python3 - "$TMP/capture.jsonl" "$APP_ID" "$COMPOSE_ID" <<'PY'
import json, sys
rows = [json.loads(line) for line in open(sys.argv[1], encoding="utf-8") if line.strip()]
assert len(rows) == 2, rows
paths = [row["path"] for row in rows]
assert paths == ["/api/application.deploy", "/api/compose.deploy"], paths
assert json.loads(rows[0]["body"])["applicationId"] == sys.argv[2]
assert json.loads(rows[1]["body"])["composeId"] == sys.argv[3]
PY

if grep -nE 'echo .*\$(url|webhook|api_url|api_key|payload)\b' "$TRIGGER"; then
  fail "trigger script echoes a Dokploy URL or token"
fi

echo "13. deploy workflows purge only after Dokploy"
python3 - "$PROJECT_ROOT" <<'PY'
import re, sys
from pathlib import Path

root = Path(sys.argv[1])

def jobs(text):
    found = {}
    current = None
    buf = []
    for line in text.splitlines(True):
        if re.match(r"^  [A-Za-z0-9_]+:\s*$", line):
            if current is not None:
                found[current] = "".join(buf)
            current = line.strip()[:-1]
            buf = [line]
        elif current is not None:
            buf.append(line)
    if current is not None:
        found[current] = "".join(buf)
    return found

def needs(block, job):
    match = re.search(r"^\s*needs:\s*(.+)$", block, re.M)
    if not match:
        raise SystemExit(f"{job} has no needs")
    return match.group(1)

web = jobs((root / ".github/workflows/deploy-web.yml").read_text())
backend = jobs((root / ".github/workflows/deploy-backend.yml").read_text())
test = (root / ".github/workflows/test.yml").read_text()

for name in ("deploy_dokploy", "purge_cache"):
    if name not in web or name not in backend:
        raise SystemExit(f"missing {name}")

if "build_and_push" not in needs(web["deploy_dokploy"], "web deploy_dokploy"):
    raise SystemExit("web deploy_dokploy must need build_and_push")
if "deploy_dokploy" not in needs(web["purge_cache"], "web purge_cache"):
    raise SystemExit("web purge must need deploy_dokploy")
if "build_images" not in needs(backend["deploy_dokploy"], "backend deploy_dokploy"):
    raise SystemExit("backend deploy_dokploy must need build_images")
if "deploy_dokploy" not in needs(backend["purge_cache"], "backend purge_cache"):
    raise SystemExit("backend purge must need deploy_dokploy")
if "pushed == 'true'" not in backend["deploy_dokploy"]:
    raise SystemExit("backend deploy_dokploy must run only when images were pushed")

for label, text in ("web", web["purge_cache"]), ("backend", backend["purge_cache"]):
    if "wait_for_served_version.sh" not in text:
        raise SystemExit(f"{label} purge does not wait for the served version")
    if "CLOUDFLARE_CACHE_PURGE_TOKEN and CF_ZONE_ID must both be set" not in text:
        raise SystemExit(f"{label} purge no longer fails closed on missing credentials")

if "DOKPLOY_WEB_APPLICATION_ID" not in web["deploy_dokploy"]:
    raise SystemExit("web job missing application id secret")
if "DOKPLOY_IMAGE_TAG: latest" not in web["deploy_dokploy"]:
    raise SystemExit("web job must send the latest tag")
if "DOKPLOY_TARGET_LABEL: web" not in web["deploy_dokploy"]:
    raise SystemExit("web label missing")
if "DOKPLOY_BACKEND_WEBHOOK_URL" not in backend["deploy_dokploy"]:
    raise SystemExit("backend webhook secret missing")
if "DOKPLOY_BACKEND_COMPOSE_ID" not in backend["deploy_dokploy"]:
    raise SystemExit("backend compose id secret missing")
if "DOKPLOY_TARGET_LABEL: backend" not in backend["deploy_dokploy"]:
    raise SystemExit("backend label missing")
if "RELEASE_VERSION=" not in (root / ".github/workflows/deploy-backend.yml").read_text():
    raise SystemExit("backend image is not labeled with RELEASE_VERSION")
if "test_dokploy_deploy_trigger.sh" not in test:
    raise SystemExit("CI does not run the Dokploy trigger test")

for path in (
    root / ".github/workflows/deploy-web.yml",
    root / ".github/workflows/deploy-backend.yml",
):
    body = path.read_text()
    if "by hand" in body or "pulls the image" in body or "pulls the images" in body:
        raise SystemExit(f"{path.name} still describes a hand pull")
PY

echo "[test_dokploy_deploy_trigger] Passed"
