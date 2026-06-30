#!/bin/bash
#
# install.sh - One-liner installer for Hyprland on Fedora 44.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/hamza72x/Hyprland/main/hamza72x/install.sh | sudo bash
#
set -euo pipefail

REPO="hamza72x/Hyprland"
REPO_BASE_URL="https://raw.githubusercontent.com/$REPO/main/hamza72x"
API_URL="https://api.github.com/repos/$REPO/releases/latest"
WORKDIR="$(mktemp -d)"

cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root:"
    echo "  curl -fsSL $REPO_BASE_URL/install.sh | sudo bash"
    exit 1
fi

echo ""
echo "============================================="
echo " Hyprland Installer for Fedora 44"
echo "============================================="
echo ""

# --- Fetch latest release RPM URL ---
echo "Finding latest release..."
RPM_URL="$(curl -fsSL "$API_URL" \
    | grep -o '"browser_download_url": *"[^"]*\.rpm"' \
    | head -1 \
    | cut -d'"' -f4)"

if [ -z "$RPM_URL" ]; then
    echo "Error: Could not find RPM in latest release at $API_URL"
    exit 1
fi

echo "  Release: $RPM_URL"
echo ""

# --- Download all required files ---
echo "Downloading installer files..."
curl -fSL -o "$WORKDIR/common.sh" "$REPO_BASE_URL/common.sh"

mkdir -p "$WORKDIR/configs/hypr" "$WORKDIR/configs/waybar" "$WORKDIR/configs/alacritty"
for f in hypr/hyprland.lua hypr/hyprland.conf hypr/keybindings.conf hypr/windowrules.conf hypr/monitors.conf hypr/animations.conf; do
    curl -fsSL -o "$WORKDIR/configs/$f" "$REPO_BASE_URL/configs/$f" 2>/dev/null || true
done
for f in waybar/config.jsonc waybar/style.css; do
    curl -fsSL -o "$WORKDIR/configs/$f" "$REPO_BASE_URL/configs/$f" 2>/dev/null || true
done
for f in alacritty/alacritty.toml alacritty/colors.toml; do
    curl -fsSL -o "$WORKDIR/configs/$f" "$REPO_BASE_URL/configs/$f" 2>/dev/null || true
done

echo "Downloading RPM..."
RPM_FILE="$WORKDIR/$(basename "$RPM_URL")"
curl -fSL -o "$RPM_FILE" "$RPM_URL"
echo ""

# --- Run install ---
source "$WORKDIR/common.sh"

install_dependencies

info "Installing Hyprland RPM..."
echo ""
dnf install -y "$RPM_FILE"

# Install default configs as the real user
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(eval echo "~$REAL_USER")"
if [ -d "$WORKDIR/configs" ]; then
    export HOME="$REAL_HOME"
    su "$REAL_USER" -c "source '$WORKDIR/common.sh' && install_configs '$WORKDIR/configs'"
fi

post_install
