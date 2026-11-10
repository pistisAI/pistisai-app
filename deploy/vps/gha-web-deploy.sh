#!/usr/bin/env bash
# Forced SSH command used by GitHub Actions to deploy a web image to the VPS.
# This is the ONLY deploy path. Manual deploys are prohibited.
#
# Installed as /usr/local/sbin/gha-web-deploy (root:root 0755). Each repo gets its
# own key in ~ghdeploy/.ssh/authorized_keys, pinned to one app:
#   restrict,command="/usr/local/sbin/gha-web-deploy iacle" ssh-ed25519 AAAA... iacle-app-gha
# stdin:                 `docker save <app>-web:gha-<sha12>`
# SSH_ORIGINAL_COMMAND:  the full 40-char commit sha
set -euo pipefail

app="${1:?usage: gha-web-deploy <app>}"
case "$app" in
  iacle) port=8081 ;;
  pistisai) port=8070 ;;
  *) echo "unknown app: $app" >&2; exit 2 ;;
esac

sha="${SSH_ORIGINAL_COMMAND:-}"
if ! [[ "$sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo "expected a 40-char commit sha, got: '$sha'" >&2
  exit 2
fi

name="${app}-web"
image="${name}:gha-${sha:0:12}"
prev="${name}-prev"

loaded="$(docker load | sed -n 's/^Loaded image: //p' | tail -1)"
if [ "$loaded" != "$image" ]; then
  echo "stdin image '$loaded' is not '$image'" >&2
  [ -n "$loaded" ] && docker rmi "$loaded" >/dev/null 2>&1 || true
  exit 2
fi

rollback() {
  echo "deploy of $image failed, rolling back" >&2
  docker logs --tail 50 "$name" >&2 2>&1 || true
  docker rm -f "$name" >/dev/null 2>&1 || true
  if docker inspect "$prev" >/dev/null 2>&1; then
    docker rename "$prev" "$name"
    docker start "$name" >/dev/null
  fi
  exit 1
}

docker rm -f "$prev" >/dev/null 2>&1 || true
if docker inspect "$name" >/dev/null 2>&1; then
  docker rename "$name" "$prev"
  docker stop "$prev" >/dev/null
fi

docker run -d --name "$name" --restart unless-stopped -p "127.0.0.1:${port}:80" "$image" >/dev/null || rollback

code=000
for _ in $(seq 1 30); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${port}/" || true)"
  [ "$code" = "200" ] && break
  sleep 2
done
[ "$code" = "200" ] || rollback

echo "deployed $image on 127.0.0.1:${port} (previous container kept as $prev)"

# Keep the 3 newest gha images of this app; in-use images are skipped by docker.
docker images --format '{{.Repository}}:{{.Tag}}' "$name" | grep ':gha-' | tail -n +4 \
  | xargs -r docker rmi >/dev/null 2>&1 || true
