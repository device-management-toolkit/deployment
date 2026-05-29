# macOS Installer (Console — on-prem)

Native macOS `.pkg` installer for Device Management Toolkit (Console) on-prem.
Two editions are produced per build, both with the system tray:

- **UI** — system tray plus the embedded web UI (auto-launched after install)
- **Headless** — system tray plus the API only, no web UI bundled
  (auto-launched after install)

## Build

Must run on macOS — uses `pkgbuild` / `productbuild`.

Prereqs on the build host:

- macOS with `pkgbuild` / `productbuild` (standard with Xcode CLT)
- Go 1.25+ — only when building binaries from source; matches
  `services/console/go.mod`
- Node.js 20+ and `npm` — only when building from source; the UI edition
  builds the Angular web UI (`npm run build-enterprise`) and stages it into
  the console's `go:embed` dir before compiling
- Xcode Command Line Tools — only when building from source; both editions
  use `CGO_ENABLED=1` for the tray dependency

```bash
./build-pkg.sh [VERSION] [ARCH]
```

Defaults: `VERSION=0.0.0`, `ARCH=arm64`. `ARCH` is passed through as
`GOARCH` (use `arm64` or `amd64`).

Outputs to `dist/darwin/`:

- `console_<VERSION>_macos_<ARCH>.pkg`           (UI)
- `console_<VERSION>_macos_<ARCH>_headless.pkg`  (headless)

### Binary sourcing

The script needs two prebuilt binaries:
`console_mac_<ARCH>_tray` and `console_mac_<ARCH>_headless_tray`. Release
binaries already have the web UI embedded; a from-source build of the UI
edition rebuilds it (see below).

- **Release-train (preferred):** point `BINARY_DIR` at a directory holding
  the binaries from a tagged Console release. No Go/CGO/Node toolchain needed.
  ```bash
  BINARY_DIR=/path/to/release/darwin ./build-pkg.sh 3.1.0 arm64
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
  ./build-pkg.sh
  ```

If neither path is satisfied, the script exits with a clear error.

## Scope

- `.pkg` installer that provisions Console on a single macOS host.
- Apple Silicon (`arm64`) and Intel (`amd64`).
- Installs binary to `/usr/local/device-management-toolkit/` and symlinks
  `dmt-console`, `dmt-configure`, `dmt-uninstall` into `/usr/local/bin`.
- Auto-launches `console --tray` as the console user after install.
- Reinstall safely stops the running instance via `preinstall`; clean
  uninstall via `sudo dmt-uninstall`.
