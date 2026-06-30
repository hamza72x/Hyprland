#!/bin/bash
#
# install_all.sh - Install Hyprland from a local build artifact.
#
# Run this after build-hyprland.sh completes. It installs the RPM produced
# by the build script onto the current machine.
#
# Usage:
#   sudo ./install_all.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

echo "=== Installing Hyprland from local RPM ==="
echo "RPM: $RPM_FILE"
echo ""

dnf install -y "$RPM_FILE"

echo ""
echo "=== Done ==="
Hyprland --version
echo ""
echo "Start Hyprland from a TTY with: Hyprland"
echo "Or select it from your display manager."
