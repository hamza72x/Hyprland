#!/bin/bash
#
# install_release_file.sh - Install Hyprland from a GitHub release URL.
#
# Downloads the RPM and installs all required runtime dependencies.
# Meant for barebone Fedora installations.
#
# Usage:
#   sudo ./install_release_file.sh <rpm-url>
#   sudo ./install_release_file.sh https://github.com/hamza72x/Hyprland/releases/download/v0.55.0-fedora44/hyprland-0.55.0-1.fc44.custom.x86_64.rpm
#
set -euo pipefail

# --------------------------------------------------------------------------- #
#  Runtime dependencies needed on a barebone Fedora
# --------------------------------------------------------------------------- #

RUNTIME_DEPS=(
    # Wayland / display
    wayland
    libwayland-client
    libwayland-server
    libwayland-cursor
    libxkbcommon
    mesa-libEGL
    mesa-libGLES
    mesa-libgbm
    libdrm
    libseat
    libdisplay-info

    # Rendering / graphics
    cairo
    pango
    pixman
    glslang
    vulkan-loader
    libXcursor

    # Input
    libinput

    # XWayland
    xorg-x11-server-Xwayland

    # System libraries
    glib2
    re2
    muParser
    lcms2
    libuuid
    libffi
    hwdata
    file-libs
    polkit

    # XCB (for XWayland support)
    libxcb
    xcb-util-errors
    xcb-util-renderutil
    xcb-util-wm

    # Image / cursor / theme libraries
    librsvg2
    tomlplusplus
    pugixml
    libzip
    libwebp
    libjpeg-turbo
    libpng
)

SDDM_DEPS=(
    sddm
)

# --------------------------------------------------------------------------- #
#  Helpers
# --------------------------------------------------------------------------- #

info()  { echo -e "\033[1;34m==>\033[0m \033[1m$*\033[0m"; }
ok()    { echo -e "\033[1;32m  ✓\033[0m $*"; }

ask_yes_no() {
    local prompt="$1"
    local answer
    echo -n -e "\033[1;33m  ?\033[0m $prompt [Y/n] "
    read -r answer
    case "$answer" in
        [nN]*) return 1 ;;
        *) return 0 ;;
    esac
}

# --------------------------------------------------------------------------- #
#  Main
# --------------------------------------------------------------------------- #

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

echo ""
echo "============================================="
echo " Hyprland Installer for Fedora 44"
echo "============================================="
echo ""
echo "Source: $URL"
echo ""

# --- Step 1: Download ---
info "Downloading Hyprland RPM..."
curl -fSL -o "$RPM_FILE" "$URL"
ok "Downloaded $(basename "$RPM_FILE")"
echo ""

# --- Step 2: Runtime dependencies ---
info "The following runtime packages are required:"
echo ""
printf '    %s\n' "${RUNTIME_DEPS[@]}"
echo ""

if ask_yes_no "Install runtime dependencies?"; then
    echo ""
    dnf install -y --skip-unavailable "${RUNTIME_DEPS[@]}"
    ok "Runtime dependencies installed"
else
    echo "  Skipped. (RPM install may fail if deps are missing)"
fi

echo ""

# --- Step 3: Display manager (SDDM) ---
info "SDDM is a display manager that provides a graphical login screen."
echo "    Without it, you'll need to start Hyprland manually from a TTY."
echo ""

if ask_yes_no "Install SDDM (display manager)?"; then
    echo ""
    dnf install -y "${SDDM_DEPS[@]}"
    systemctl enable sddm 2>/dev/null || true
    systemctl set-default graphical.target 2>/dev/null || true
    ok "SDDM installed, enabled, and graphical.target set as default"
else
    echo "  Skipped."
    echo ""
    info "Setting graphical.target as default boot target..."
    systemctl set-default graphical.target 2>/dev/null || true
    ok "graphical.target set (Hyprland will start on login via TTY session)"
fi

echo ""

# --- Step 4: Install Hyprland RPM ---
info "Installing Hyprland..."
echo ""
dnf install -y "$RPM_FILE"

echo ""
echo "============================================="
ok "Hyprland installed successfully!"
echo "============================================="
echo ""
Hyprland --version
echo ""
echo "To start:"
echo "  - If SDDM installed: reboot and select Hyprland from the session menu"
echo "  - From TTY: log in and run 'Hyprland'"
echo ""
