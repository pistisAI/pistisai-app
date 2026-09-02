#!/usr/bin/env bash
# Deploy the hosted test Hermes agent to the production Pistisai VPS.
# Target: cloudllm@pistisai.app:/opt/Pistisai
# This is NOT Simon's VPS (31.97.140.7).
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

VPS_HOST="${VPS_HOST:-${PISTISAI_VPS_HOST:-pistisai.app}}"
VPS_USER="${VPS_USER:-${PISTISAI_VPS_USER:-cloudllm}}"
VPS_SSH_KEY_FILE="${VPS_SSH_KEY_FILE:-}"
REMOTE_DIR="${REMOTE_DIR:-${PISTISAI_REMOTE_DIR:-/opt/Pistisai}}"
HERMES_API_SERVER_KEY="${HERMES_API_SERVER_KEY:-}"
PISTISAI_VPS_SSH_HOST="${PISTISAI_VPS_SSH_HOST:-}"

is_simon_host() {
  case "${1:-}" in
    31.97.140.7) return 0 ;;
    *) return 1 ;;
  esac
}

if is_simon_host "$VPS_HOST"; then
  echo "[deploy-hermes] ignoring Simon VPS host $VPS_HOST; using pistisai.app" >&2
  VPS_HOST="pistisai.app"
  VPS_USER="cloudllm"
  REMOTE_DIR="/opt/Pistisai"
fi

if [[ "$VPS_USER" == "pistisai" ]]; then
  echo "[deploy-hermes] ignoring Simon SSH user pistisai; using cloudllm" >&2
  VPS_USER="cloudllm"
fi

case "$REMOTE_DIR" in
  /opt/pistisai|/opt/pistisai/deploy)
    echo "[deploy-hermes] ignoring Simon remote dir $REMOTE_DIR; using /opt/Pistisai" >&2
    REMOTE_DIR="/opt/Pistisai"
    ;;
esac

SSH_HOST="${PISTISAI_VPS_SSH_HOST:-$VPS_HOST}"
if is_simon_host "$SSH_HOST"; then
  echo "[deploy-hermes] ignoring Simon origin SSH host $SSH_HOST; using pistisai.app" >&2
  SSH_HOST="pistisai.app"
fi

if [[ -z "$VPS_SSH_KEY_FILE" ]]; then
  echo "VPS_SSH_KEY_FILE is required" >&2
  exit 1
fi
if [[ ! -f "$VPS_SSH_KEY_FILE" ]]; then
  echo "VPS_SSH_KEY_FILE does not exist: $VPS_SSH_KEY_FILE" >&2
  exit 1
fi
if [[ ! -f "$REPO_ROOT/deploy/hermes/docker-compose.hermes.yml" ]]; then
  echo "missing $REPO_ROOT/deploy/hermes/docker-compose.hermes.yml" >&2
  exit 1
fi

ssh_opts=(
  -i "$VPS_SSH_KEY_FILE"
  -4
  -o BatchMode=yes
  -o ConnectTimeout=15
  -o StrictHostKeyChecking=accept-new
  -o ServerAliveInterval=30
  -o ServerAliveCountMax=6
)

ssh_target="${VPS_USER}@${SSH_HOST}"

case "$SSH_HOST" in
  pistisai.app|www.pistisai.app|app.pistisai.app|api.pistisai.app|hermes.pistisai.app)
    echo "[deploy-hermes] $SSH_HOST is Cloudflare-proxied; GitHub/CI cannot SSH to :22" >&2
    echo "[deploy-hermes] set PISTISAI_VPS_SSH_HOST to the origin VPS IP (not 31.97.140.7)" >&2
    exit 1
    ;;
esac

echo "[deploy-hermes] target ${ssh_target}:${REMOTE_DIR}"

ssh "${ssh_opts[@]}" "$ssh_target" \
  "mkdir -p $(printf %q "$REMOTE_DIR")/deploy/hermes $(printf %q "$REMOTE_DIR")/config/nginx $(printf %q "$REMOTE_DIR")/config/docker"

