#!/usr/bin/env bash
# Probe Cloudflare API capabilities available to the CI token (no secrets printed).
set -euo pipefail

ZONE_ID="${1:-}"
TOKEN="${2:-}"
ACCOUNT_ID="${PISTISAI_CF_ACCOUNT_ID:-35fa09929e656c4e96e4aa79909d11b7}"
TUNNEL_ID="${PISTISAI_CF_TUNNEL_ID:-b0aebd5d-5fdf-4dc1-b64c-932c4ee8b400}"

if [[ -z "$ZONE_ID" || -z "$TOKEN" ]]; then
  echo "usage: probe_cloudflare_token.sh ZONE_ID TOKEN" >&2
  exit 2
fi

python3 - "$ZONE_ID" "$TOKEN" "$ACCOUNT_ID" "$TUNNEL_ID" <<'PY'
import json, sys, urllib.error, urllib.request

zone_id, token, account_id, tunnel_id = sys.argv[1:5]
headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json",
    "User-Agent": "pistisai-probe-cloudflare-token",
}

def call(label, method, path):
    req = urllib.request.Request(
        f"https://api.cloudflare.com/client/v4{path}",
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = json.load(resp)
        print(f"{label}: ok success={body.get('success')}")
        return body
    except urllib.error.HTTPError as exc:
        err = exc.read().decode(errors="replace")[:240]
        print(f"{label}: http_{exc.code} {err}")
        return None

verify = call("token_verify", "GET", "/user/tokens/verify")
if verify and verify.get("result"):
    result = verify["result"]
    print(f"token_status={result.get('status')}")
    for perm in result.get("permissions") or []:
        print(f"permission={perm}")

dns = call("dns_records", "GET", f"/zones/{zone_id}/dns_records?per_page=100")
if dns and dns.get("result"):
    for record in dns["result"]:
        name = record.get("name")
        rtype = record.get("type")
        content = record.get("content")
        proxied = record.get("proxied")
        print(f"dns {name} {rtype} proxied={proxied} content={content}")

call("purge_cache_dry", "GET", f"/zones/{zone_id}")
call("rulesets_redirect", "GET", f"/zones/{zone_id}/rulesets/phases/http_request_dynamic_redirect/entrypoint")
call("pagerules", "GET", f"/zones/{zone_id}/pagerules")
connections = call(
    "tunnel_connections",
    "GET",
    f"/accounts/{account_id}/cfd_tunnel/{tunnel_id}/connections",
)
if connections and connections.get("result"):
    for connector in connections["result"]:
        for conn in connector.get("conns") or []:
            print(f"tunnel_origin_ip={conn.get('origin_ip')}")
PY
