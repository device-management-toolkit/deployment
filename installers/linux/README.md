# Linux Installer (Console — on-prem)

Native Linux `.deb` and `.rpm` installers for Device Management Toolkit
(Console) on-prem. Two editions are produced per build, both with the
system tray (matches the macOS PKG and Windows NSIS installers):

- **UI** — system tray plus the embedded web UI (auto-launched after install)
- **Headless** — system tray plus the API only, no embedded web UI
  (auto-launched after install)

The tray uses `fyne.io/systray`, which requires GTK3 + Ayatana
AppIndicator at runtime. Both are declared as package dependencies.

## Build

Prereqs on the build host:

- `nfpm` — `go install github.com/goreleaser/nfpm/v2/cmd/nfpm@latest`
- Go 1.25+ — only when building binaries from source; matches
  `services/console/go.mod`
- Node.js 20+ and `npm` — only when building from source; the UI edition
  builds the Angular web UI (`npm run build-enterprise`) and stages it into
  the console's `go:embed` dir before compiling
- `gcc`, `libgtk-3-dev`, `libayatana-appindicator3-dev` — only when
  building from source; both editions use `CGO_ENABLED=1` for the tray
  dependency (mirrors the macOS / Windows tray builds)

```bash
./build-packages.sh [VERSION] [ARCH]
```

Defaults: `VERSION=0.0.0`, `ARCH=amd64`. Only `amd64` is supported in v1;
arm64 is tracked as a follow-up.

Outputs to `dist/linux/`:

- `console_<VERSION>_linux_amd64.deb`           (UI)
- `console_<VERSION>_linux_amd64.rpm`           (UI)
- `console_<VERSION>_linux_amd64_headless.deb`  (headless)
- `console_<VERSION>_linux_amd64_headless.rpm`  (headless)

### Binary sourcing

The script needs two prebuilt binaries:
`console_linux_<ARCH>_tray` and `console_linux_<ARCH>_headless_tray`. Release
binaries already have the web UI embedded; a from-source build of the UI
edition rebuilds it (see below).

- **Release-train (preferred):** point `BINARY_DIR` at a directory holding
  the binaries from a tagged Console release. No Go/CGO/Node toolchain needed.
  ```bash
  BINARY_DIR=/path/to/release/linux ./build-packages.sh 3.1.0 amd64
  ```
- **Local dev:** initialize the `services/console` and `services/sample-web-ui`
  submodules and the script will build the binaries from source. For the UI
  edition it runs `npm run build-enterprise` in `sample-web-ui` and stages the
  output into `services/console/internal/controller/httpapi/ui` (the
  `go:embed` dir, which is gitignored apart from `.gitkeep`) before compiling
  — matching the Console release workflow. Without this the full binary would
  ship an empty web UI.
  ```bash
  git submodule update --init services/console services/sample-web-ui
  ./build-packages.sh
  ```

If neither path is satisfied, the script exits with a clear error.

## Install

```bash
# Debian / Ubuntu
sudo apt install ./console_3.1.0_linux_amd64.deb

# RHEL / Rocky / Fedora
sudo dnf install ./console_3.1.0_linux_amd64.rpm
```

On first install the postinstall scriptlet:

1. Generates `/opt/dmt-console/config/config.yml` from a template with a
   random JWT signing key, encryption key, and admin password. (This is the
   file the binary actually reads — it resolves its config relative to the
   real binary at `/opt/dmt-console/dmt-console`, which the `/usr/bin`
   symlink points at.)
2. Writes the generated admin credentials to
   `/opt/dmt-console/INITIAL_CREDENTIALS.txt` (mode 0600, owned by the
   detected desktop user).
3. Auto-launches `dmt-console --tray` as the detected desktop user when a
   graphical session is active.
4. Installs an XDG autostart entry so the tray restarts on every login.

Read the initial credentials with:

```bash
cat /opt/dmt-console/INITIAL_CREDENTIALS.txt
```

The file is `chown`'d to the detected desktop user on install, so no
`sudo` is needed there. On a server install with no desktop user the
file stays root-owned — prefix with `sudo` in that case.

### Server (no GUI) installs

If no graphical session is detected, postinstall skips the auto-launch
and prints a hint. The binary still works as a CLI; run it directly (it
finds `/opt/dmt-console/config/config.yml` on its own — no `--config`
needed):

```bash
/usr/bin/dmt-console
```

(No systemd unit ships with this package — the macOS and Windows
installers also do not install a system service. If you want one, the
README in the deployment repo documents `docker-compose.yml` and the
Helm chart for the server-style deployment.)

## System tray

The UI edition's tray menu has an **Open DMT Console** item that launches
the configured URL in your default browser; the headless edition shows
status only (no web UI to open). The URL is derived from `config.yml`:
`https` when `http.tls.enabled` is `true` (the default), the configured
`http.host` (default `localhost`), and `http.port` (default `8181`) — so
out of the box it opens `https://localhost:8181`. TLS uses a self-signed
cert on first run, so the browser shows a one-time "not private" warning;
accept it, or set `tls.enabled: false` via `dmt-configure`.

The tray icon itself rides D-Bus (Ayatana AppIndicator) and needs only the
session bus, but **"Open" shells out to `xdg-open`, which needs a display**.
postinstall and the XDG autostart entry launch the tray with
`DISPLAY`/`WAYLAND_DISPLAY` from your graphical session so this works. If
"Open" does nothing, the running daemon was started without a display —
relaunch it from a graphical session:

```bash
pkill -x dmt-console
dmt-console --tray
```

## Reconfigure

