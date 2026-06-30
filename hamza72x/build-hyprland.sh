#!/bin/bash
#
# build-hyprland.sh - Build Hyprland from source on Fedora 44 and produce an RPM.
#
# Usage:
#   ./build-hyprland.sh          # full build + RPM
#   ./build-hyprland.sh --deps   # install dependencies only
#   ./build-hyprland.sh --rpm    # package only (assumes build done)
#
# Output: ~/rpmbuild/RPMS/x86_64/hyprland-*.rpm
#
set -euo pipefail

HYPRLAND_VERSION="0.55.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$HOME/hypr-deps"
STAGING="$HOME/hyprland-rpm-staging"
JOBS="$(nproc)"

# Library versions to build from source
HYPRUTILS_TAG="v0.13.1"
HYPRLANG_TAG="v0.6.8"
HYPRGRAPHICS_TAG="v0.5.1"
HYPRCURSOR_TAG="v0.1.13"
HYPRWIRE_TAG="v0.3.1"
AQUAMARINE_TAG="v0.12.1"
HYPRWAYLAND_SCANNER_TAG="v0.4.6"
HYPRTOOLKIT_TAG="v0.5.4"
HYPRLAND_GUIUTILS_TAG="v0.2.1"
LUA_VERSION="5.5.0"

# --------------------------------------------------------------------------- #
#  Helpers
# --------------------------------------------------------------------------- #

info()  { echo -e "\033[1;34m==>\033[0m \033[1m$*\033[0m"; }
ok()    { echo -e "\033[1;32m  ✓\033[0m $*"; }
fail()  { echo -e "\033[1;31m  ✗\033[0m $*"; exit 1; }

need_root() {
    if [ "$EUID" -ne 0 ]; then
        fail "This step requires root. Run with sudo or as root."
    fi
}

clone_and_checkout() {
    local repo="$1" tag="$2" dir="$3"
    if [ -d "$dir" ]; then
        info "  $dir already exists, resetting to $tag"
        cd "$dir" && git fetch --tags 2>/dev/null || true
        git checkout "$tag" 2>/dev/null
    else
        git clone --depth=50 "https://github.com/hyprwm/$repo.git" "$dir"
        cd "$dir" && git checkout "$tag"
    fi
}

build_cmake_dep() {
    local name="$1" repo="$2" tag="$3" extra_args="${4:-}"
    info "Building $name ($tag)"
    local dir="$BUILD_DIR/$name"
    clone_and_checkout "$repo" "$tag" "$dir"
    cd "$dir"
    # shellcheck disable=SC2086
    cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr $extra_args
    cmake --build build -j"$JOBS"
    sudo cmake --install build
    ok "$name installed"
}

# --------------------------------------------------------------------------- #
#  Step 1: Install DNF build dependencies
# --------------------------------------------------------------------------- #

install_deps() {
    info "Installing build dependencies from DNF"
    sudo dnf install -y \
        cmake gcc-c++ git meson ninja-build pkg-config tar gzip curl \
        wayland-devel wayland-protocols-devel libxkbcommon-devel \
        cairo-devel pango-devel pixman-devel libdrm-devel \
        mesa-libgbm-devel mesa-libEGL-devel mesa-libGLES-devel \
        libinput-devel glib2-devel re2-devel muParser-devel lcms2-devel \
        libXcursor-devel libuuid-devel xcb-util-errors-devel libxcb-devel \
        xcb-util-renderutil-devel xcb-util-wm-devel xcb-util-devel \
        xcb-util-keysyms-devel glslang-devel spirv-tools-devel \
        vulkan-headers OpenEXR-devel libwebp-devel libjpeg-turbo-devel \
        libpng-devel file-devel hwdata-devel libseat-devel \
        libdisplay-info-devel librsvg2-devel tomlplusplus-devel \
        pugixml-devel libzip-devel readline-devel python3 libffi-devel \
        iniparser-devel abseil-cpp-devel \
        rpm-build \
        --skip-unavailable
    ok "DNF dependencies installed"
}

# --------------------------------------------------------------------------- #
#  Step 2: Build Hypr ecosystem libraries from source
# --------------------------------------------------------------------------- #

