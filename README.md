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
| `run-orca-desktop.sh` | Wrapper: finds or downloads official AppImage, runs under Firejail |
| `install.sh` | Copies profiles, launcher, desktop entry |
| `.github/workflows/validate.yml` | CI: bash -n, ShellCheck, basic profile checks |
| `SECURITY-REVIEW.md` | Known gaps and hardening notes |

This repo does **not** rebuild or re-host the Orca binary. `--update` pulls the official AppImage straight from [stablyai/orca releases](https://github.com/stablyai/orca/releases).

## Quick start

```bash
# Install Firejail
sudo pacman -S firejail   # Arch
# sudo apt install firejail

git clone https://github.com/ystrem/orca-desktop-sandbox
cd orca-desktop-sandbox
bash install.sh

vim ~/.config/firejail/orca-desktop.net
# → add your remote orca serve IP (Tailscale 100.x / LAN)

orca-desktop-sandbox
```

## Features

* **Official AppImage only** — `orca-desktop-sandbox --update` downloads from `stablyai/orca`, no third-party rebuild
* **Desktop menu entry**
* **CLI arg forwarding** (e.g. `--devtools`)
* **Auto-discovery** of AppImage / `orca-ide` / `ORCA_APPIMAGE`
* **Uninstall**: `bash install.sh --uninstall`

## Network isolation

By default outbound is limited to loopback, DNS, and hosts you list in `orca-desktop.net`:

```
-A OUTPUT -d 100.64.1.20/32 -j ACCEPT
```

For netfilter to apply, enable a network namespace (`net default` in the profile or `--net=default`).

## Environment variables

| Variable | Purpose | Default |
| --- | --- | --- |
| `ORCA_APPIMAGE` | Path to AppImage / binary | Auto-detected |
| `ORCA_UPSTREAM_REPO` | Release source for `--update` | `stablyai/orca` |
| `ORCA_PROFILE_DIR` | Firejail profiles | `~/.config/firejail` |
| `ORCA_BIN_DIR` | Launcher + downloaded AppImage | `~/.local/bin` |
| `ORCA_DESKTOP_DIR` | `.desktop` files | `~/.local/share/applications` |

## What gets restricted

SSH/GPG/cloud creds, password managers, browser profiles, shell history, docker/podman sockets, writable home (except `~/.orca` + Electron config), capabilities, private `/tmp`, seccomp, noroot.

## CI

`validate.yml` runs on push/PR: `bash -n`, ShellCheck, and a few firejail profile sanity greps. No AppImage is downloaded or uploaded in CI.

## Related

* [hermes-desktop-sandbox](https://github.com/ystrem/hermes-desktop-sandbox) (builds Hermes AppImage — different problem)
* [onorca.dev](https://www.onorca.dev/) · [stablyai/orca](https://github.com/stablyai/orca)
