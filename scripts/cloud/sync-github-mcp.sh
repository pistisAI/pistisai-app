#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI not available; skipping GitHub MCP sync" >&2
  exit 0
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "gh not authenticated; skipping GitHub MCP sync" >&2
  exit 0
fi

token="$(gh auth token)"

export GH_TOKEN="$token"
export GITHUB_TOKEN="$token"
export GITHUB_MCP_TOKEN="$token"

env_file="${HOME}/.cursor/cloud-agent.env"
mkdir -p "$(dirname "$env_file")"
cat >"$env_file" <<EOF
export GH_TOKEN='${token}'
export GITHUB_TOKEN='${token}'
export GITHUB_MCP_TOKEN='${token}'
EOF
chmod 600 "$env_file"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT="$repo_root"

python3 - <<'PY'
import json
import os

token = os.environ["GITHUB_MCP_TOKEN"]
entry = {
    "type": "http",
    "url": "https://api.githubcopilot.com/mcp/",
    "headers": {"Authorization": f"Bearer {token}"},
}

repo_root = os.environ["REPO_ROOT"]
paths = [
    os.path.expanduser("~/.cursor/mcp.json"),
    os.path.join(repo_root, ".cursor", "mcp-runtime.json"),
]

for path in paths:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    config: dict = {"mcpServers": {}}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as handle:
            config = json.load(handle)
    config.setdefault("mcpServers", {})["github"] = entry
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(config, handle, indent=2)
        handle.write("\n")
    os.chmod(path, 0o600)
    print(f"Updated {path}")
PY
