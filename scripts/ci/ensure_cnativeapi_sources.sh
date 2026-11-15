#!/usr/bin/env bash
# Ensure tool/cnativeapi can see nativeapi core sources before flutter build.
# Prefer a git submodule checkout; otherwise fetch cxx_impl from the published
# cnativeapi archive (same source linux_native_deps uses on Linux).
set -euo pipefail

MARKER="tool/cnativeapi/cxx_impl/src/CMakeLists.txt"
CORE_MARKER="core/src/CMakeLists.txt"
# Keep in sync with the path override version in pubspec.yaml (cnativeapi 0.5.2).
ARCHIVE_URL="https://pub.dev/api/archives/cnativeapi-0.5.2.tar.gz"

if [[ -f "$MARKER" ]] || [[ -f "$CORE_MARKER" ]]; then
  echo "cnativeapi native sources already present"
  exit 0
fi

if [[ -f .gitmodules ]]; then
  git submodule update --init --recursive
  if [[ -f "$MARKER" ]] || [[ -f "$CORE_MARKER" ]]; then
    echo "cnativeapi native sources from git submodules"
    exit 0
  fi
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$ARCHIVE_URL" | tar -xzf - -C "$tmp" cxx_impl
rm -rf tool/cnativeapi/cxx_impl
mv "$tmp/cxx_impl" tool/cnativeapi/cxx_impl
test -f "$MARKER"
echo "cnativeapi cxx_impl fetched from pub.dev archive"
