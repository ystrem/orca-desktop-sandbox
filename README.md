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

## Building / finding Orca locally

Download from [onorca.dev/download](https://www.onorca.dev/download) or [GitHub Releases](https://github.com/stablyai/orca/releases):

* `orca-linux.AppImage`
* `.deb` / `.rpm` packages

The launcher auto-detects AppImages in `~/.local/bin`, `~/Applications`, and common paths.

## Related

* Inspired by [hermes-desktop-sandbox](https://github.com/ystrem/hermes-desktop-sandbox)
* Orca: [onorca.dev](https://www.onorca.dev/) · [stablyai/orca](https://github.com/stablyai/orca)
* Headless server guide: [headless-linux-server.md](https://github.com/stablyai/orca/blob/main/docs/reference/headless-linux-server.md)