rsync -az \
  -e "ssh ${ssh_opts[*]}" \
  --exclude '.gitignore' \
  "$REPO_ROOT/deploy/hermes/" \
  "${ssh_target}:${REMOTE_DIR}/deploy/hermes/"

rsync -az \
  -e "ssh ${ssh_opts[*]}" \
  "$REPO_ROOT/config/nginx/nginx-webapp-internal.conf" \
  "${ssh_target}:${REMOTE_DIR}/config/nginx/nginx-webapp-internal.conf"

rsync -az \
  -e "ssh ${ssh_opts[*]}" \
  "$REPO_ROOT/config/docker/nginx-proxy.conf" \
  "${ssh_target}:${REMOTE_DIR}/config/docker/nginx-proxy.conf"

rsync -az \
  -e "ssh ${ssh_opts[*]}" \
  "$REPO_ROOT/config/docker/nginx-web.conf" \
  "${ssh_target}:${REMOTE_DIR}/config/docker/nginx-web.conf"

rsync -az \
  -e "ssh ${ssh_opts[*]}" \
  "$REPO_ROOT/config/nginx/nginx-flutter.conf" \
  "${ssh_target}:${REMOTE_DIR}/config/nginx/nginx-flutter.conf"

ssh "${ssh_opts[@]}" "$ssh_target" \
  "export REMOTE_DIR=$(printf %q "$REMOTE_DIR"); export HERMES_API_SERVER_KEY=$(printf %q "$HERMES_API_SERVER_KEY"); bash -seuo pipefail" <<'REMOTE'
cd "$REMOTE_DIR"

if docker info >/dev/null 2>&1; then
  docker_bin=(docker)
elif sudo -n docker info >/dev/null 2>&1; then
  docker_bin=(sudo docker)
else
  echo "[deploy-hermes] docker is not available for this user" >&2
  exit 1
fi

compose() {
  if "${docker_bin[@]}" compose version >/dev/null 2>&1; then
    "${docker_bin[@]}" compose "$@"
  else
    sudo -n docker-compose "$@"
  fi
}

ENV_FILE=".env"
if [[ ! -f "$ENV_FILE" ]]; then
  ENV_FILE="deploy/.env"
fi
if [[ ! -f "$ENV_FILE" ]]; then
  touch .env
  ENV_FILE=".env"
fi

if [[ -n "${HERMES_API_SERVER_KEY:-}" ]]; then
  if grep -q '^HERMES_API_SERVER_KEY=' "$ENV_FILE"; then
    # Use '|' delimiter and escape sed metacharacters in the key value.
    local_escaped="$(printf '%s' "$HERMES_API_SERVER_KEY" | sed -e 's/[|&\\]/\\&/g')"
    sed -i "s|^HERMES_API_SERVER_KEY=.*|HERMES_API_SERVER_KEY=${local_escaped}|" "$ENV_FILE"
  else
    printf '\nHERMES_API_SERVER_KEY=%s\n' "$HERMES_API_SERVER_KEY" >> "$ENV_FILE"
  fi
elif ! grep -q '^HERMES_API_SERVER_KEY=.\+' "$ENV_FILE"; then
  GEN="$(openssl rand -hex 32)"
  printf '\nHERMES_API_SERVER_KEY=%s\n' "$GEN" >> "$ENV_FILE"
  echo "[deploy-hermes] generated HERMES_API_SERVER_KEY on the VPS (not printed)"
fi

# Exact container names we may attach / reload. Avoid substring greps.
PROXY_CONTAINER_ALLOWLIST=(
  pistisai-nginx-proxy
  pistisai-web
  pistisai-flutter-app
  pistisai-flutter
)

detect_proxy_network() {
  local name net
  for name in "${PROXY_CONTAINER_ALLOWLIST[@]}"; do
    if "${docker_bin[@]}" ps --format '{{.Names}}' | grep -Fxq "$name"; then
      net="$("${docker_bin[@]}" inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{println $k}}{{end}}' "$name" | awk 'NF { print; exit }')"
      if [[ -n "$net" ]]; then
        printf '%s\n' "$net"
        return 0
      fi
    fi
  done
  return 1
}

