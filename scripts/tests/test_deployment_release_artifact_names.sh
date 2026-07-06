#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_FILE="$PROJECT_ROOT/.github/workflows/deployment.yml"
SCRIPT_FILE="$PROJECT_ROOT/scripts/release/verify_github_release_assets.py"

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "Missing deployment workflow: $WORKFLOW_FILE" >&2
  exit 1
fi

if [[ ! -f "$SCRIPT_FILE" ]]; then
  echo "Missing release asset verifier: $SCRIPT_FILE" >&2
  exit 1
fi

for needle in \
  'mkdir -p "$STAGING_DIR/pistisai"' \
  'cp -a build/linux/x64/release/bundle/. "$STAGING_DIR/pistisai/"' \
  'tar -czf dist/linux/pistisai-linux-x64.tar.gz -C "$STAGING_DIR" pistisai' \
  'build-tools/installers/windows/' \
  'windows/installer/' \
  'name: windows-release-assets' \
  'Verify Windows Release Assets' \
  'test -f "dist/windows/pistisai-${VERSION}-portable.zip"' \
  'test -f "dist/windows/pistisai-${VERSION}-portable.zip.sha256"' \
  'test -f "dist/windows/Pistisai-Windows-${VERSION}-Setup.exe"' \
  'Verify GitHub Release Assets Published' \
  'run: python3 scripts/release/verify_github_release_assets.py' \
  'test -f "dist/windows/Pistisai-Windows-${VERSION}-Setup.exe.sha256"' \
  'pistisai-x86_64.AppImage' \
  'artifacts: "dist/linux/*,dist/windows/pistisai-${{ needs.ai_change_analysis.outputs.new_version }}-portable.zip,dist/windows/pistisai-${{ needs.ai_change_analysis.outputs.new_version }}-portable.zip.sha256,dist/windows/Pistisai-Windows-${{ needs.ai_change_analysis.outputs.new_version }}-Setup.exe,dist/windows/Pistisai-Windows-${{ needs.ai_change_analysis.outputs.new_version }}-Setup.exe.sha256,dist/aur/*"' \
  '### Windows' \
  '- `pistisai-${{ needs.ai_change_analysis.outputs.new_version }}-portable.zip`' \
  '- `Pistisai-Windows-${{ needs.ai_change_analysis.outputs.new_version }}-Setup.exe`'; do
  if ! grep -Fq -- "$needle" "$WORKFLOW_FILE"; then
    echo "Deployment workflow missing expected release artifact hardening string: $needle" >&2
    exit 1
  fi
done

for needle in \
  'required_assets = {' \
  'pistisai-{version}-portable.zip' \
  'pistisai-{version}-portable.zip.sha256' \
  'Pistisai-Windows-{version}-Setup.exe' \
  'Pistisai-Windows-{version}-Setup.exe.sha256' \
  'pistisai_{version}_amd64.deb' \
  'pistisai_{version}_amd64.deb.sha256' \
  'pistisai-{version}-x86_64.AppImage' \
  'pistisai-{version}-x86_64.AppImage.sha256' \
  'Verified GitHub release assets: ' \
  'Missing release assets: '; do
  if ! grep -Fq "$needle" "$SCRIPT_FILE"; then
    echo "Release asset verifier missing expected string: $needle" >&2
    exit 1
  fi
done

echo "[test_deployment_release_artifact_names] Passed"
