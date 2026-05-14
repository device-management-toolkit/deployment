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
BINARY_DIR="${BINARY_DIR:-$OUTPUT_DIR}"
UI_BINARY="$BINARY_DIR/console_windows_${ARCH}.exe"
HEADLESS_BINARY="$BINARY_DIR/console_windows_${ARCH}_headless.exe"

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
    if [ ! -f "$CONSOLE_SRC/cmd/app/main.go" ] && [ ! -d "$CONSOLE_SRC/cmd/app" ]; then
        echo "Error: console source not found at $CONSOLE_SRC" >&2
        echo "Either initialize the submodule:" >&2
        echo "    git submodule update --init services/console" >&2
        echo "or provide prebuilt binaries via BINARY_DIR env var:" >&2
        echo "    BINARY_DIR=/path/to/dist/windows $0 $VERSION $ARCH" >&2
        echo "  expected files: $(basename "$UI_BINARY"), $(basename "$HEADLESS_BINARY")" >&2
        exit 1
    fi

    mkdir -p "$BINARY_DIR"

    echo "Building UI binary with tray (CGO_ENABLED=1)..."
    (cd "$CONSOLE_SRC" && CGO_ENABLED=1 GOOS=windows GOARCH=amd64 go build -tags=tray -ldflags "-s -w" -trimpath -o "$UI_BINARY" ./cmd/app)
    echo "  Built: $UI_BINARY"

    echo "Building headless binary with tray (CGO_ENABLED=1)..."
    (cd "$CONSOLE_SRC" && CGO_ENABLED=1 GOOS=windows GOARCH=amd64 go build -tags='tray noui' -ldflags "-s -w" -trimpath -o "$HEADLESS_BINARY" ./cmd/app)
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

# Convert Unix-style paths to Windows paths for NSIS (backslashes)
UI_BINARY_WIN=$(echo "$UI_BINARY" | sed 's|^/c|C:|' | sed 's|/|\\|g')
HEADLESS_BINARY_WIN=$(echo "$HEADLESS_BINARY" | sed 's|^/c|C:|' | sed 's|/|\\|g')

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