HERMES_DOCKER_NETWORK="${HERMES_DOCKER_NETWORK:-}"
if [[ -z "$HERMES_DOCKER_NETWORK" ]]; then
  HERMES_DOCKER_NETWORK="$(detect_proxy_network || true)"
fi
if [[ -z "$HERMES_DOCKER_NETWORK" ]]; then
  HERMES_DOCKER_NETWORK="pistisai-network"
fi
if ! "${docker_bin[@]}" network inspect "$HERMES_DOCKER_NETWORK" >/dev/null 2>&1; then
  echo "[deploy-hermes] creating docker network $HERMES_DOCKER_NETWORK"
  "${docker_bin[@]}" network create "$HERMES_DOCKER_NETWORK"
fi
export HERMES_DOCKER_NETWORK
echo "[deploy-hermes] using docker network $HERMES_DOCKER_NETWORK"

compose --env-file "$ENV_FILE" -f deploy/hermes/docker-compose.hermes.yml pull
compose --env-file "$ENV_FILE" -f deploy/hermes/docker-compose.hermes.yml up -d

for attempt in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:8642/health >/dev/null 2>&1; then
    break
  fi
  if [[ "$attempt" -eq 30 ]]; then
    "${docker_bin[@]}" logs --tail 80 pistisai-hermes || true
    echo "[deploy-hermes] container health check failed" >&2
    exit 1
  fi
  sleep 2
done

for proxy_name in "${PROXY_CONTAINER_ALLOWLIST[@]}"; do
  if ! "${docker_bin[@]}" ps --format '{{.Names}}' | grep -Fxq "$proxy_name"; then
    continue
  fi
  "${docker_bin[@]}" network connect "$HERMES_DOCKER_NETWORK" "$proxy_name" 2>/dev/null || true
  if [[ "$proxy_name" == "pistisai-nginx-proxy" ]]; then
    # Proxy container mounts nginx.conf, not conf.d/default.conf.
    if [[ -f config/docker/nginx-proxy.conf ]]; then
      "${docker_bin[@]}" cp config/docker/nginx-proxy.conf "$proxy_name":/etc/nginx/nginx.conf || true
    fi
  elif "${docker_bin[@]}" exec "$proxy_name" test -f /etc/nginx/conf.d/default.conf 2>/dev/null; then
    "${docker_bin[@]}" cp config/docker/nginx-web.conf "$proxy_name":/etc/nginx/conf.d/default.conf || true
  fi
  if "${docker_bin[@]}" exec "$proxy_name" nginx -t >/dev/null 2>&1; then
    "${docker_bin[@]}" exec "$proxy_name" nginx -s reload
    echo "[deploy-hermes] reloaded nginx in $proxy_name"
  else
    echo "[deploy-hermes] nginx reload skipped for $proxy_name"
  fi
done

if command -v nginx >/dev/null 2>&1; then
  if sudo -n nginx -t >/dev/null 2>&1; then
    sudo -n nginx -s reload
    echo "[deploy-hermes] reloaded host nginx"
  fi
fi

# Final health probe is informational — readiness was already looped above.
curl -fsS http://127.0.0.1:8642/health || echo "[deploy-hermes] final health probe failed (non-fatal)"
echo
REMOTE

echo "[deploy-hermes] local VPS health passed"
echo "[deploy-hermes] public checks:"
for url in \
  "https://api.pistisai.app/hermes/health" \
  "https://app.pistisai.app/hermes/health" \
  "https://pistisai.app/hermes/health"
do
  code="$(curl -sS -o /tmp/hermes-public.body -w '%{http_code}' --max-time 20 "$url" || true)"
  if grep -qi '<html' /tmp/hermes-public.body 2>/dev/null; then
    echo "  $url -> $code (SPA HTML, not Hermes)"
  else
    echo "  $url -> $code"
  fi
done
