#!/usr/bin/env bash
# Cloud Agent install: provision the Flutter toolchain and project dependencies
# so the documented dev/CI gates (flutter analyze, flutter tests, backend
# lint/security tests) can run out of the box.
#
# Must be idempotent: it may run repeatedly and against cached or partially
# prepared state, and it becomes the baseline snapshot for environment builds.
set -euo pipefail

FLUTTER_VERSION="3.44.6"
FLUTTER_CHANNEL="stable"
FLUTTER_HOME="${FLUTTER_HOME:-${HOME}/flutter}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

log() { echo "==> $*"; }

install_linux_build_deps() {
  # System libraries required for `flutter build linux` (mirrors CI). Best-effort:
  # analyze/test gates do not need these, so a transient apt failure must not
  # block dependency provisioning.
  if ! command -v sudo >/dev/null 2>&1; then
    log "sudo unavailable; skipping Linux desktop build deps"
    return 0
  fi
  log "Installing Linux desktop build dependencies via apt"
  if ! sudo apt-get update -qq; then
    log "apt-get update failed; skipping Linux desktop build deps"
    return 0
  fi
  sudo apt-get install -y -qq \
    clang cmake ninja-build pkg-config \
    libgtk-3-dev liblzma-dev libstdc++-12-dev \
    libsecret-1-dev libjsoncpp-dev \
    libnotify-dev libcurl4-openssl-dev \
    libayatana-appindicator3-dev \
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-libav \
    xz-utils unzip git curl \
    || log "Some Linux desktop build deps failed to install; continuing"
}

install_flutter() {
  if [[ -x "${FLUTTER_HOME}/bin/flutter" ]]; then
    local current
    current="$("${FLUTTER_HOME}/bin/flutter" --version 2>/dev/null | head -1 || true)"
    if [[ "${current}" == *"${FLUTTER_VERSION}"* ]]; then
      log "Flutter ${FLUTTER_VERSION} already present at ${FLUTTER_HOME}"
      return 0
    fi
    log "Flutter present but not ${FLUTTER_VERSION} (${current}); reinstalling"
    rm -rf "${FLUTTER_HOME}"
  fi

  local archive="flutter_linux_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz"
  local url="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/linux/${archive}"
  local tmp
  tmp="$(mktemp -d)"
  log "Downloading Flutter ${FLUTTER_VERSION} (${FLUTTER_CHANNEL})"
  curl -fSL --retry 4 --retry-delay 4 -o "${tmp}/${archive}" "${url}"
  log "Extracting Flutter to ${FLUTTER_HOME}"
  mkdir -p "$(dirname "${FLUTTER_HOME}")"
  tar -xJf "${tmp}/${archive}" -C "$(dirname "${FLUTTER_HOME}")"
  rm -rf "${tmp}"
}

link_flutter_on_path() {
  # Symlinking into /usr/local/bin guarantees flutter/dart resolve in every
  # shell (login or not) without relying on shell rc files.
  if command -v sudo >/dev/null 2>&1; then
    sudo ln -sfn "${FLUTTER_HOME}/bin/flutter" /usr/local/bin/flutter
    sudo ln -sfn "${FLUTTER_HOME}/bin/dart" /usr/local/bin/dart
  fi

  # Also persist on PATH for interactive shells that read rc files.
  local rc_line="export PATH=\"${FLUTTER_HOME}/bin:\$PATH\""
  local rc
  for rc in "${HOME}/.bashrc" "${HOME}/.profile"; do
    if [[ -f "${rc}" ]] && ! grep -qF "${FLUTTER_HOME}/bin" "${rc}"; then
      printf '\n# Flutter SDK (added by cloud install)\n%s\n' "${rc_line}" >>"${rc}"
    fi
  done
  export PATH="${FLUTTER_HOME}/bin:${PATH}"
}

configure_flutter() {
  log "Configuring Flutter (git safe.directory, precache, config)"
  git config --global --add safe.directory "${FLUTTER_HOME}" || true
  flutter config --no-analytics >/dev/null 2>&1 || true
  flutter config --enable-linux-desktop --enable-web >/dev/null 2>&1 || true
  # Warm the artifact cache for the platforms agents build (linux + web).
  flutter precache --linux --web --universal >/dev/null 2>&1 || \
    log "flutter precache had non-fatal issues; continuing"
}

flutter_pub_get() {
  log "Resolving Flutter packages (app + shared)"
  (cd "${REPO_ROOT}" && flutter pub get)
  if [[ -f "${REPO_ROOT}/lib/shared/pubspec.yaml" ]]; then
    (cd "${REPO_ROOT}/lib/shared" && flutter pub get) || \
      log "lib/shared pub get failed; continuing"
  fi
}

npm_install_dir() {
  local dir="$1"
  if [[ -f "${dir}/package.json" ]]; then
    log "npm install in ${dir#${REPO_ROOT}/}"
    (cd "${dir}" && npm install --no-audit --no-fund)
  fi
}

install_node_deps() {
  npm_install_dir "${REPO_ROOT}"
  npm_install_dir "${REPO_ROOT}/services/api-backend"
  npm_install_dir "${REPO_ROOT}/services/streaming-proxy"
  npm_install_dir "${REPO_ROOT}/services/sdk"
}

main() {
  install_linux_build_deps
  install_flutter
  link_flutter_on_path
  configure_flutter
  flutter_pub_get
  install_node_deps
  log "Cloud install complete"
  flutter --version || true
  node --version || true
}

main "$@"
