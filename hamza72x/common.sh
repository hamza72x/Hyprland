#!/bin/bash
#
# common.sh - Shared functions and package lists for Hyprland install scripts.
#
# Sourced by install.sh, install_all.sh, and install_release_file.sh.
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

# Read from /dev/tty so prompts work even when script is piped (curl | bash).
# Falls back to auto-yes if no TTY is available (non-interactive).
ask_yes_no() {
    local prompt="$1"
    local answer=""
    if (true < /dev/tty) 2>/dev/null; then
        echo -n -e "\033[1;33m  ?\033[0m $prompt [Y/n] " > /dev/tty
        read -r answer < /dev/tty || answer="y"
    else
        echo -e "\033[1;33m  ?\033[0m $prompt [Y/n] (auto: yes)"
        answer="y"
    fi
    case "$answer" in
        [nN]*) return 1 ;;
        *) return 0 ;;
    esac
}

# Copy a config directory to a target, only if target file doesn't exist yet.
# On re-runs (upsert), existing files are left untouched unless user says yes.
# Args: $1=source_dir $2=target_dir $3=check_file (relative) $4=label
_upsert_config() {
    local src="$1" dst="$2" check="$3" label="$4"
    [ -d "$src" ] || return 0

    if [ -e "$dst/$check" ]; then
        ok "$label config already present at $dst"
    else
        mkdir -p "$dst"
        cp -r "$src/"* "$dst/"
        ok "$label config installed to $dst"
    fi
}

# --------------------------------------------------------------------------- #
#  install_dependencies - Idempotent: dnf skips already-installed packages
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
        dnf install -y --skip-unavailable "${SDDM_DEPS[@]}"
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
#  install_configs - Upsert: installs only if not already present, or asks
# --------------------------------------------------------------------------- #

install_configs() {
    local config_src="$1"   # path to our configs/ directory
    local target_home="$2"  # target user's home directory

    if [ ! -d "$config_src" ]; then
        warn "No configs directory found at $config_src, skipping."
        return
    fi

    local conf_dir="$target_home/.config"

    info "Step 4: Default configuration files"
    echo ""

    # Hyprland config (v0.55+ uses hyprland.lua)
    local hypr_dir="$conf_dir/hypr"
    if [ -f "$hypr_dir/hyprland.lua" ] || [ -f "$hypr_dir/hyprland.conf" ]; then
        warn "Existing Hyprland config found at $hypr_dir/"
        if ask_yes_no "Overwrite with default config?"; then
            mkdir -p "$hypr_dir"
            cp -r "$config_src/hypr/"* "$hypr_dir/"
            ok "Hyprland config updated"
        else
            ok "Hyprland config left as-is"
        fi
    else
        mkdir -p "$hypr_dir"
        cp -r "$config_src/hypr/"* "$hypr_dir/"
        ok "Hyprland config installed to $hypr_dir"
    fi

    # Waybar
    _upsert_config "$config_src/waybar" "$conf_dir/waybar" "config.jsonc" "Waybar"

    # Alacritty
    _upsert_config "$config_src/alacritty" "$conf_dir/alacritty" "alacritty.toml" "Alacritty"

    echo ""
}

# --------------------------------------------------------------------------- #
#  fix_config_ownership - Ensure configs are owned by the real user, not root
# --------------------------------------------------------------------------- #

fix_config_ownership() {
    local user="$1"
    local home="$2"

    if [ -n "$user" ] && [ "$user" != "root" ] && [ -d "$home/.config" ]; then
        chown -R "$user:$user" "$home/.config/hypr" 2>/dev/null || true
        chown -R "$user:$user" "$home/.config/waybar" 2>/dev/null || true
        chown -R "$user:$user" "$home/.config/alacritty" 2>/dev/null || true
    fi
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
    if command -v Hyprland &>/dev/null; then
        ok "Hyprland binary found at $(command -v Hyprland)"
    else
        warn "Hyprland binary not in PATH yet (may need re-login)"
    fi
    echo ""
    echo "To start:"
    echo "  - If SDDM installed: reboot and select Hyprland from the session menu"
    echo "  - From TTY: log in and run 'Hyprland'"
    echo ""
}
