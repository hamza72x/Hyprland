#!/bin/bash
#
# install_release_file.sh - Install Hyprland from a GitHub release URL.
#
# Downloads the RPM from the given URL and installs it.
#
# Usage:
#   sudo ./install_release_file.sh <rpm-url>
#   sudo ./install_release_file.sh https://github.com/hamza72x/Hyprland/releases/download/v0.55.0-fedora44/hyprland-0.55.0-1.fc44.custom.x86_64.rpm
#
set -euo pipefail

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

echo "=== Installing Hyprland from GitHub Release ==="
echo "URL: $URL"
echo ""

echo "[1/2] Downloading..."
curl -fSL -o "$RPM_FILE" "$URL"

echo "[2/2] Installing..."
dnf install -y "$RPM_FILE"

echo ""
echo "=== Done ==="
Hyprland --version
echo ""
echo "Start Hyprland from a TTY with: Hyprland"
echo "Or select it from your display manager."
