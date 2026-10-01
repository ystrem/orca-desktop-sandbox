#!/bin/bash
# Install Orca Desktop Firejail sandbox & desktop launcher
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILE_SRC="${SCRIPT_DIR}/orca-desktop.local"
NETFILTER_SRC="${SCRIPT_DIR}/orca-desktop.net"
WRAPPER_SRC="${SCRIPT_DIR}/run-orca-desktop.sh"
PROFILE_DIR="${ORCA_PROFILE_DIR:-${HOME}/.config/firejail}"
BIN_DIR="${ORCA_BIN_DIR:-${HOME}/.local/bin}"
DESKTOP_DIR="${ORCA_DESKTOP_DIR:-${HOME}/.local/share/applications}"
DESKTOP_FILE="${DESKTOP_DIR}/orca-desktop-sandbox.desktop"

show_help() {
    echo "Usage: install.sh [OPTIONS]"
    echo ""
    echo "Install or uninstall the Orca Desktop Firejail sandbox."
    echo ""
    echo "Options:"
    echo "  --uninstall    Remove installed Firejail profiles, wrapper script, and desktop launcher"
    echo "  -h, --help     Show this help message and exit"
    echo ""
    exit 0
}

do_uninstall() {
    echo "==> Uninstalling Orca Desktop Sandbox..."
    rm -f "${PROFILE_DIR}/orca-desktop.local"
    rm -f "${PROFILE_DIR}/orca-desktop.net"
    rm -f "${BIN_DIR}/orca-desktop-sandbox"
    rm -f "${DESKTOP_FILE}"
    echo "  ✓ Removed ${PROFILE_DIR}/orca-desktop.local"
    echo "  ✓ Removed ${PROFILE_DIR}/orca-desktop.net"
    echo "  ✓ Removed ${BIN_DIR}/orca-desktop-sandbox"
    echo "  ✓ Removed ${DESKTOP_FILE}"
    echo "==> Uninstall complete!"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --uninstall)
            do_uninstall
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run 'install.sh --help' for usage."
            exit 1
            ;;
    esac
done

echo "==> Checking Firejail..."
if ! command -v firejail &>/dev/null; then
    echo "Firejail is not installed. Install it first:"
    echo "  sudo pacman -S firejail    # Arch/CachyOS"
    echo "  sudo apt install firejail  # Debian/Ubuntu"
    echo "  sudo dnf install firejail  # Fedora"
    exit 1
fi

echo "==> Copying Firejail profile..."
mkdir -p "${PROFILE_DIR}"
cp "${PROFILE_SRC}" "${PROFILE_DIR}/orca-desktop.local"
cp "${NETFILTER_SRC}" "${PROFILE_DIR}/orca-desktop.net"
echo "  → ${PROFILE_DIR}/orca-desktop.local"
echo "  → ${PROFILE_DIR}/orca-desktop.net"

echo ""
echo "==> ⚠️  Edit netfilter rules before first run!"
echo "    Set your remote orca serve IP(s) in: ${PROFILE_DIR}/orca-desktop.net"
echo "    Uncomment/add lines with Tailscale (100.x) or LAN addresses"
echo ""

echo "==> Installing wrapper script..."
mkdir -p "${BIN_DIR}"
cp "${WRAPPER_SRC}" "${BIN_DIR}/orca-desktop-sandbox"
chmod +x "${BIN_DIR}/orca-desktop-sandbox"
echo "  → ${BIN_DIR}/orca-desktop-sandbox"

echo "==> Installing Desktop Menu entry..."
mkdir -p "${DESKTOP_DIR}"
cat <<EOF > "${DESKTOP_FILE}"
[Desktop Entry]
Name=Orca Desktop (Sandboxed)
Comment=Sandboxed Electron thin client for Orca ADE (remote orca serve)
Exec=${BIN_DIR}/orca-desktop-sandbox %U
Icon=orca
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=Orca
EOF
chmod +x "${DESKTOP_FILE}"
echo "  → ${DESKTOP_FILE}"

if [[ ":$PATH:" != *":${BIN_DIR}:"* ]]; then
    echo ""
    echo "⚠️  ${BIN_DIR} is not in your PATH."
    echo "   Add this to your ~/.bashrc or ~/.zshrc:"
    echo "   export PATH=\"\${PATH}:${BIN_DIR}\""
fi

FOUND_APPIMAGE=""
if [ -n "${ORCA_APPIMAGE:-}" ] && [ -e "${ORCA_APPIMAGE}" ]; then
    FOUND_APPIMAGE="${ORCA_APPIMAGE}"
else
    SEARCH_DIRS=(
        "${BIN_DIR}"
        "${HOME}/Applications"
        "/opt/orca"
    )
    for dir in "${SEARCH_DIRS[@]}"; do
        if [ -d "${dir}" ]; then
            FOUND=$(find "${dir}" -maxdepth 2 \(
                -name "orca-linux.AppImage" -o
                -name "Orca-*.AppImage" -o
                -name "orca-*.AppImage"
            \) -type f 2>/dev/null | sort -V | tail -1)
            if [ -n "${FOUND}" ]; then
                FOUND_APPIMAGE="${FOUND}"
                break
            fi
            for candidate in orca-ide Orca orca; do
                if [ -x "${dir}/${candidate}" ]; then
                    FOUND_APPIMAGE="${dir}/${candidate}"
                    break 2
                fi
            done
        fi
    done
fi

if [ -n "${FOUND_APPIMAGE}" ]; then
    echo "  ✓ Found local executable: ${FOUND_APPIMAGE}"
else
    echo "  ⚠️  No local Orca AppImage found."
    echo "  ==> Downloading official AppImage from stablyai/orca..."
    if "${BIN_DIR}/orca-desktop-sandbox" --download; then
        echo "  ✓ Official AppImage downloaded."
    else
        echo "  ⚠️  Automatic download failed."
        echo "  Get it from: https://www.onorca.dev/download"
        echo "  or: https://github.com/stablyai/orca/releases"
        echo "  Place AppImage in ~/.local/bin or set ORCA_APPIMAGE."
    fi
fi

echo ""
echo "==> Done!"
echo "Before first run, edit your network rules:"
echo "  vim ${PROFILE_DIR}/orca-desktop.net"
echo ""
echo "Then launch:  orca-desktop-sandbox"
echo "Update app:   orca-desktop-sandbox --update"
echo ""
