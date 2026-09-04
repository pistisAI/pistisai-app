#!/usr/bin/env bash
set -euo pipefail

# Persist and restore a *user* GitHub token for `gh` / GitHub MCP, and wire the
# runtime MCP config for Cloud Agents.
# Cloud Agent boot injects a `ghs_` GitHub App token that can push git but
# cannot write issues. A user OAuth token (`gho_`) or PAT (`ghp_` /
# `github_pat_`) must win, and must be rewritten into gh's hosts.yml on
# every boot because Cursor may reset ~/.config/gh to the App account.
#
# It also injects the Supabase MCP server into the runtime config when a
# SUPABASE_ACCESS_TOKEN secret is present: the hosted server uses browser OAuth
# that a headless agent cannot complete, so the token is passed as a Bearer
# header instead. When the secret is absent, Supabase is simply skipped.

ENV_FILE="${HOME}/.cursor/cloud-agent.env"
TOKEN_FILE="${HOME}/.config/gh/pistisai-user.token"

is_user_token() {
  case "${1:-}" in
    gho_*|ghp_*|github_pat_*) return 0 ;;
    *) return 1 ;;
  esac
}

read_token_file() {
  local path="$1"
  [[ -f "$path" ]] || return 1
  # shellcheck disable=SC1090
  if [[ "$path" == *.env ]]; then
    # shellcheck disable=SC1091
    . "$path"
    printf '%s' "${GH_TOKEN:-${GITHUB_TOKEN:-${GITHUB_MCP_TOKEN:-}}}"
    return 0
  fi
  tr -d '[:space:]' <"$path"
}

token=""
if is_user_token "${GH_TOKEN:-}"; then
  token="$GH_TOKEN"
elif is_user_token "${GITHUB_TOKEN:-}"; then
  token="$GITHUB_TOKEN"
elif is_user_token "${GITHUB_MCP_TOKEN:-}"; then
  token="$GITHUB_MCP_TOKEN"
else
  persisted="$(read_token_file "$ENV_FILE" 2>/dev/null || true)"
  if is_user_token "$persisted"; then
    token="$persisted"
  else
    persisted="$(read_token_file "$TOKEN_FILE" 2>/dev/null || true)"
    if is_user_token "$persisted"; then
      token="$persisted"
    fi
  fi
fi

if [[ -z "$token" ]]; then
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    token="$(gh auth token 2>/dev/null || true)"
  fi
fi

if [[ -z "$token" ]]; then
  echo "gh not authenticated and no user GH_TOKEN set; skipping GitHub MCP sync" >&2
  exit 0
fi

export GH_TOKEN="$token"
export GITHUB_TOKEN="$token"
export GITHUB_MCP_TOKEN="$token"

mkdir -p "$(dirname "$ENV_FILE")" "$(dirname "$TOKEN_FILE")"
umask 077
cat >"$ENV_FILE" <<EOF
export PATH="\$HOME/.local/bin:\$PATH"
export GH_TOKEN='${token}'
export GITHUB_TOKEN='${token}'
export GITHUB_MCP_TOKEN='${token}'
EOF
chmod 600 "$ENV_FILE"

  if is_user_token "$token"; then
    printf '%s\n' "$token" >"$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    mkdir -p "${HOME}/.local/bin"
    cat >"${HOME}/.local/bin/gh" <<'WRAP'
#!/bin/bash
if [ -f "${HOME}/.cursor/cloud-agent.env" ]; then
  # shellcheck disable=SC1091
  . "${HOME}/.cursor/cloud-agent.env"
fi
for candidate in /exec-daemon/gh /usr/bin/gh /usr/local/bin/gh; do
  if [ -x "$candidate" ]; then
    exec "$candidate" "$@"
  fi
done
echo "gh wrapper: no GitHub CLI binary found" >&2
exit 127
WRAP
    chmod 755 "${HOME}/.local/bin/gh"
    if command -v /exec-daemon/gh >/dev/null 2>&1; then
      env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN \
        /exec-daemon/gh auth login --hostname github.com --with-token --insecure-storage <"$TOKEN_FILE" >/dev/null
      env -u GH_TOKEN -u GITHUB_TOKEN \
        /exec-daemon/gh auth switch --user imrightguy >/dev/null 2>&1 || true
    fi
  fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT="$repo_root"

python3 - <<'PY'
import json
import os

repo_root = os.environ["REPO_ROOT"]
runtime_paths = [
    os.path.expanduser("~/.cursor/mcp.json"),
    os.path.join(repo_root, ".cursor", "mcp-runtime.json"),
]

servers: dict = {}

# GitHub MCP: inject the resolved user/App token as a Bearer header.
github_token = os.environ.get("GITHUB_MCP_TOKEN")
if github_token:
    servers["github"] = {
        "type": "http",
        "url": "https://api.githubcopilot.com/mcp/",
        "headers": {"Authorization": f"Bearer {github_token}"},
    }

# Supabase MCP: the hosted server uses browser OAuth for interactive clients,
# which a headless Cloud Agent cannot complete. When a personal access token is
# provided (SUPABASE_ACCESS_TOKEN secret), authenticate non-interactively by
# passing it as a Bearer header. The URL/features are taken from the committed
# .cursor/mcp.json so the runtime follows whatever the project config declares.
supabase_token = os.environ.get("SUPABASE_ACCESS_TOKEN")
if supabase_token:
    supabase_url = None
    committed = os.path.join(repo_root, ".cursor", "mcp.json")
    if os.path.exists(committed):
        try:
            with open(committed, encoding="utf-8") as handle:
                declared = json.load(handle)
            supabase_url = (
                declared.get("mcpServers", {}).get("supabase", {}).get("url")
            )
        except (OSError, ValueError):
            supabase_url = None
    servers["supabase"] = {
        "type": "http",
        "url": supabase_url or "https://mcp.supabase.com/mcp",
        "headers": {"Authorization": f"Bearer {supabase_token}"},
    }
else:
    print("SUPABASE_ACCESS_TOKEN not set; skipping Supabase MCP sync")

for path in runtime_paths:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    config: dict = {"mcpServers": {}}
    if os.path.exists(path):
        try:
            with open(path, encoding="utf-8") as handle:
                config = json.load(handle)
        except ValueError:
            config = {"mcpServers": {}}
    config.setdefault("mcpServers", {})
    for name, entry in servers.items():
        config["mcpServers"][name] = entry
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(config, handle, indent=2)
        handle.write("\n")
    os.chmod(path, 0o600)
    print(f"Updated {path}")
PY
