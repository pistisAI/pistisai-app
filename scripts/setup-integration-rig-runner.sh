#!/usr/bin/env bash
# Register this Linux PC as a GitHub Actions runner for the physical integration test rig.
# Labels: linux, self-hosted, integration-rig
#
# Get a registration token from:
#   https://github.com/pistisAI/pistisai-app/settings/actions/runners/new?arch=x64&os=linux
set -euo pipefail

GITHUB_REPO="${GITHUB_REPO:-https://github.com/pistisAI/pistisai-app}"
RUNNER_LABELS="linux,self-hosted,integration-rig"
RUNNER_VERSION="${RUNNER_VERSION:-2.329.0}"
RUNNER_DIR="${RUNNER_DIR:-$HOME/actions-runner-integration-rig}"

echo "Physical integration rig runner setup"
echo "Repo: $GITHUB_REPO"
echo "Install dir: $RUNNER_DIR"
echo ""

for cmd in curl git docker adb flutter; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon must be running." >&2
  exit 1
fi

if [[ -z "${GITHUB_RUNNER_TOKEN:-}" ]]; then
  echo "Set GITHUB_RUNNER_TOKEN to the one-time registration token from GitHub."
  echo "Example: GITHUB_RUNNER_TOKEN=... bash scripts/setup-integration-rig-runner.sh"
  exit 1
fi

RUNNER_NAME="${RUNNER_NAME:-integration-rig-$(hostname -s)}"
ARCH="x64"
TARBALL="actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz"

mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

if [[ ! -f ./config.sh ]]; then
  curl -fsSL -o "$TARBALL" "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${TARBALL}"
  tar xzf "$TARBALL"
  rm -f "$TARBALL"
fi

./config.sh \
  --url "$GITHUB_REPO" \
  --token "$GITHUB_RUNNER_TOKEN" \
  --name "$RUNNER_NAME" \
  --labels "$RUNNER_LABELS" \
  --unattended \
  --replace

echo ""
echo "Runner configured. Start it:"
echo "  cd $RUNNER_DIR && ./run.sh"
echo ""
echo "Or install as a service (systemd):"
echo "  cd $RUNNER_DIR && sudo ./svc.sh install && sudo ./svc.sh start"
echo ""
echo "Then run workflow: Actions → Integration Test Rig (Physical USB)"
