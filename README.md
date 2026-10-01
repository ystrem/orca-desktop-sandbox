# Orca Desktop Sandbox

Firejail sandbox profile for isolating the [Orca](https://www.onorca.dev/) ADE desktop app when used as a **thin client** to remote `orca serve` (headless) servers.

Local Orca only shows UI and talks to remote runtimes. Code, worktrees, terminals and agents live on the server — so the local desktop does **not** need access to your project directories.

## Why sandbox the Orca desktop?

Orca desktop is an **Electron shell** (Chromium + Node.js). Even as a remote client it has access to:

* Your `~/.orca/` state (pairing tokens, settings, server list)
* Network (pairing / WebSocket to remote servers)
* Display and optional microphone

Sandboxing with Firejail restricts:

* **Filesystem** — only `~/.orca` and Electron app config writable; everything else read-only or blacklisted
* **Network** — only localhost + DNS + explicitly whitelisted remote Orca server IPs
* **Capabilities** — none
* **Temp** — isolated `/tmp`
* **Sensitive data** — SSH keys, GPG, cloud credentials, password vaults, browser histories, docker sockets hidden

## What's in here

| File | Purpose |
| --- | --- |
| `orca-desktop.local` | Firejail profile — sandbox rules |
| `orca-desktop.net` | Netfilter rules — restrict to specific IPs/domains |
| `run-orca-desktop.sh` | Wrapper script to launch the sandboxed desktop & check for updates |
| `install.sh` | Setup script (copies profiles, launcher, desktop entry) |
| `.github/workflows/mirror-orca.yml` | GitHub Actions — mirrors official Orca Linux AppImage every 6h |
| `SECURITY-REVIEW.md` | Known gaps and hardening notes |

## Quick start

```bash
# Install Firejail (Arch/CachyOS)
sudo pacman -S firejail
# Debian/Ubuntu: sudo apt install firejail

# Clone and install
git clone https://github.com/ystrem/orca-desktop-sandbox
cd orca-desktop-sandbox
bash install.sh

# EDIT the netfilter rules before first run:
vim ~/.config/firejail/orca-desktop.net
# → uncomment / add lines with your remote orca serve IPs (Tailscale 100.x, LAN, etc.)

# Launch sandboxed Orca from application menu or terminal:
orca-desktop-sandbox
```

## Features

* **Mirrored AppImages via GitHub Actions** — workflow checks `stablyai/orca` every 6 hours and re-publishes the official Linux AppImage to this repo’s Releases (tag `orca-vX.Y.Z`)
* **One-Click Auto-Updates** — `orca-desktop-sandbox --update` downloads the latest mirrored AppImage
* **Desktop Menu Entry** — creates `~/.local/share/applications/orca-desktop-sandbox.desktop`
* **CLI Argument Forwarding** — pass flags directly to the AppImage (e.g. `orca-desktop-sandbox --devtools`)
* **Flexible Binary Discovery** — auto-detects AppImages, unpacked executables, or `ORCA_APPIMAGE`
* **Easy Uninstall** — `bash install.sh --uninstall`

## Network isolation

By default, Orca can **only** talk to:

* localhost (127.0.0.1 / ::1)
* DNS
* **Whitelisted IPs/hosts** specified in `orca-desktop.net`

To whitelist your remote `orca serve` hosts, edit `~/.config/firejail/orca-desktop.net`:

```
-A OUTPUT -d 100.64.1.20/32 -j ACCEPT   # Tailscale example
-A OUTPUT -d 192.168.1.50/32 -j ACCEPT  # LAN example
```

*Note:* For Firejail netfilter rules to take effect, Firejail requires an active network namespace. You can pass `--net=default` or uncomment `net default` in `orca-desktop.local`.

## Environment Variables

| Variable | Purpose | Default |
| --- | --- | --- |
| `ORCA_APPIMAGE` | Path to explicit Orca AppImage or executable | Auto-detected |
| `ORCA_SANDBOX_REPO` | `owner/repo` for mirrored releases | `ystrem/orca-desktop-sandbox` |
| `ORCA_PROFILE_DIR` | Firejail profiles directory | `${HOME}/.config/firejail` |
| `ORCA_BIN_DIR` | Executable launcher bin directory | `${HOME}/.local/bin` |
| `ORCA_DESKTOP_DIR` | XDG desktop entries directory | `${HOME}/.local/share/applications` |

## Microphone (dictation)

Microphone works — the profile preserves PulseAudio/PipeWire sockets and `/dev/snd` access. If audio stops working, check that `nogroups` is **not** set.

## What gets restricted

| Area | Restriction |
| --- | --- |
| SSH keys | Blocked (`~/.ssh`) |
| GPG keys | Blocked (`~/.gnupg`) |
| Cloud credentials | Blocked (`~/.aws`, `~/.azure`, `~/.kube`, `~/.config/gcloud`) |
| Password stores | Blocked (Bitwarden, 1Password, KeePassXC, password-store) |
| Browser data | Blocked (Chromium, Chrome, Brave, Edge, Firefox, …) |
| Developer tokens | Blocked (`~/.npmrc`, `~/.pypirc`, `~/.cargo/credentials*`, `~/.config/gh`) |
| Shell history | Blocked |
| Docker/Podman sockets | Blocked |
| `/tmp` | Private (fresh tmpfs) |
| Network | Only 127.0.0.1 + whitelisted IPs |
| Kernel | No new privileges, seccomp |
| Capabilities | All dropped |

## GitHub Actions (mirror)

Unlike Hermes (which builds the AppImage from source), Orca already publishes official Linux AppImages. This repo’s workflow:

1. Polls [stablyai/orca](https://github.com/stablyai/orca) releases every 6 hours (and on manual dispatch)
2. Downloads the official `orca-linux.AppImage` (or any `*.AppImage` fallback)
3. Creates a release here tagged `orca-vX.Y.Z` with the unmodified binary + SHA256

Trigger manually: **Actions → Mirror Orca Linux AppImage → Run workflow** (optionally force).

## Related

* Inspired by [hermes-desktop-sandbox](https://github.com/ystrem/hermes-desktop-sandbox)
* Orca: [onorca.dev](https://www.onorca.dev/) · [stablyai/orca](https://github.com/stablyai/orca)
* Headless server guide: [headless-linux-server.md](https://github.com/stablyai/orca/blob/main/docs/reference/headless-linux-server.md)
