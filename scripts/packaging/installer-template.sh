#!/bin/bash
# Pistisai Linux Installer
set -e

INSTALL_VERSION=""
INSTALL_CHANNEL="stable"
INSTALL_DIR=""
SYSTEM_WIDE=false
SKIP_DAEMON=false
SILENT=false

show_help() {
    cat << EOF
Pistisai Linux Installer

Usage: curl -fsSL https://pistisai.app/install.sh | bash [OPTIONS]

Options:
    --system              Install system-wide to /opt (requires sudo)
    --channel <channel>    Update channel: stable, beta, edge (default: stable)
    --dir <path>          Custom installation directory
    --no-daemon           Skip update daemon installation
    --silent              Suppress output except errors
    -h, --help            Show this help message

Environment Variables:
    PISTISAI_DIR       Override installation directory
    PISTISAI_CHANNEL   Default update channel

Examples:
    # User-local installation (default)
    curl -fsSL https://pistisai.app/install.sh | bash

    # System-wide installation
    curl -fsSL https://pistisai.app/install.sh | bash -s -- --system

    # Beta channel
    curl -fsSL https://pistisai.app/install.sh | bash -s -- --channel beta
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --system)
            SYSTEM_WIDE=true
            shift
            ;;
        --channel)
            INSTALL_CHANNEL="$2"
            shift 2
            ;;
        --dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --no-daemon)
            SKIP_DAEMON=true
            shift
            ;;
        --silent)
            SILENT=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Logging functions
log_info() {
    if [ "$SILENT" != true ]; then
        echo "📦 $1"
    fi
}

log_success() {
    if [ "$SILENT" != true ]; then
        echo "✅ $1"
    fi
}

log_warning() {
    echo "⚠️  $1" >&2
}

log_error() {
    echo "❌ $1" >&2
}

