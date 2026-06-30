#!/bin/bash
#
# common.sh - Shared functions and package lists for Hyprland install scripts.
#
# Sourced by install_all.sh and install_release_file.sh
# Do not run directly.
#

# --------------------------------------------------------------------------- #
#  Runtime dependencies (required for Hyprland to launch)
# --------------------------------------------------------------------------- #

RUNTIME_DEPS=(
    # Wayland / display
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

# --------------------------------------------------------------------------- #
#  Desktop environment packages (for a usable Hyprland desktop)
# --------------------------------------------------------------------------- #

DESKTOP_DEPS=(
    # Bar / launcher / notifications
    waybar
    rofi-wayland
    dunst

    # Terminal
    alacritty
    foot

    # Screenshot / screen tools
    grim
    slurp
    wl-clipboard

    # Audio
    pipewire
    pipewire-pulseaudio
    wireplumber
    pavucontrol

    # Networking / Bluetooth
    NetworkManager
    blueman

    # Brightness / media
    brightnessctl
    playerctl

    # Portals (for file pickers, screen sharing)
    xdg-desktop-portal-gtk
    xdg-desktop-portal-hyprland

    # Polkit (auth prompts)
    polkit-gnome

    # Theming / appearance
    nwg-look

    # File manager
    nautilus

    # Fonts
    google-noto-emoji-fonts
    google-noto-sans-fonts

    # Misc
    jq
    imagemagick
    libnotify
    xdg-user-dirs
)

# --------------------------------------------------------------------------- #
#  Display manager
# --------------------------------------------------------------------------- #

SDDM_DEPS=(
    sddm
)

# --------------------------------------------------------------------------- #
#  Helpers
# --------------------------------------------------------------------------- #

info()  { echo -e "\033[1;34m==>\033[0m \033[1m$*\033[0m"; }
ok()    { echo -e "\033[1;32m  ✓\033[0m $*"; }
warn()  { echo -e "\033[1;33m  !\033[0m $*"; }

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
#  install_dependencies - Run by both install scripts
# --------------------------------------------------------------------------- #

install_dependencies() {
    echo ""
    echo "============================================="
    echo " Hyprland Installer for Fedora 44"
    echo "============================================="
    echo ""

    # --- Runtime dependencies ---
    info "Step 1: Runtime libraries (required for Hyprland to launch)"
    echo ""
    printf '    %s\n' "${RUNTIME_DEPS[@]}"
    echo ""

    if ask_yes_no "Install runtime dependencies?"; then
        echo ""
        dnf install -y --skip-unavailable "${RUNTIME_DEPS[@]}"
        ok "Runtime dependencies installed"
    else
        warn "Skipped. Hyprland may not start without these."
    fi

    echo ""

    # --- Desktop packages ---
    info "Step 2: Desktop packages (waybar, rofi, alacritty, dunst, pipewire, etc.)"
    echo ""
    printf '    %s\n' "${DESKTOP_DEPS[@]}"
    echo ""

    if ask_yes_no "Install desktop packages?"; then
        echo ""
        dnf install -y --skip-unavailable "${DESKTOP_DEPS[@]}"
        ok "Desktop packages installed"
    else
        warn "Skipped. You may not have a bar, launcher, or terminal."
    fi

    echo ""

    # --- Display manager (SDDM) ---
    info "Step 3: SDDM (display manager for graphical login)"
    echo "    Without it, you'll need to start Hyprland manually from a TTY."
    echo ""

    if ask_yes_no "Install SDDM (display manager)?"; then
        echo ""
        dnf install -y "${SDDM_DEPS[@]}"
        systemctl enable sddm 2>/dev/null || true
        systemctl set-default graphical.target 2>/dev/null || true
        ok "SDDM installed, enabled, and graphical.target set as default"
    else
        echo ""
        info "Setting graphical.target as default boot target..."
        systemctl set-default graphical.target 2>/dev/null || true
        ok "graphical.target set"
    fi

    echo ""
}

# --------------------------------------------------------------------------- #
#  install_configs - Copy default configs if user doesn't have them
# --------------------------------------------------------------------------- #

install_configs() {
    local config_src="$1"  # path to our configs/ directory

    if [ ! -d "$config_src" ]; then
        warn "No configs directory found at $config_src, skipping config install."
        return
    fi

    info "Step 4: Default Hyprland configuration"
    echo "    Installs config files only if you don't already have them."
    echo ""

    local hypr_conf_dir="$HOME/.config/hypr"

    if [ -f "$hypr_conf_dir/hyprland.conf" ]; then
        warn "Existing config found at $hypr_conf_dir/hyprland.conf"
        if ask_yes_no "Overwrite with default config?"; then
            cp -r "$config_src/hypr/"* "$hypr_conf_dir/"
            ok "Config files updated"
        else
            echo "  Skipped."
        fi
    else
        echo "    No existing Hyprland config found. Installing defaults..."
        mkdir -p "$hypr_conf_dir"
        cp -r "$config_src/hypr/"* "$hypr_conf_dir/"
        ok "Default config installed to $hypr_conf_dir"
    fi

    # Waybar config
    local waybar_dir="$HOME/.config/waybar"
    if [ -d "$config_src/waybar" ] && [ ! -f "$waybar_dir/config.jsonc" ]; then
        mkdir -p "$waybar_dir"
        cp -r "$config_src/waybar/"* "$waybar_dir/"
        ok "Default waybar config installed"
    fi

    # Alacritty config
    local alacritty_dir="$HOME/.config/alacritty"
    if [ -d "$config_src/alacritty" ] && [ ! -f "$alacritty_dir/alacritty.toml" ]; then
        mkdir -p "$alacritty_dir"
        cp -r "$config_src/alacritty/"* "$alacritty_dir/"
        ok "Default alacritty config installed"
    fi

    echo ""
}

# --------------------------------------------------------------------------- #
#  post_install - Final verification and instructions
# --------------------------------------------------------------------------- #

post_install() {
    echo ""
    echo "============================================="
    ok "Hyprland installed successfully!"
    echo "============================================="
    echo ""
    Hyprland --version 2>/dev/null || warn "Hyprland binary not in PATH yet (may need re-login)"
    echo ""
    echo "To start:"
    echo "  - If SDDM installed: reboot and select Hyprland from the session menu"
    echo "  - From TTY: log in and run 'Hyprland'"
    echo ""
}
