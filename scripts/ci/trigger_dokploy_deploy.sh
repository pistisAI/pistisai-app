#!/usr/bin/env bash
# Ask Dokploy to deploy the image GitHub Actions just published.
#
# Either set DOKPLOY_WEBHOOK_URL, or set DOKPLOY_API_URL with DOKPLOY_API_KEY
# and DOKPLOY_APPLICATION_ID and/or DOKPLOY_COMPOSE_ID. A webhook is used when
# its URL is set, and the API is not called as well.
#
# The webhook body is a Docker registry push payload. Dokploy redeploys a
# Docker application only when that tag matches the tag on the application.
# Set DOKPLOY_IMAGE_NAME to the image without its tag (for example
# ghcr.io/pistisai/pistisai-app-web) so Dokploy can compare the name too.
# DOKPLOY_IMAGE_TAG defaults to latest.
#
# Optional DOKPLOY_API_KEY is sent as the x-api-key header on the webhook.
# The API always requires that header.
#
# When neither path is configured, the script warns and exits 0. Set
# DOKPLOY_REQUIRED=true to fail instead. DOKPLOY_TARGET_LABEL is only a log
# label. This script never prints the URL, the token, or the ids.
set -euo pipefail

label="${DOKPLOY_TARGET_LABEL:-deploy}"
tag="${DOKPLOY_IMAGE_TAG:-latest}"
webhook="${DOKPLOY_WEBHOOK_URL:-}"
api_url="${DOKPLOY_API_URL:-}"
api_key="${DOKPLOY_API_KEY:-}"
app_id="${DOKPLOY_APPLICATION_ID:-}"
compose_id="${DOKPLOY_COMPOSE_ID:-}"
image_name="${DOKPLOY_IMAGE_NAME:-}"
required="${DOKPLOY_REQUIRED:-}"

if [[ -z "$tag" ]]; then
  tag="latest"
fi

require_http_url() {
  case "$1" in
    http://*|https://*) ;;
    *)
      echo "Dokploy (${label}): endpoint must be an http or https URL." >&2
      exit 1
      ;;
  esac
}

# Prints the HTTP status. Never prints the URL, the token, or the response.
dokploy_post() {
  local url="$1"
  local payload="$2"
  local send_key="$3"
  local user_agent="${4:-}"
  local body_file err_file code
  local -a args

  require_http_url "$url"
  body_file="$(mktemp)"
  err_file="$(mktemp)"
  args=(
    --silent
    --show-error
    --max-time 30
    --output "$body_file"
    --write-out '%{http_code}'
    --request POST
    --header 'Content-Type: application/json'
    --header 'Accept: application/json'
    --data-binary "$payload"
  )
  if [[ -n "$user_agent" ]]; then
    args+=(--header "User-Agent: ${user_agent}")
  fi
  if [[ "$send_key" == "yes" ]]; then
    args+=(--header "x-api-key: ${api_key}")
  fi

  code="$(curl "${args[@]}" --url "$url" 2>"$err_file" || true)"
  rm -f "$body_file" "$err_file"

  if [[ ! "$code" =~ ^2[0-9][0-9]$ ]]; then
    if [[ -z "$code" || "$code" == "000" ]]; then
      echo "Dokploy (${label}): deploy trigger failed (no HTTP response)." >&2
    else
      echo "Dokploy (${label}): deploy trigger failed (HTTP ${code})." >&2
    fi
    return 1
  fi
}

skip_unconfigured() {
  local required_flag="${required,,}"
  if [[ "$required_flag" == "true" || "$required_flag" == "1" ]]; then
    echo "Dokploy (${label}): not configured and DOKPLOY_REQUIRED is set, so the job fails." >&2
    exit 1
  fi
  echo "Dokploy (${label}): not configured; skipping deploy trigger."
  exit 0
}

if [[ -n "$webhook" ]]; then
  require_http_url "$webhook"
  send_key="no"
  if [[ -n "$api_key" ]]; then
    send_key="yes"
  fi
  if [[ -n "$image_name" ]]; then
    payload="$(jq -nc \
      --arg tag "$tag" \
      --arg name "$image_name" \
      '{push_data:{tag:$tag,pushed_at:(now|floor),pusher:"ci"},repository:{repo_name:$name,status:"Active"}}')"
    user_agent="Go-http-client/1.1"
  else
    payload="$(jq -nc \
      --arg tag "$tag" \
      '{push_data:{tag:$tag,pushed_at:(now|floor),pusher:"ci"},repository:{status:"Active"}}')"
    user_agent=""
  fi
  dokploy_post "$webhook" "$payload" "$send_key" "$user_agent"
  echo "Dokploy (${label}): deploy trigger accepted."
  exit 0
fi

if [[ -z "$api_url" ]]; then
  skip_unconfigured
fi

require_http_url "$api_url"
if [[ -z "$api_key" ]]; then
  echo "Dokploy (${label}): DOKPLOY_API_URL is set but DOKPLOY_API_KEY is missing." >&2
  exit 1
fi
if [[ -z "$app_id" && -z "$compose_id" ]]; then
  echo "Dokploy (${label}): set DOKPLOY_APPLICATION_ID or DOKPLOY_COMPOSE_ID." >&2
  exit 1
fi

base="${api_url%/}"
if [[ "$base" == */api ]]; then
  prefix="$base"
else
  prefix="${base}/api"
fi

if [[ -n "$app_id" ]]; then
  payload="$(jq -nc --arg id "$app_id" '{applicationId:$id}')"
  dokploy_post "${prefix}/application.deploy" "$payload" "yes"
  echo "Dokploy (${label}): application deploy trigger accepted."
fi

if [[ -n "$compose_id" ]]; then
  payload="$(jq -nc --arg id "$compose_id" '{composeId:$id}')"
  dokploy_post "${prefix}/compose.deploy" "$payload" "yes"
  echo "Dokploy (${label}): compose deploy trigger accepted."
fi
