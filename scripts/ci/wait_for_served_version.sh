#!/usr/bin/env bash
# Poll a public health or version URL until it serves this deploy.
#
# SERVED_VERSION is the exact text (text mode) or JSON field value (json mode)
# that proves the host is running the image just published. SERVED_VERSION_URL
# defaults to https://pistisai.app/ for text mode and
# https://api.pistisai.app/service-version for json mode. A non-2xx response,
# including a login redirect, does not count.
#
# SERVED_VERSION_TIMEOUT_SECONDS defaults to 600. SERVED_VERSION_INTERVAL_SECONDS
# defaults to 10. The URL is not printed.
set -euo pipefail

expected="${SERVED_VERSION:-}"
mode="${SERVED_VERSION_MODE:-text}"
field="${SERVED_VERSION_JSON_FIELD:-release_version}"
timeout="${SERVED_VERSION_TIMEOUT_SECONDS:-600}"
interval="${SERVED_VERSION_INTERVAL_SECONDS:-10}"
url="${SERVED_VERSION_URL:-}"

if [[ -z "$expected" ]]; then
  echo "SERVED_VERSION is empty; refusing to treat every response as the new version." >&2
  exit 1
fi

if [[ -z "$url" ]]; then
  if [[ "$mode" == "json" ]]; then
    url="https://api.pistisai.app/service-version"
  else
    url="https://pistisai.app/"
  fi
fi

case "$url" in
  http://*|https://*) ;;
  *)
    echo "SERVED_VERSION_URL must be an http or https URL." >&2
    exit 1
    ;;
esac

if ! [[ "$timeout" =~ ^[0-9]+$ && "$interval" =~ ^[0-9]+$ ]]; then
  echo "SERVED_VERSION_TIMEOUT_SECONDS and SERVED_VERSION_INTERVAL_SECONDS must be whole seconds." >&2
  exit 1
fi

deadline=$((SECONDS + timeout))

while true; do
  body_file="$(mktemp)"
  err_file="$(mktemp)"
  code="$(
    curl --silent --show-error \
      --connect-timeout 10 \
      --max-time 20 \
      --output "$body_file" \
      --write-out '%{http_code}' \
      -H 'Cache-Control: no-cache' \
      -H 'Pragma: no-cache' \
      -G --data-urlencode "cb=${SECONDS}" \
      --url "$url" 2>"$err_file" || true
  )"
  rm -f "$err_file"

  matched=0
  if [[ "$code" =~ ^2[0-9][0-9]$ ]]; then
    if [[ "$mode" == "json" ]]; then
      if jq -e --arg value "$expected" --arg field "$field" '.[$field] == $value' "$body_file" >/dev/null 2>&1; then
        matched=1
      fi
    elif grep -F -q -- "$expected" "$body_file"; then
      matched=1
    fi
  fi
  rm -f "$body_file"

  if [[ "$matched" -eq 1 ]]; then
    echo "Host is serving the new version."
    exit 0
  fi

  if (( SECONDS >= deadline )); then
    echo "Timed out after ${timeout}s waiting for the host to serve the new version." >&2
    exit 1
  fi

  sleep "$interval"
done
