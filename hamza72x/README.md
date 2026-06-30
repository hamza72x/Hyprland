# hamza72x/Hyprland Fork - Fedora 44 Build

Custom build of Hyprland v0.55 for Fedora 44 (x86_64) with all dependencies bundled.

Fedora 44 ships outdated Hypr ecosystem libraries and lacks Lua 5.5, so we build everything from source.

## One-liner Install

```bash
curl -fsSL https://raw.githubusercontent.com/hamza72x/Hyprland/main/hamza72x/install.sh | sudo bash
```

This automatically:
- Finds the latest RPM from GitHub releases
- Installs runtime libraries, desktop packages (waybar, rofi, alacritty, dunst, pipewire)
- Optionally installs SDDM and sets graphical boot target
- Installs the Hyprland RPM
- Sets up default configs (Lua config for v0.55+)

## Files

| File | Description |
|------|-------------|
| `install.sh` | One-liner installer (curl \| sudo bash) |
| `install_all.sh` | Install from a locally built RPM |
| `install_release_file.sh` | Install from a GitHub release URL |
| `build-hyprland.sh` | Full source build (deps + build + RPM) |
| `common.sh` | Shared package lists and install logic |
| `configs/` | Default configs for hypr, waybar, alacritty |

## Default Config

Hyprland v0.55 uses **Lua configuration** (`hyprland.lua`). The installer places a
ready-to-use config at `~/.config/hypr/hyprland.lua` with:

- **SUPER+T** — alacritty, **SUPER+B** — firefox, **SUPER+A** — rofi, **SUPER+E** — nautilus
- **SUPER+Q** — close window, **SUPER+W** — toggle float, **SUPER+F** — fullscreen
- **SUPER+1-0** — workspaces, **SUPER+SHIFT+1-0** — move to workspace
- **Print** — screenshot, **SUPER+SHIFT+P** — region screenshot
- Media keys, brightness keys, volume keys all mapped
- Waybar auto-starts with clock, workspaces, audio, network, battery
- Catppuccin Mocha color scheme for alacritty

## What Gets Built from Source

| Library | Version | Why |
|---------|---------|-----|
| hyprutils | 0.13.1 | Fedora has 0.7.1 |
| hyprlang | 0.6.8 | Fedora has 0.6.4 |
| hyprgraphics | 0.5.1 | Fedora has 0.1.5 |
| hyprcursor | 0.1.13 | Needs newer hyprutils |
| aquamarine | 0.12.1 | Not in repos |
| hyprwire | 0.3.1 | Not in repos |
| hyprwayland-scanner | 0.4.6 | GCC 16 compat |
| Lua | 5.5.0 | Not in repos |
