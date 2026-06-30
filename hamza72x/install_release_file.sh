#!/bin/bash
#
# install_release_file.sh - Install Hyprland from a GitHub release URL.
#
# Downloads the RPM and installs runtime deps, desktop packages, SDDM, and configs.
# Meant for barebone Fedora installations. Can be used standalone (downloads its deps).
#
# Usage:
#   sudo ./install_release_file.sh <rpm-url>
#   sudo ./install_release_file.sh https://github.com/hamza72x/Hyprland/releases/download/v0.55.0-fedora44/hyprland-0.55.0-1.fc44.custom.x86_64.rpm
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_BASE_URL="https://raw.githubusercontent.com/hamza72x/Hyprland/main/hamza72x"

# Auto-fetch common.sh and configs if not found locally (standalone mode)
if [ ! -f "$SCRIPT_DIR/common.sh" ]; then
    echo "Standalone mode: downloading required files..."
    curl -fSL -o "$SCRIPT_DIR/common.sh" "$REPO_BASE_URL/common.sh"

    mkdir -p "$SCRIPT_DIR/configs/hypr" "$SCRIPT_DIR/configs/waybar" "$SCRIPT_DIR/configs/alacritty"
    for f in hypr/hyprland.lua hypr/hyprland.conf hypr/keybindings.conf hypr/windowrules.conf hypr/monitors.conf hypr/animations.conf; do
        curl -fSL -o "$SCRIPT_DIR/configs/$f" "$REPO_BASE_URL/configs/$f" 2>/dev/null || true
    done
    for f in waybar/config.jsonc waybar/style.css; do
        curl -fSL -o "$SCRIPT_DIR/configs/$f" "$REPO_BASE_URL/configs/$f" 2>/dev/null || true
    done
    for f in alacritty/alacritty.toml alacritty/colors.toml; do
        curl -fSL -o "$SCRIPT_DIR/configs/$f" "$REPO_BASE_URL/configs/$f" 2>/dev/null || true
    done
    echo ""
fi

source "$SCRIPT_DIR/common.sh"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo ./install_release_file.sh <url>"
    exit 1
fi

URL="${1:-}"

if [ -z "$URL" ]; then
    echo "Usage: sudo ./install_release_file.sh <rpm-url>"
    echo ""
    echo "Example:"
    echo "  sudo ./install_release_file.sh https://github.com/hamza72x/Hyprland/releases/download/v0.55.0-fedora44/hyprland-0.55.0-1.fc44.custom.x86_64.rpm"
    exit 1
fi

TMPDIR="$(mktemp -d)"
RPM_FILE="$TMPDIR/$(basename "$URL")"

cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

echo "Source: $URL"

# Download RPM
info "Downloading Hyprland RPM..."
curl -fSL -o "$RPM_FILE" "$URL"
ok "Downloaded $(basename "$RPM_FILE")"
echo ""

# Install all dependencies (runtime + desktop + SDDM)
install_dependencies

# Install Hyprland RPM
info "Installing Hyprland RPM..."
echo ""
dnf install -y "$RPM_FILE"

# Install default configs (run as the real user, not root)
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(eval echo "~$REAL_USER")"
if [ -d "$SCRIPT_DIR/configs" ]; then
    export HOME="$REAL_HOME"
    su "$REAL_USER" -c "source '$SCRIPT_DIR/common.sh' && install_configs '$SCRIPT_DIR/configs'"
fi

post_install
