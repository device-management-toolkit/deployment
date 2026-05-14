# Windows Installer (Console — on-prem)

Native Windows NSIS installer for Device Management Toolkit (Console) on-prem.
Two editions are produced per build, both with the system tray:

- **Full** — system tray plus the embedded web UI
- **Headless** — system tray plus the API only (no web UI bundled)

## Build

Run from **Windows** in **Git Bash** (or MSYS2). The script hardcodes
`C:\Program Files (x86)\NSIS\makensis.exe` and uses Git Bash–style paths, so
it does not run on Linux or macOS.

Prereqs on the build host:

- Git Bash or MSYS2
- NSIS 3.x at the default install path
- Go 1.25+ — only when building binaries from source (see below); matches
  `services/console/go.mod`
- A mingw-w64 `gcc` on `PATH` — only when building from source; both
  editions use `CGO_ENABLED=1` for the tray dependency

```bash
./build-installers.sh [VERSION] [ARCH]
```

Defaults: `VERSION=0.0.0`, `ARCH=x64`. `ARCH` only affects output filenames
— the Go build is hardcoded to `GOARCH=amd64`.

Outputs to `dist/windows/`:

- `console_<VERSION>_windows_<ARCH>_setup.exe`           (full)
- `console_<VERSION>_windows_<ARCH>_headless_setup.exe`  (headless)

### Binary sourcing

The script needs two prebuilt binaries:
`console_windows_<ARCH>.exe` and `console_windows_<ARCH>_headless.exe`.

- **Release-train (preferred):** point `BINARY_DIR` at a directory holding
  the binaries from a tagged Console release. No Go/CGO toolchain needed.
  ```bash
  BINARY_DIR=/c/path/to/release/windows ./build-installers.sh 3.1.0 x64
  ```
- **Local dev:** initialize the `services/console` submodule and the script
  will build the binaries from source (needs Go + a CGO-capable mingw
  toolchain).
  ```bash
  git submodule update --init services/console
  ./build-installers.sh
  ```

If neither path is satisfied, the script exits with a clear error.

