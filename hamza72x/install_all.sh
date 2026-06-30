#!/bin/bash
#
# install_all.sh - Install Hyprland from a local build artifact.
#
# Installs runtime deps, desktop packages, SDDM, configs, then the RPM.
# Idempotent: safe to run multiple times.
#
# Usage:
#   sudo ./install_all.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo ./install_all.sh"
    exit 1
fi

# Find the RPM in the same directory
RPM_FILE="$(find "$SCRIPT_DIR" -maxdepth 1 -name 'hyprland-*.rpm' | sort -V | tail -1)"

if [ -z "$RPM_FILE" ]; then
    echo "Error: No hyprland-*.rpm found in $SCRIPT_DIR"
    echo ""
    echo "Either:"
    echo "  1. Run ./build-hyprland.sh first to produce the RPM"
    echo "  2. Or use ./install_release_file.sh <url> to install from a GitHub release"
    exit 1
fi

echo "RPM: $(basename "$RPM_FILE")"

install_dependencies

info "Installing Hyprland RPM..."
echo ""
dnf install -y "$RPM_FILE"

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(eval echo "~$REAL_USER")"

if [ -d "$SCRIPT_DIR/configs" ]; then
    install_configs "$SCRIPT_DIR/configs" "$REAL_HOME"
    fix_config_ownership "$REAL_USER" "$REAL_HOME"
fi

post_install