build_deps() {
    mkdir -p "$BUILD_DIR"

    build_cmake_dep "hyprwayland-scanner" "hyprwayland-scanner" "$HYPRWAYLAND_SCANNER_TAG"
    build_cmake_dep "hyprutils"           "hyprutils"           "$HYPRUTILS_TAG"
    build_cmake_dep "hyprlang"            "hyprlang"            "$HYPRLANG_TAG"
    build_cmake_dep "hyprgraphics"        "hyprgraphics"        "$HYPRGRAPHICS_TAG"
    build_cmake_dep "hyprcursor"          "hyprcursor"          "$HYPRCURSOR_TAG"
    build_cmake_dep "hyprwire"            "hyprwire"            "$HYPRWIRE_TAG"

    # aquamarine needs special handling: GCC 16 rejects zero-size arrays under -Wpedantic
    info "Building aquamarine ($AQUAMARINE_TAG)"
    local aq_dir="$BUILD_DIR/aquamarine"
    clone_and_checkout "aquamarine" "$AQUAMARINE_TAG" "$aq_dir"
    cd "$aq_dir"
    sed -i 's/-Wpedantic//' CMakeLists.txt
    rm -f protocols/wayland.cpp protocols/wayland.hpp \
          protocols/xdg-shell.cpp protocols/xdg-shell.hpp \
          protocols/linux-dmabuf-v1.cpp protocols/linux-dmabuf-v1.hpp
    cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
    cmake --build build -j"$JOBS"
    sudo cmake --install build
    ok "aquamarine installed"

    # hyprtoolkit needs same -Wpedantic fix and protocol regeneration
    info "Building hyprtoolkit ($HYPRTOOLKIT_TAG)"
    local ht_dir="$BUILD_DIR/hyprtoolkit"
    clone_and_checkout "hyprtoolkit" "$HYPRTOOLKIT_TAG" "$ht_dir"
    cd "$ht_dir"
    sed -i 's/-Wpedantic//' CMakeLists.txt
    rm -f protocols/*.cpp protocols/*.hpp 2>/dev/null || true
    cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
    cmake --build build -j"$JOBS"
    sudo cmake --install build
    ok "hyprtoolkit installed"

    # hyprland-guiutils
    build_cmake_dep "hyprland-guiutils" "hyprland-guiutils" "$HYPRLAND_GUIUTILS_TAG"

    # Lua 5.5
    info "Building Lua $LUA_VERSION"
    cd "$BUILD_DIR"
    if [ ! -d "lua-${LUA_VERSION}" ]; then
        curl -L -o "lua-${LUA_VERSION}.tar.gz" "https://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz"
        tar xzf "lua-${LUA_VERSION}.tar.gz"
    fi
    cd "lua-${LUA_VERSION}"
    make linux -j"$JOBS" MYCFLAGS="-fPIC"
    sudo make install INSTALL_TOP=/usr
    # Fedora uses lib64
    sudo cp -f /usr/lib/liblua.a /usr/lib64/liblua.a 2>/dev/null || true

    # Create pkg-config files for Lua 5.5
    cat > /tmp/lua55.pc << 'LUAPC'
prefix=/usr
exec_prefix=${prefix}
libdir=${exec_prefix}/lib64
includedir=${prefix}/include

Name: Lua
Description: An Extensible Extension Language
Version: 5.5.0
Requires:
Libs: -L${libdir} -llua -lm
Cflags: -I${includedir}
LUAPC
    sudo cp /tmp/lua55.pc /usr/lib64/pkgconfig/lua55.pc
    sudo cp /tmp/lua55.pc /usr/lib64/pkgconfig/lua5.5.pc
    sudo cp /tmp/lua55.pc /usr/lib64/pkgconfig/lua-5.5.pc
    sudo cp /tmp/lua55.pc /usr/lib64/pkgconfig/lua.pc
    ok "Lua $LUA_VERSION installed"

    sudo ldconfig
}

# --------------------------------------------------------------------------- #
#  Step 3: Build Hyprland
# --------------------------------------------------------------------------- #

build_hyprland() {
    info "Building Hyprland $HYPRLAND_VERSION"
    cd "$REPO_ROOT"
    git submodule update --init --recursive

    rm -rf build
    cmake -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DNO_SYSTEMD=OFF

    cmake --build build -j"$JOBS"
    ok "Hyprland built successfully"

    # Quick verification
    ./build/Hyprland --version
}

# --------------------------------------------------------------------------- #
#  Step 4: Package as RPM
# --------------------------------------------------------------------------- #

package_rpm() {
    info "Packaging Hyprland as RPM"

    rm -rf "$STAGING"
    mkdir -p "$STAGING"

    # Fix ownership of build dirs (previous sudo cmake --install leaves root-owned files)
    sudo chown -R "$(whoami)" "$BUILD_DIR" 2>/dev/null || true

    # Install Hyprland into staging
    cd "$REPO_ROOT"
    DESTDIR="$STAGING" cmake --install build

    # Install all custom-built libraries into staging
    for dep in hyprutils hyprlang hyprgraphics hyprcursor hyprwire aquamarine hyprwayland-scanner hyprtoolkit hyprland-guiutils; do
        if [ -d "$BUILD_DIR/$dep/build" ]; then
            cd "$BUILD_DIR/$dep"
            DESTDIR="$STAGING" cmake --install build
        fi
    done

    # Install Lua 5.5
    if [ -d "$BUILD_DIR/lua-${LUA_VERSION}" ]; then
        cd "$BUILD_DIR/lua-${LUA_VERSION}"
        make install INSTALL_TOP="$STAGING/usr"
    fi

    # Copy lua pkgconfig
    mkdir -p "$STAGING/usr/lib64/pkgconfig"
    if [ -f /usr/lib64/pkgconfig/lua55.pc ]; then
        cp /usr/lib64/pkgconfig/lua55.pc "$STAGING/usr/lib64/pkgconfig/"
        cp /usr/lib64/pkgconfig/lua5.5.pc "$STAGING/usr/lib64/pkgconfig/"
        cp /usr/lib64/pkgconfig/lua.pc "$STAGING/usr/lib64/pkgconfig/"
    fi

    # Set up rpmbuild tree
    local rpmbuild_dir="$HOME/rpmbuild"
    mkdir -p "$rpmbuild_dir"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

    # Create tarball from staging
    cd "$STAGING"
    tar czf "$rpmbuild_dir/SOURCES/hyprland-${HYPRLAND_VERSION}.tar.gz" .

    # Write RPM spec
    cat > "$rpmbuild_dir/SPECS/hyprland.spec" << SPEC
%global debug_package %{nil}

Name:           hyprland
Version:        ${HYPRLAND_VERSION}
Release:        1.fc44.custom
Summary:        A dynamic tiling Wayland compositor
License:        BSD-3-Clause
URL:            https://hyprland.org

Source0:        hyprland-%{version}.tar.gz

AutoReqProv:    no

%description
Hyprland is a dynamic tiling Wayland compositor based on wlroots that doesn't
sacrifice on its looks. It supports multiple layouts, fancy effects, has a
very flexible IPC model allowing for a lot of customization, and more.

This is a custom build for Fedora 44 with bundled Hypr ecosystem libraries
(hyprutils, hyprlang, hyprgraphics, hyprcursor, aquamarine, hyprwire) and
Lua 5.5.

%prep
%setup -c -T
tar xzf %{SOURCE0}

%install
cp -a usr %{buildroot}/usr

%post
/sbin/ldconfig

%postun
/sbin/ldconfig

%files
/usr/bin/*
/usr/lib64/lib*.so*
/usr/lib64/pkgconfig/*
/usr/lib64/cmake/*
%dir /usr/lib/lua
/usr/lib/lua/*
/usr/lib/liblua.a
/usr/share/hypr/
/usr/share/wayland-sessions/*
/usr/share/xdg-desktop-portal/*
/usr/share/man/man1/*
/usr/share/bash-completion/completions/*
/usr/share/fish/vendor_completions.d/*
/usr/share/zsh/site-functions/*
/usr/share/pkgconfig/*
%dir /usr/share/lua
/usr/share/lua/*
/usr/include/*
/usr/man/man1/*
SPEC

    # Build the RPM
    rpmbuild -bb "$rpmbuild_dir/SPECS/hyprland.spec"

    local rpm_path
    rpm_path="$(find "$rpmbuild_dir/RPMS" -name "hyprland-*.rpm" | head -1)"

    if [ -n "$rpm_path" ]; then
        cp "$rpm_path" "$SCRIPT_DIR/"
        ok "RPM created: $SCRIPT_DIR/$(basename "$rpm_path")"
        echo ""
        info "Install on target machine with:"
        echo "  sudo dnf install ./$(basename "$rpm_path")"
    else
        fail "RPM build failed"
    fi
}

# --------------------------------------------------------------------------- #
#  Main
# --------------------------------------------------------------------------- #

main() {
    local mode="${1:-all}"

    echo ""
    echo "============================================="
    echo " Hyprland $HYPRLAND_VERSION Builder for Fedora 44"
    echo "============================================="
    echo ""

    case "$mode" in
        --deps)
            install_deps
            build_deps
            ;;
        --rpm)
            package_rpm
            ;;
        --build)
            build_hyprland
            ;;
        all|"")
            install_deps
            build_deps
            build_hyprland
            package_rpm
            ;;
        *)
            echo "Usage: $0 [--deps|--build|--rpm]"
            echo ""
            echo "  (no args)  Full build: deps + build + RPM"
            echo "  --deps     Install dependencies only"
            echo "  --build    Build Hyprland only (deps must be installed)"
            echo "  --rpm      Package RPM only (build must be done)"
            exit 1
            ;;
    esac

    echo ""
    ok "Done!"
}

main "$@"