```bash
dmt-configure
```

No `sudo` needed on a desktop install — postinstall chowns the config to
the desktop user, so its owner can reconfigure directly. (On a server
install with a root-owned config, run it with `sudo`.)

Prompts for HTTP port, TLS toggle, admin username and password; rewrites
`/opt/dmt-console/config/config.yml`; stops and relaunches the running tray
instance so the new values take effect. Direct edits to `config.yml` are
preserved across package upgrades (postinstall checks for an existing
file before regenerating).

## Upgrade

```bash
sudo apt install ./console_3.1.1_linux_amd64.deb
# or
sudo dnf upgrade ./console_3.1.1_linux_amd64.rpm
```

Upgrade behavior:

- preinstall kills the running tray (mirrors macOS preinstall and Windows
  `taskkill /F /IM console.exe`).
- `config.yml` is **preserved** (operator edits are not clobbered).
- `INITIAL_CREDENTIALS.txt` is not regenerated.
- postinstall relaunches the tray for the detected desktop user.

**Downgrades are refused.** preinstall is stamped with the package version
at build time; if a newer version is already installed it exits non-zero,
which aborts the `apt`/`dnf` operation (a hard stop, not dpkg/rpm's soft
"downgrading" warning — matching the macOS and Windows installers). To move
to an older version, uninstall first (`sudo dmt-uninstall`), then install
the target version.

## Uninstall

```bash
sudo dmt-uninstall
```

Detects the package manager, kills any running tray, then prompts twice
(mirroring the Windows uninstaller's "remove user data?" step):

1. **Remove configuration** (`/opt/dmt-console`) — drives `apt purge` vs
   `apt remove`; on rpm it backs the config up to `/root` first when kept.
2. **Also remove your Console data** — the per-user database, profiles, and
   encrypted credentials under `~/.config/device-management-toolkit/`. Off by
   default; resolves the desktop user via `$SUDO_USER` and deletes only that
   user's data when confirmed.

Or use the package manager directly:

```bash
sudo apt remove dmt-console       # keep /opt/dmt-console (config)
sudo apt purge  dmt-console       # remove /opt/dmt-console (config)
sudo dnf remove dmt-console       # rpm has no remove/purge split
```

Per-user Console state lives under `$XDG_CONFIG_HOME`
(default `~/.config/device-management-toolkit/`, what Go's
`os.UserConfigDir()` returns) and is **never** touched by the package
manager itself — only `dmt-uninstall`'s second prompt removes it (the
macOS/Windows uninstallers prompt about `~/Library`/`%APPDATA%` the same
way).

## Install layout

| Component         | Path                                                |
|-------------------|-----------------------------------------------------|
| Binary (real)     | `/opt/dmt-console/dmt-console`                      |
| Binary (symlink)  | `/usr/bin/dmt-console` → `/opt/dmt-console/dmt-console` |
| Helper CLIs       | `/usr/bin/{dmt-configure,dmt-uninstall}`            |
| XDG autostart     | `/etc/xdg/autostart/dmt-console.desktop`            |
| Config            | `/opt/dmt-console/config/config.yml` (chowned to the desktop user) |
| Config template   | `/usr/share/dmt-console/config.yml.tmpl`            |
| Initial creds     | `/opt/dmt-console/INITIAL_CREDENTIALS.txt`          |
| Docs              | `/usr/share/doc/dmt-console/{README.md,copyright}`  |
| Per-user state    | `~/.config/device-management-toolkit/` (Go's `os.UserConfigDir()`) |

## Dependencies (runtime, not bundled)

- GTK3 + Ayatana AppIndicator — required for the tray. Declared as
  `libgtk-3-0`, `libayatana-appindicator3-1` (Debian/Ubuntu) and
  `gtk3`, `libayatana-appindicator-gtk3` (RHEL/Fedora/Rocky).
- OpenSSL — used by postinstall to generate the JWT and encryption key.
- `xdg-utils` — provides `xdg-open`, which the tray's "Open" menu item uses
  to launch the browser. Normally preinstalled on desktops; not declared as
  a package dependency.
- Embedded SQLite (the default) — no external database required. The DB is
  created per-user at `~/.config/device-management-toolkit/console.db`
  (Go's `os.UserConfigDir()`). The `DB_URL not declared -- using embedded
  database` line on startup is informational, not an error.
- PostgreSQL (optional) — only when you set `postgres.url` in `config.yml`
  (or `DB_URL` in the environment). Run Postgres on the same host or point
  at an external instance. See `pg/` and `docker-compose.yml` in the repo
  root for a working Postgres setup.
- HashiCorp Vault (optional) — for centralized secret storage. With no
  Vault configured, the encryption key in `config.yml` is used directly (the
  OS keyring is only consulted when no key is present in config/env).

Postgres and Vault are not bundled — same as the macOS and Windows
installers.

## Scope

- `.deb` and `.rpm` for Debian / Ubuntu / RHEL / Rocky / Fedora.
- `amd64` only in v1 (arm64 follow-up).
- System tray with auto-launch + XDG autostart, mirroring macOS/Windows.
- Idempotent reinstall (preinstall kills the running tray) and clean
  uninstall.

## Out of scope (follow-ups)

- `linux/arm64` builds (requires adding `GOARCH=arm64` target to
  `services/console/Makefile`).
- `.tar.gz` + `install.sh` for distros without dpkg/rpm (Alpine, Arch).
- Optional systemd unit for headless server deployments (would need a
  dedicated build without tray to avoid the GTK3 runtime dep).
- Code signing (`debsigs`, `rpm --addsign`).
