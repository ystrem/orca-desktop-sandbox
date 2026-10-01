#!/bin/bash
# Orca Desktop — Firejail sandboxed launcher (thin client to remote orca serve)
# Auto-detects local AppImages / unpacked binaries

set -euo pipefail

PROFILE_DIR="${ORCA_PROFILE_DIR:-${HOME}/.config/firejail}"
PROFILE="${PROFILE_DIR}/orca-desktop.local"
DOWNLOAD_DIR="${ORCA_BIN_DIR:-${HOME}/.local/bin}"

show_help() {
    echo "Usage: orca-desktop-sandbox [OPTIONS] [ELECTRON_ARGS...]"
    echo ""
    echo "Launch the Orca Desktop AppImage inside a Firejail sandbox."
    echo "Intended for use as a thin client to remote 'orca serve' hosts."
    echo ""
    echo "Environment variables:"
    echo "  ORCA_APPIMAGE   Path to custom Orca AppImage or executable"
    echo ""
    echo "Options:"
    echo "  -h, --help             Show this help message and exit"
    echo ""
    exit 0
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
fi

# Locate local AppImage or unpacked binary
APPIMAGE="${APPIMAGE:-}"

if [ -z "${APPIMAGE}" ]; then
    if [ -n "${ORCA_APPIMAGE:-}" ] && [ -e "${ORCA_APPIMAGE}" ]; then
        APPIMAGE="${ORCA_APPIMAGE}"
    else
        SEARCH_DIRS=(
            "${HOME}/.local/bin"
            "${HOME}/Applications"
            "/opt/orca"
            "/usr/local/bin"
            "."
        )

        for dir in "${SEARCH_DIRS[@]}"; do
            if [ -d "${dir}" ]; then
                # Prefer official naming
                FOUND=$(find "${dir}" -maxdepth 2 \(
                    -name "orca-linux.AppImage" -o
                    -name "Orca-*.AppImage" -o
                    -name "orca-*.AppImage"
                \) -type f 2>/dev/null | sort -V | tail -1)
                if [ -n "${FOUND}" ]; then
                    APPIMAGE="${FOUND}"
                    break
                fi
                # Unpacked / binary names
                for candidate in orca-ide Orca orca; do
                    if [ -x "${dir}/${candidate}" ]; then
                        APPIMAGE="${dir}/${candidate}"
                        break 2
                    fi
                done
                if [ -x "${dir}/linux-unpacked/orca" ]; then
                    APPIMAGE="${dir}/linux-unpacked/orca"
                    break
                fi
            fi
        done
    fi
fi

if [ -z "${APPIMAGE}" ]; then
    echo "Error: No local Orca AppImage or executable found."
    echo ""
    echo "Download from: https://www.onorca.dev/download"
    echo "  or: https://github.com/stablyai/orca/releases"
    echo ""
    echo "Then either:"
    echo "  - place the AppImage in ~/.local/bin or ~/Applications"
    echo "  - or set ORCA_APPIMAGE=/path/to/orca-linux.AppImage"
    exit 1
fi

if [ ! -f "${PROFILE}" ]; then
    echo "Warning: Firejail profile not found at ${PROFILE}"
    echo "Run install.sh or copy orca-desktop.local to ${PROFILE}"
    echo "Falling back to a minimal firejail sandbox..."
    exec firejail --private-tmp --noroot --caps.drop=all \
        --read-only="${HOME}" \
        --read-write="${HOME}/.orca" \
        --blacklist="${HOME}/.ssh" \
        --blacklist="${HOME}/.gnupg" \
        --blacklist="/var/run/docker.sock" \
        --blacklist="/run/docker.sock" \
        "${APPIMAGE}" "$@"
else
    exec firejail --profile="${PROFILE}" "${APPIMAGE}" "$@"
fi
