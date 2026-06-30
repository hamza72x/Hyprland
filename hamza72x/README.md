# hamza72x/Hyprland Fork - Fedora 44 Build

Custom build tooling for Hyprland on Fedora 44 (x86_64).

Fedora 44 ships outdated Hypr ecosystem libraries and lacks Lua 5.5, so we build everything from source.

## Quick Install (prebuilt)

```bash
# From GitHub release (recommended):
sudo ./install_release_file.sh https://github.com/hamza72x/Hyprland/releases/download/v0.55.0-fedora44/hyprland-0.55.0-1.fc44.custom.x86_64.rpm

# Or install directly with dnf:
curl -fSLO https://github.com/hamza72x/Hyprland/releases/download/v0.55.0-fedora44/hyprland-0.55.0-1.fc44.custom.x86_64.rpm
sudo dnf install ./hyprland-0.55.0-1.fc44.custom.x86_64.rpm
```

## Build from Source + RPM

```bash
cd hamza72x/
chmod +x build-hyprland.sh
./build-hyprland.sh
```

This will:
1. Install all build deps from DNF
2. Build 7 Hypr libraries + Lua 5.5 from source
3. Build Hyprland
4. Produce `hyprland-0.55.0-1.fc44.custom.x86_64.rpm`

Install the RPM on any Fedora 44 machine:
```bash
sudo dnf install ./hyprland-0.55.0-1.fc44.custom.x86_64.rpm
```

## Files

| File | Description |
|------|-------------|
| `build-hyprland.sh` | All-in-one build script (deps + build + RPM) |
| `install_all.sh` | Install from a locally built RPM |
| `install_release_file.sh` | Install from a GitHub release URL |

## Install from GitHub Release (easiest)

```bash
sudo ./install_release_file.sh https://github.com/hamza72x/Hyprland/releases/download/v0.55.0-fedora44/hyprland-0.55.0-1.fc44.custom.x86_64.rpm
```

Or just download and install directly:
```bash
curl -fSLO https://github.com/hamza72x/Hyprland/releases/download/v0.55.0-fedora44/hyprland-0.55.0-1.fc44.custom.x86_64.rpm
sudo dnf install ./hyprland-0.55.0-1.fc44.custom.x86_64.rpm
```

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
