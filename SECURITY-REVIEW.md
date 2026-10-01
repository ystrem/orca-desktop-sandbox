# Security Review — Orca Desktop Sandbox

Date: 2026-10-01

This review covers the Firejail profile, netfilter rules, launcher wrapper, and install
script. Findings are ordered by severity. Model is adapted from hermes-desktop-sandbox
for the **thin-client** use case (local Orca UI → remote `orca serve`).

## Summary

The sandbox model is sound for a remote-only client: all capabilities are dropped,
`noroot` and `seccomp` are enabled, the home directory is read-only with explicit
whitelists for Orca state only, `/tmp` is private, sensitive paths and docker sockets
are blacklisted, and `private-dev` is on. The main remaining gaps are X11 isolation
and D-Bus exposure.

## Critical

- **X11 is shared with the host — keylogger + screen capture.**

  The profile only passes `env DISPLAY=${DISPLAY}` and has no `x11` directive. If the
  Electron renderer is compromised, it can read input from **all** windows, screenshot
  the screen, and inject fake input. X11 provides no isolation between clients.

  Fix: `x11 xorg` (Xephyr, requires `xorg-xephyr`) or use native Wayland
  (`env WAYLAND_DISPLAY` without XWayland). This is the largest real gap for a desktop
  sandbox.

## High

- **D-Bus left open.**

  `nodbus` / `nodbus-user` are not set so audio and notifications work. The app can call
  session/system D-Bus services (screenshot, keyring, notifications). Consider
  `dbus-user none` / `dbus-system none` and verify audio still works over raw sockets.
  Document this as a conscious trade-off.

## Medium

- **`read-only ${HOME}` does not prevent exec.** Add `noexec ${HOME}` if desired — the
  AppImage is typically mounted via FUSE into a private path, so it is unaffected, but
  it blocks executing anything downloaded into the home directory.
- **Missing `restrict-namespaces`.** Without it the app can create new user namespaces.
  Caution: Electron/Chromium may need them for its own sandbox — if so, use the SUID
  chrome-sandbox and keep `restrict-namespaces` if possible.
- **Weak fallback in the wrapper.** When the profile is missing, the launcher runs a
  reduced set of flags. Prefer failing loudly or using the same strict profile.
- **`seccomp` without exceptions.** Electron/Chromium (JIT, GPU) may fail under the
  default seccomp filter. Verify functionality; if needed add `seccomp.keep` for
  required syscalls.

## Low / cosmetic

- Consider `blacklist /boot`, `blacklist /root`, or `private-etc` for a cleaner `/etc`.
- Netfilter INPUT chain includes ESTABLISHED/RELATED and loopback (fixed vs early Hermes).

## Context

This sandbox wraps a **thin client**. The agent does not run code or touch project files
on the local machine — that happens on remote `orca serve`. Firejail therefore mainly
protects against exploitation of the Electron/Chromium renderer (XSS, JS exploits),
not against what agents do on the server. The highest-value local fixes are X11
isolation and D-Bus restriction.

## Recommended next steps

1. Add X11 isolation (`x11 xorg`) or native Wayland.
2. Reconsider D-Bus exposure after testing audio.
3. Optionally add `noexec ${HOME}` and `restrict-namespaces` if Chromium still runs.
4. Document which remote IPs users must whitelist in `orca-desktop.net`.
