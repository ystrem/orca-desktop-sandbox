#!/bin/bash
# Orca Desktop — Firejail sandboxed launcher (thin client to remote orca serve)
# Auto-detects local AppImages / unpacked binaries, or downloads mirrored releases

set -euo pipefail

PROFILE_DIR="${ORCA_PROFILE_DIR:-${HOME}/.config/firejail}"
PROFILE="${PROFILE_DIR}/orca-desktop.local"
DOWNLOAD_DIR="${ORCA_BIN_DIR:-${HOME}/.local/bin}"

# Auto-detect GitHub release repository for --update
if [ -n "${ORCA_SANDBOX_REPO:-}" ]; then
    RELEASE_REPO="${ORCA_SANDBOX_REPO}"
else
    DETECTED_REPO=$(git config --get remote.origin.url 2>/dev/null | sed -E 's/.*[:\/]([^\/]+\/[^\/.]+)(\.git)?$/\1/' || echo "")
    RELEASE_REPO="${DETECTED_REPO:-ystrem/orca-desktop-sandbox}"
fi

show_help() {
    echo "Usage: orca-desktop-sandbox [OPTIONS] [ELECTRON_ARGS...]"
    echo ""
    echo "Launch the Orca Desktop AppImage inside a Firejail sandbox."
    echo "Intended for use as a thin client to remote 'orca serve' hosts."
    echo ""
    echo "Environment variables:"
    echo "  ORCA_APPIMAGE      Path to custom Orca AppImage or executable"
    echo "  ORCA_SANDBOX_REPO  owner/repo for mirrored releases (default: ystrem/orca-desktop-sandbox)"
    echo ""
    echo "Options:"
    echo "  --update, --download   Download / update the latest mirrored AppImage from GitHub"
    echo "  -h, --help             Show this help message and exit"
    echo ""
    exit 0
}

download_latest_release() {
    echo "==> Fetching latest mirrored Orca AppImage from GitHub (${RELEASE_REPO})..."
    local release_json asset_url file_name tag_name
    release_json=$(curl -fsSL -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${RELEASE_REPO}/releases/latest" 2>/dev/null || echo "")

    if [ -z "${release_json}" ] || echo "${release_json}" | grep -q '"message": "Not Found"'; then
        echo "Error: Could not fetch latest release from https://github.com/${RELEASE_REPO}/releases"
        echo "Ensure GitHub Actions has published a mirrored release, or download from:"
        echo "  https://github.com/stablyai/orca/releases"
        exit 1
    fi

    asset_url=$(echo "${release_json}" | grep -oE '"browser_download_url": "[^"]+\.AppImage"' | head -n1 | sed 's/.*"browser_download_url": "//;s/"$//')
    file_name=$(echo "${release_json}" | grep -oE '"name": "[^"]+\.AppImage"' | head -n1 | sed 's/.*"name": "//;s/"$//')
    tag_name=$(echo "${release_json}" | grep -oE '"tag_name": "[^"]+"' | head -n1 | sed 's/.*"tag_name": "//;s/"$//')

    if [ -z "${asset_url}" ]; then
        echo "Error: No .AppImage asset found in latest release (${tag_name})."
        exit 1
    fi

    mkdir -p "${DOWNLOAD_DIR}"
    local target_path="${DOWNLOAD_DIR}/${file_name}"

    echo "==> Downloading ${file_name} (${tag_name}) to ${DOWNLOAD_DIR}..."
    curl -fL --progress-bar -o "${target_path}" "${asset_url}"
    chmod +x "${target_path}"
    # Stable symlink for discovery
    ln -sfn "${target_path}" "${DOWNLOAD_DIR}/orca-linux.AppImage"
    echo "  ✓ Download complete: ${target_path}"
    APPIMAGE="${target_path}"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
fi

if [[ "${1:-}" == "--update" || "${1:-}" == "--download" ]]; then
    download_latest_release
    shift
    # If only --update was requested, exit after download
    if [ "$#" -eq 0 ]; then
        exit 0
    fi
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
                FOUND=$(find "${dir}" -maxdepth 2 \(
                    -name "orca-linux.AppImage" -o
                    -name "Orca-*.AppImage" -o
                    -name "orca-*.AppImage"
                \) -type f 2>/dev/null | sort -V | tail -1)
                if [ -n "${FOUND}" ]; then
                    APPIMAGE="${FOUND}"
                    break
                fi
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

# If still not found, offer to download from mirrored releases
if [ -z "${APPIMAGE}" ]; then
    echo "No local Orca AppImage or executable found."
    echo "Attempting automatic download of mirrored release from GitHub..."
    download_latest_release
fi

# Non-blocking update check
(
    latest_tag=$(curl -fsSL --connect-timeout 1 -m 2 -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${RELEASE_REPO}/releases/latest" 2>/dev/null \
        | grep -oE '"tag_name": "[^"]+"' | head -n1 | sed 's/.*"tag_name": "//;s/"$//' || echo "")
    if [ -n "${latest_tag}" ] && [ "${latest_tag}" != "null" ]; then
        current_name=$(basename "${APPIMAGE}")
        if [[ "${current_name}" != *"${latest_tag#orca-}"* ]] && [[ "${current_name}" != *"${latest_tag}"* ]]; then
            echo "💡 Tip: A newer mirrored Orca release (${latest_tag}) may be available." >&2
            echo "   Run 'orca-desktop-sandbox --update' to download it." >&2
        fi
    fi
) &>/dev/null &

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
