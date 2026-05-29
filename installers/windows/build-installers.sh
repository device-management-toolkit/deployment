#!/bin/bash
# Device Management Toolkit Console - Windows Installer Build Script
# Copyright (c) Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
# Builds two NSIS installers: one for UI edition, one for headless.
# Requires: NSIS (makensis) installed and on PATH.

set -e

VERSION="${1:-0.0.0}"
ARCH="${2:-x64}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
NSI_FILE="$SCRIPT_DIR/console.nsi"
OUTPUT_DIR="$REPO_ROOT/dist/windows"

# VI_VERSION must be numeric X.X.X.X — strip any pre-release suffix.
VI_VERSION="$(echo "$VERSION" | sed 's/-.*//').0"

# Console source is consumed via the services/console submodule when binaries
# are built locally. For release-train builds, set BINARY_DIR to a directory
# containing prebuilt binaries (see expected names below) to skip building.
CONSOLE_SRC="$REPO_ROOT/services/console"
WEBUI_SRC="$REPO_ROOT/services/sample-web-ui"
UI_EMBED_DIR="$CONSOLE_SRC/internal/controller/httpapi/ui"
BINARY_DIR="${BINARY_DIR:-$OUTPUT_DIR}"
UI_BINARY="$BINARY_DIR/console_windows_${ARCH}.exe"
HEADLESS_BINARY="$BINARY_DIR/console_windows_${ARCH}_headless.exe"

# Build the Angular web UI and stage it into the console's go:embed dir before
# compiling the full binary. That dir is gitignored (only .gitkeep is tracked),
# so a from-source build must populate it or the full binary ships an empty UI.
# Headless (-tags=noui) drops the embed entirely. Mirrors the Console release
# workflow's build-enterprise + move-into-httpapi/ui step.
build_web_ui() {
    if [ ! -f "$WEBUI_SRC/package.json" ]; then
        echo "Error: sample-web-ui source not found at $WEBUI_SRC" >&2
        echo "Initialize the submodule:" >&2
        echo "    git submodule update --init services/sample-web-ui" >&2
        exit 1
    fi
    if ! command -v npm >/dev/null 2>&1; then
        echo "Error: npm not found on PATH (needed to build the embedded web UI)" >&2
        exit 1
    fi

    echo "Building embedded web UI (npm run build-enterprise)..."
    (cd "$WEBUI_SRC" && npm ci && npm run build-enterprise)

    echo "Staging web UI into $UI_EMBED_DIR ..."
    rm -rf "$UI_EMBED_DIR"
    mkdir -p "$UI_EMBED_DIR"
    touch "$UI_EMBED_DIR/.gitkeep"
    cp -R "$WEBUI_SRC/ui/browser/." "$UI_EMBED_DIR/"
}

echo "Building Windows NSIS installers..."
echo "Version: $VERSION"
echo "Architecture: $ARCH"
echo "Binary dir: $BINARY_DIR"
echo ""

mkdir -p "$OUTPUT_DIR"

if [ -f "$UI_BINARY" ] && [ -f "$HEADLESS_BINARY" ]; then
    echo "=== Using prebuilt binaries ==="
    echo "  UI:       $UI_BINARY"
    echo "  Headless: $HEADLESS_BINARY"
else
    echo "=== Building Binaries from $CONSOLE_SRC ==="
    if [ ! -f "$CONSOLE_SRC/cmd/app/main.go" ] || [ ! -d "$CONSOLE_SRC/cmd/app" ]; then
        echo "Error: console source not found at $CONSOLE_SRC" >&2
        echo "Either initialize the submodule:" >&2
        echo "    git submodule update --init services/console" >&2
        echo "or provide prebuilt binaries via BINARY_DIR env var:" >&2
        echo "    BINARY_DIR=/path/to/dist/windows $0 $VERSION $ARCH" >&2
        echo "  expected files: $(basename "$UI_BINARY"), $(basename "$HEADLESS_BINARY")" >&2
        exit 1
    fi

    mkdir -p "$BINARY_DIR"

    build_web_ui

    # Stamp the version into the binary (matches the Console release workflow).
    LDFLAGS="-s -w -X 'github.com/device-management-toolkit/console/internal/app.Version=$VERSION'"

    echo "Building UI binary with tray (CGO_ENABLED=1)..."
    (cd "$CONSOLE_SRC" && CGO_ENABLED=1 GOOS=windows GOARCH=amd64 go build -tags=tray -ldflags "$LDFLAGS" -trimpath -o "$UI_BINARY" ./cmd/app)
    echo "  Built: $UI_BINARY"

    echo "Building headless binary with tray (CGO_ENABLED=1)..."
    (cd "$CONSOLE_SRC" && CGO_ENABLED=1 GOOS=windows GOARCH=amd64 go build -tags='tray noui' -ldflags "$LDFLAGS" -trimpath -o "$HEADLESS_BINARY" ./cmd/app)
    echo "  Built: $HEADLESS_BINARY"
fi

echo ""

# Build NSIS installers
echo "=== Building NSIS Installers ==="

# Use full path to makensis from NSIS installation
MAKENSIS="/c/Program Files (x86)/NSIS/makensis.exe"

if [ ! -f "$MAKENSIS" ]; then
    echo "Error: makensis not found at $MAKENSIS" >&2
    echo "Please install NSIS from https://nsis.sourceforge.io/" >&2
    exit 1
fi

# Convert Unix-style paths to Windows paths for NSIS. cygpath handles all
# drives and MSYS mount points correctly (Git Bash ships with it).
if ! command -v cygpath >/dev/null 2>&1; then
    echo "Error: cygpath not found; required for Unix→Windows path conversion." >&2
    echo "Install Git for Windows / MSYS2 to get cygpath." >&2
    exit 1
fi
UI_BINARY_WIN=$(cygpath -w "$UI_BINARY")
HEADLESS_BINARY_WIN=$(cygpath -w "$HEADLESS_BINARY")

echo "Building UI installer..."
"$MAKENSIS" -DVERSION="$VERSION" -DVI_VERSION="$VI_VERSION" -DARCH="$ARCH" -DEDITION=ui -DBINARY="$UI_BINARY_WIN" "$NSI_FILE"
mv "$SCRIPT_DIR/console_${VERSION}_windows_${ARCH}_setup.exe" "$OUTPUT_DIR/"
echo "  Created: $OUTPUT_DIR/console_${VERSION}_windows_${ARCH}_setup.exe"

echo "Building headless installer..."
"$MAKENSIS" -DVERSION="$VERSION" -DVI_VERSION="$VI_VERSION" -DARCH="$ARCH" -DEDITION=headless -DBINARY="$HEADLESS_BINARY_WIN" "$NSI_FILE"
mv "$SCRIPT_DIR/console_${VERSION}_windows_${ARCH}_headless_setup.exe" "$OUTPUT_DIR/"
echo "  Created: $OUTPUT_DIR/console_${VERSION}_windows_${ARCH}_headless_setup.exe"

echo ""
echo "=== Build Complete ==="
echo ""
echo "Installers created:"
echo "  UI:       $OUTPUT_DIR/console_${VERSION}_windows_${ARCH}_setup.exe"
echo "  Headless: $OUTPUT_DIR/console_${VERSION}_windows_${ARCH}_headless_setup.exe"