# Detect latest version from GitHub releases
detect_latest_version() {
    local channel="${1:-stable}"
    local api_url="https://api.github.com/repos/pistisAI/pistisai-app/releases/latest"

    if [ "$channel" != "stable" ]; then
        api_url="https://api.github.com/repos/pistisAI/pistisai-app/releases?per_page=1"
    fi

    if command -v curl &> /dev/null; then
        VERSION=$(curl -s "$api_url" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')
    elif command -v wget &> /dev/null; then
        VERSION=$(wget -qO- "$api_url" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')
    else
        log_error "Neither curl nor wget found"
        exit 1
    fi

    if [ -z "$VERSION" ]; then
        log_error "Failed to detect version from GitHub API"
        exit 1
    fi

    echo "$VERSION"
}

# Setup installation directory
setup_install_dir() {
    local system_wide="$1"
    local custom_dir="$2"

    local install_dir=""

    # Check for environment variable override
    if [ -n "$PISTISAI_DIR" ]; then
        install_dir="$PISTISAI_DIR"
    elif [ -n "$custom_dir" ]; then
        install_dir="$custom_dir"
    elif [ "$system_wide" = true ]; then
        install_dir="/opt/pistisai"
    else
        install_dir="$HOME/.local/share/pistisai"
    fi

    mkdir -p "$install_dir"
    mkdir -p "$install_dir/icons"
    mkdir -p "$install_dir/cache"

    echo "$install_dir"
}

# Download AppImage from GitHub releases
download_appimage() {
    local version="$1"
    local channel="$2"
    local output_dir="$3"

    local base_url="https://github.com/pistisAI/pistisai-app/releases/download/v${version}"
    local appimage_name="Pistisai-${version}-x86_64.AppImage"
    local download_url="${base_url}/${appimage_name}"

    echo "📦 Downloading Pistisai v${version}..." >&2

    mkdir -p "$output_dir"

    if command -v curl &> /dev/null; then
        curl -L -o "${output_dir}/${appimage_name}" "$download_url" >&2
    elif command -v wget &> /dev/null; then
        wget -O "${output_dir}/${appimage_name}" "$download_url" >&2
    else
        log_error "Neither curl nor wget found"
        return 1
    fi

    chmod +x "${output_dir}/${appimage_name}"

    # Verify download
    if [ ! -f "${output_dir}/${appimage_name}" ]; then
        log_error "Download failed"
        return 1
    fi

    echo "✅ Downloaded to ${output_dir}/${appimage_name}" >&2
    echo "${output_dir}/${appimage_name}"
}

# Create desktop entry
create_desktop_entry() {
    local install_dir="$1"
    local system_wide="$2"

    local desktop_dir=""
    local icon_dir=""

    if [ "$system_wide" = true ]; then
        desktop_dir="/usr/share/applications"
        icon_dir="/usr/share/icons/hicolor"
    else
        desktop_dir="$HOME/.local/share/applications"
        icon_dir="$HOME/.local/share/icons"
    fi

    mkdir -p "$desktop_dir"
    mkdir -p "$icon_dir/hicolor"

    cat > "${desktop_dir}/pistisai.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Pistisai
GenericName=AI Model Bridge
Comment=Manage and run powerful Large Language Models locally
Icon=pistisai
Exec=${install_dir}/Pistisai %u
Terminal=false
Categories=Development;Utility;Network;
Keywords=AI;LLM;Machine Learning;Ollama;Local;
StartupNotify=true
StartupWMClass=Pistisai
MimeType=x-scheme-handler/pistisai;
EOF

    # Copy icon
    if [ -f "${install_dir}/icons/pistisai.png" ]; then
        mkdir -p "$icon_dir/hicolor/128x128/apps"
        cp "${install_dir}/icons/pistisai.png" "$icon_dir/hicolor/128x128/apps/pistisai.png"
    fi

    log_success "Created desktop entry"
}

# Update desktop database
update_desktop_database() {
    if command -v update-desktop-database &> /dev/null; then
        update-desktop-database ~/.local/share/applications 2>/dev/null || true
    fi

    if command -v gtk-update-icon-cache &> /dev/null; then
        gtk-update-icon-cache ~/.local/share/icons 2>/dev/null || true
    fi
}

# Install and enable update daemon
install_daemon() {
    local install_dir="$1"
    local system_wide="$2"

    log_info "Installing update daemon..."

    # Extract embedded files from base64
    echo "$EMBEDDED_UPDATED" | base64 -d > "${install_dir}/pistisai-updated"
    chmod +x "${install_dir}/pistisai-updated"

    if [ "$system_wide" = true ]; then
        # System-wide installation
        echo "$EMBEDDED_UPDATED_SERVICE" | base64 -d > /etc/systemd/system/pistisai-updated.service
        echo "$EMBEDDED_UPDATED_TIMER" | base64 -d > /etc/systemd/system/pistisai-updated.timer

        systemctl daemon-reload || true
        systemctl unmask pistisai-updated.service pistisai-updated.timer 2>/dev/null || true
        if ! systemctl enable pistisai-updated.timer; then
            log_warning "Could not enable system update timer; continuing"
        fi
        if ! systemctl start pistisai-updated.timer; then
            log_warning "Could not start system update timer; continuing"
        fi
    else
        # User installation
        local user_service_dir="$HOME/.config/systemd/user"
        mkdir -p "$user_service_dir"

        # Extract and adapt service file for user installation
        echo "$EMBEDDED_UPDATED_SERVICE" | base64 -d | sed "s|%h|%h|g" > "$user_service_dir/pistisai-updated.service"
        echo "$EMBEDDED_UPDATED_TIMER" | base64 -d | sed "s|%h|%h|g" > "$user_service_dir/pistisai-updated.timer"

        systemctl --user daemon-reload || true
        systemctl --user unmask pistisai-updated.service pistisai-updated.timer 2>/dev/null || true
        if ! systemctl --user enable pistisai-updated.timer; then
            log_warning "Could not enable user update timer; continuing"
        fi
        if ! systemctl --user start pistisai-updated.timer; then
            log_warning "Could not start user update timer; continuing"
        fi
    fi

    log_success "Update daemon installed and enabled"
}

main() {
    local version="${INSTALL_VERSION}"

    if [ -z "$version" ]; then
        version="$(detect_latest_version "$INSTALL_CHANNEL")"
    fi

    if [ -z "$INSTALL_DIR" ]; then
        INSTALL_DIR="$(setup_install_dir "$SYSTEM_WIDE" "")"
    else
        INSTALL_DIR="$(setup_install_dir "$SYSTEM_WIDE" "$INSTALL_DIR")"
    fi

    local downloaded_appimage
    downloaded_appimage="$(download_appimage "$version" "$INSTALL_CHANNEL" "$INSTALL_DIR")"

    # Create stable launcher name expected by the desktop file
    cp "$downloaded_appimage" "$INSTALL_DIR/Pistisai"
    chmod +x "$INSTALL_DIR/Pistisai"

    create_desktop_entry "$INSTALL_DIR" "$SYSTEM_WIDE"
    update_desktop_database

    if [ "$SKIP_DAEMON" != true ]; then
        install_daemon "$INSTALL_DIR" "$SYSTEM_WIDE"
    fi

    log_success "Pistisai installed successfully"
    echo "Installed version: $version"
    echo "Location: $INSTALL_DIR/Pistisai"
}

main "$@"
