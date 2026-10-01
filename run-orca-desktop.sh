#!/bin/bash
# Orca Desktop — Firejail sandboxed launcher (thin client to remote orca serve)
# Downloads the official AppImage directly from stablyai/orca (no local mirror).

set -euo pipefail

PROFILE_DIR="${ORCA_PROFILE_DIR:-${HOME}/.config/firejail}"
PROFILE="${PROFILE_DIR}/orca-desktop.local"
DOWNLOAD_DIR="${ORCA_BIN_DIR:-${HOME}/.local/bin}"
UPSTREAM_REPO="${ORCA_UPSTREAM_REPO:-stablyai/orca}"

show_help() {
    echo "Usage: orca-desktop-sandbox [OPTIONS] [ELECTRON_ARGS...]"
    echo ""
    echo "Launch the Orca Desktop AppImage inside a Firejail sandbox."
    echo "Intended for use as a thin client to remote 'orca serve' hosts."
    echo ""
    echo "Environment variables:"
    echo "  ORCA_APPIMAGE       Path to custom Orca AppImage or executable"
    echo "  ORCA_UPSTREAM_REPO  owner/repo for official releases (default: stablyai/orca)"
    echo ""
    echo "Options:"
    echo "  --update, --download   Download latest official AppImage from stablyai/orca"
    echo "  -h, --help             Show this help message and exit"
    echo ""
    exit 0
}

download_latest_release() {
    echo "==> Fetching latest official Orca AppImage from ${UPSTREAM_REPO}..."
    local release_json asset_url file_name tag_name
    release_json=$(curl -fsSL -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest" 2>/dev/null || echo "")

    if [ -z "${release_json}" ] || echo "${release_json}" | grep -q '"Not Found"'; then
        echo "Error: Could not fetch latest release from https://github.com/${UPSTREAM_REPO}/releases"
        echo "Download manually: https://www.onorca.dev/download"
        exit 1
    fi

    tag_name=$(echo "${release_json}" | grep -oE '"tag_name": "[^"]+"' | head -n1 | sed 's/.*"tag_name": "//;s/"$//')

    # Prefer the canonical asset name used by docs / onorca.dev
    asset_url=$(echo "${release_json}" | grep -oE '"browser_download_url": "[^"]*orca-linux\.AppImage"' | head -n1 | sed 's/.*"browser_download_url": "//;s/"$//')
    file_name="orca-linux.AppImage"

    if [ -z "${asset_url}" ]; then
        asset_url=$(echo "${release_json}" | grep -oE '"browser_download_url": "[^"]+\.AppImage"' | head -n1 | sed 's/.*"browser_download_url": "//;s/"$//')
        file_name=$(echo "${release_json}" | grep -oE '"name": "[^"]+\.AppImage"' | head -n1 | sed 's/.*"name": "//;s/"$//')
    fi

    if [ -z "${asset_url}" ]; then
        # Stable redirect URL as last resort
        asset_url="https://github.com/${UPSTREAM_REPO}/releases/latest/download/orca-linux.AppImage"
        file_name="orca-linux.AppImage"
        echo "Note: using latest/download redirect for ${file_name}"
    fi

    mkdir -p "${DOWNLOAD_DIR}"
    local target_path="${DOWNLOAD_DIR}/${file_name}"
    local tmp_path="${target_path}.partial"

    echo "==> Downloading ${file_name} (${tag_name:-latest}) → ${DOWNLOAD_DIR}/"
    curl -fL --progress-bar -o "${tmp_path}" "${asset_url}"
    chmod +x "${tmp_path}"
    mv -f "${tmp_path}" "${target_path}"
    # Stable name for discovery when asset had a versioned filename
    if [ "${file_name}" != "orca-linux.AppImage" ]; then
        ln -sfn "${target_path}" "${DOWNLOAD_DIR}/orca-linux.AppImage"
    fi
    echo "  ✓ ${target_path}"
    APPIMAGE="${target_path}"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
fi

if [[ "${1:-}" == "--update" || "${1:-}" == "--download" ]]; then
    download_latest_release
    shift
    if [ "$#" -eq 0 ]; then
        exit 0
    fi
fi

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

if [ -z "${APPIMAGE}" ]; then
    echo "No local Orca AppImage found — downloading official release..."
    download_latest_release
fi

# Non-blocking tip when upstream is newer (best-effort; ignores rate limits)
(
    latest_tag=$(curl -fsSL --connect-timeout 1 -m 2 -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest" 2>/dev/null \
        | grep -oE '"tag_name": "[^"]+"' | head -n1 | sed 's/.*"tag_name": "//;s/"$//' || echo "")
    if [ -n "${latest_tag}" ] && [ "${latest_tag}" != "null" ]; then
        current_name=$(basename "${APPIMAGE}")
        if [[ "${current_name}" != *"${latest_tag#v}"* ]] && [[ "${current_name}" != *"${latest_tag}"* ]]; then
            # Only tip if we have a versioned local name; plain orca-linux.AppImage is opaque
            if [[ "${current_name}" == *Orca-* ]] || [[ "${current_name}" == *orca-*[0-9]* ]]; then
                echo "💡 Tip: Upstream Orca ${latest_tag} may be newer." >&2
                echo "   Run 'orca-desktop-sandbox --update' to refresh." >&2
            fi
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
