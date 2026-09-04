#!/usr/bin/env bash
# Discover the Pistisai VPS origin IP for CI SSH deploys.
# pistisai.app resolves to Cloudflare anycast; GitHub runners must SSH to the
# tunnel connector's origin_ip or a grey-cloud A record — never 31.97.140.7 (Simon).
set -euo pipefail

PISTISAI_CF_ACCOUNT_ID="${PISTISAI_CF_ACCOUNT_ID:-35fa09929e656c4e96e4aa79909d11b7}"
PISTISAI_CF_TUNNEL_IDS="${PISTISAI_CF_TUNNEL_IDS:-b0aebd5d-5fdf-4dc1-b64c-932c4ee8b400 62da6c19-947b-4bf6-acad-100a73de4e0d}"
PISTISAI_VPS_SSH_USERS="${PISTISAI_VPS_SSH_USERS:-cloudllm root}"
VPS_SSH_KEY_FILE="${VPS_SSH_KEY_FILE:-}"
CLOUDFLARE_ZONE_ID="${CLOUDFLARE_ZONE_ID:-}"
CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-${CLOUDFLARE_CACHE_PURGE_TOKEN:-}}"

log() {
  printf '[discover-vps-origin] %s\n' "$1" >&2
}

is_simon_ip() {
  case "${1:-}" in
    31.97.140.7) return 0 ;;
    *) return 1 ;;
  esac
}

is_cloudflare_anycast_ip() {
  case "${1:-}" in
    104.21.*|104.22.*|104.23.*|104.24.*|104.25.*|104.26.*|104.27.*|172.64.*|172.65.*|172.66.*|172.67.*|172.68.*|172.69.*|172.70.*|172.71.*|2606:4700:*)
      return 0
      ;;
    *) return 1 ;;
  esac
}

add_candidate() {
  local ip="$1"
  [[ -z "$ip" ]] && return 0
  is_simon_ip "$ip" && return 0
  is_cloudflare_anycast_ip "$ip" && return 0
  case "$ip" in
    127.*|10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*) return 0 ;;
  esac
  if [[ " ${CANDIDATES[*]-} " != *" $ip "* ]]; then
    CANDIDATES+=("$ip")
  fi
}

cf_api() {
  local method="$1"
  local path="$2"
  python3 - "$method" "$path" "$CLOUDFLARE_API_TOKEN" <<'PY'
import json, sys, urllib.error, urllib.request

method, path, token = sys.argv[1:4]
if not token:
    sys.exit(0)
req = urllib.request.Request(
    f"https://api.cloudflare.com/client/v4{path}",
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "User-Agent": "pistisai-discover-vps-origin",
    },
    method=method,
)
try:
    with urllib.request.urlopen(req, timeout=30) as resp:
        print(resp.read().decode())
except urllib.error.HTTPError as exc:
    body = exc.read().decode(errors="replace")
    print(json.dumps({"success": False, "http_status": exc.code, "body": body[:500]}))
PY
}

log_cf_api_status() {
  local label="$1"
  local response="$2"
  local status
  status="$(printf '%s' "$response" | python3 - <<'PY'
import json, sys
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    print("invalid-json")
    sys.exit(0)
if "http_status" in data:
    print(data["http_status"])
elif data.get("success") is True:
    print("ok")
else:
    print("error")
PY
)"
  log "${label}: ${status}"
}

collect_tunnel_origin_ips() {
  [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]] && return 0
  for tunnel_id in $PISTISAI_CF_TUNNEL_IDS; do
    response="$(cf_api GET "/accounts/${PISTISAI_CF_ACCOUNT_ID}/cfd_tunnel/${tunnel_id}/connections")"
    [[ -z "$response" ]] && continue
    log_cf_api_status "tunnel ${tunnel_id} connections" "$response"
    if ! printf '%s' "$response" | python3 -c 'import json,sys; json.load(sys.stdin)' >/dev/null 2>&1; then
      log "Cloudflare tunnel connections API returned non-JSON for tunnel ${tunnel_id}"
      continue
    fi
    while IFS= read -r ip; do
      [[ -n "$ip" ]] && add_candidate "$ip"
    done < <(
      printf '%s' "$response" | python3 - <<'PY'
import json, sys

data = json.load(sys.stdin)
if not data.get("success", False):
    sys.exit(0)
for connector in data.get("result") or []:
    for conn in connector.get("conns") or []:
        ip = conn.get("origin_ip")
        if ip:
            print(ip)
PY
    )
  done
}

collect_dns_a_records() {
  [[ -z "${CLOUDFLARE_API_TOKEN:-}" || -z "${CLOUDFLARE_ZONE_ID:-}" ]] && return 0
  page=1
  while :; do
    response="$(cf_api GET "/zones/${CLOUDFLARE_ZONE_ID}/dns_records?per_page=100&page=${page}")"
    [[ -z "$response" ]] && break
    if [[ "$page" -eq 1 ]]; then
      log_cf_api_status "dns records" "$response"
    fi
    mapfile -t dns_batch < <(
      printf '%s' "$response" | python3 - <<'PY'
import json, sys

data = json.load(sys.stdin)
if not data.get("success", False):
    sys.exit(0)
records = data.get("result") or []
for record in records:
    content = record.get("content")
    proxied = record.get("proxied", False)
    if content and not proxied:
        print(content)
print(f"__COUNT__:{len(records)}")
PY
    )
    record_count=0
    for line in "${dns_batch[@]}"; do
      if [[ "$line" == __COUNT__:* ]]; then
        record_count="${line#__COUNT__:}"
      else
        add_candidate "$line"
      fi
    done
    [[ "${record_count:-0}" -lt 100 ]] && break
    page=$((page + 1))
  done
}

probe_ssh() {
  local user="$1"
  local ip="$2"
  [[ -z "$VPS_SSH_KEY_FILE" || ! -f "$VPS_SSH_KEY_FILE" ]] && return 1
  ssh -4 \
    -i "$VPS_SSH_KEY_FILE" \
    -o BatchMode=yes \
    -o ConnectTimeout=10 \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "${user}@${ip}" \
    'test -d /opt/Pistisai || test -d /opt/pistisai' \
    >/dev/null 2>&1
}

CANDIDATES=()
collect_tunnel_origin_ips
collect_dns_a_records

# Legacy Proxmox hosts from archived deployment docs (exclude Simon).
add_candidate "208.110.72.50"
add_candidate "208.110.72.52"

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  log "No origin IP candidates discovered"
  exit 1
fi

log "Probing ${#CANDIDATES[@]} SSH candidate(s)..."
for ip in "${CANDIDATES[@]}"; do
  for user in $PISTISAI_VPS_SSH_USERS; do
    log "Trying ${user}@${ip}"
    if probe_ssh "$user" "$ip"; then
      log "Origin VPS reachable at ${ip} (${user})"
      printf '%s\n' "$ip"
      exit 0
    fi
  done
done

log "No candidate accepted SSH with /opt/Pistisai present"
exit 1
