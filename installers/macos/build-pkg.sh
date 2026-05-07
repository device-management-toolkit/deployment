#!/bin/bash
# Device Management Toolkit Console - macOS PKG Build Script
# Copyright (c) Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -e

VERSION="${1:-0.0.0}"
ARCH="${2:-arm64}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$REPO_ROOT/installers/macos/build"
OUTPUT_DIR="$REPO_ROOT/dist/darwin"

# Console source is consumed via the services/console submodule when binaries
# are built locally. For release-train builds, set BINARY_DIR to a directory
# containing prebuilt binaries (see expected names below) to skip building.
CONSOLE_SRC="$REPO_ROOT/services/console"
BINARY_DIR="${BINARY_DIR:-$OUTPUT_DIR}"
UI_BINARY="$BINARY_DIR/console_mac_${ARCH}_tray"
HEADLESS_BINARY="$BINARY_DIR/console_mac_${ARCH}_headless_tray"

echo "Building macOS PKG installers..."
echo "Version: $VERSION"
echo "Architecture: $ARCH"
echo "Binary dir: $BINARY_DIR"
echo ""

mkdir -p "$OUTPUT_DIR"

if [ -x "$UI_BINARY" ] && [ -x "$HEADLESS_BINARY" ]; then
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
        echo "    BINARY_DIR=/path/to/dist/darwin $0 $VERSION $ARCH" >&2
        echo "  expected files: $(basename "$UI_BINARY"), $(basename "$HEADLESS_BINARY")" >&2
        exit 1
    fi

    mkdir -p "$BINARY_DIR"

    echo "Building UI binary with tray (CGO_ENABLED=1)..."
    (cd "$CONSOLE_SRC" && CGO_ENABLED=1 GOOS=darwin GOARCH=$ARCH go build -tags=tray -ldflags "-s -w" -trimpath -o "$UI_BINARY" ./cmd/app)
    echo "  Built: $UI_BINARY"

    echo "Building headless binary with tray (CGO_ENABLED=1)..."
    (cd "$CONSOLE_SRC" && CGO_ENABLED=1 GOOS=darwin GOARCH=$ARCH go build -tags='tray noui' -ldflags "-s -w" -trimpath -o "$HEADLESS_BINARY" ./cmd/app)
    echo "  Built: $HEADLESS_BINARY"
fi

echo ""

# Function to build a PKG
build_pkg() {
    local EDITION="$1"      # "ui" or "headless"
    local BINARY="$2"       # path to binary
    local IDENTIFIER="$3"   # package identifier suffix
    local PKG_NAME="$4"     # output pkg name

    echo "=== Building $EDITION PKG ==="

    # Clean and create build directory
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR/payload/usr/local/device-management-toolkit"
    mkdir -p "$BUILD_DIR/scripts"
    mkdir -p "$BUILD_DIR/resources"

    # Copy binary
    cp "$BINARY" "$BUILD_DIR/payload/usr/local/device-management-toolkit/console"
    chmod 755 "$BUILD_DIR/payload/usr/local/device-management-toolkit/console"

    # Copy and process configuration script
    cp "$SCRIPT_DIR/configure.sh" "$BUILD_DIR/payload/usr/local/device-management-toolkit/configure.sh"
    sed -i '' "s/VERSION_PLACEHOLDER/$VERSION/g" "$BUILD_DIR/payload/usr/local/device-management-toolkit/configure.sh"
    chmod 755 "$BUILD_DIR/payload/usr/local/device-management-toolkit/configure.sh"

    # Copy uninstall script
    cp "$SCRIPT_DIR/uninstall.sh" "$BUILD_DIR/payload/usr/local/device-management-toolkit/uninstall.sh"
    chmod 755 "$BUILD_DIR/payload/usr/local/device-management-toolkit/uninstall.sh"

    # Copy scripts (use edition-specific postinstall)
    cp "$SCRIPT_DIR/scripts/preinstall" "$BUILD_DIR/scripts/"
    cp "$SCRIPT_DIR/scripts/postinstall-$EDITION" "$BUILD_DIR/scripts/postinstall"
    sed -i '' "s/VERSION_PLACEHOLDER/$VERSION/g" "$BUILD_DIR/scripts/postinstall"
    chmod 755 "$BUILD_DIR/scripts/"*

    # Copy and process resources
    cp "$SCRIPT_DIR/resources/"*.html "$BUILD_DIR/resources/"
    cp "$REPO_ROOT/LICENSE" "$BUILD_DIR/resources/license.txt"

    # Set edition-specific conclusion text
    if [ "$EDITION" = "ui" ]; then
        CONCLUSION_TEXT="The web interface will be available at <code>https:\/\/localhost:8181<\/code> by default."
    else
        CONCLUSION_TEXT="Running in headless mode (API only). No web interface is included in this edition."
    fi

    for file in "$BUILD_DIR/resources/"*.html; do
        sed -i '' "s/VERSION_PLACEHOLDER/$VERSION/g" "$file"
        sed -i '' "s/EDITION_CONCLUSION_PLACEHOLDER/$CONCLUSION_TEXT/g" "$file"
    done

    # Process distribution.xml
    sed "s/VERSION_PLACEHOLDER/$VERSION/g" "$SCRIPT_DIR/distribution.xml" > "$BUILD_DIR/distribution.xml"

    # Build component package
    echo "  Building component package..."
    pkgbuild \
        --root "$BUILD_DIR/payload" \
        --scripts "$BUILD_DIR/scripts" \
        --identifier "com.intel.dmt-console-$IDENTIFIER" \
        --version "$VERSION" \
        --install-location "/" \
        "$BUILD_DIR/console.pkg"

    # Build product archive
    echo "  Building product archive..."
    productbuild \
        --distribution "$BUILD_DIR/distribution.xml" \
        --resources "$BUILD_DIR/resources" \
        --package-path "$BUILD_DIR" \
        "$OUTPUT_DIR/$PKG_NAME"

    echo "  Created: $OUTPUT_DIR/$PKG_NAME"
    echo ""

    # Clean up
    rm -rf "$BUILD_DIR"
}

# Build UI PKG (with tray)
build_pkg "ui" "$UI_BINARY" "ui" "console_${VERSION}_macos_${ARCH}.pkg"

# Build Headless PKG
build_pkg "headless" "$HEADLESS_BINARY" "headless" "console_${VERSION}_macos_${ARCH}_headless.pkg"

echo "=== Build Complete ==="
echo ""
echo "Installers created:"
echo "  UI (with system tray): $OUTPUT_DIR/console_${VERSION}_macos_${ARCH}.pkg"
echo "  Headless:              $OUTPUT_DIR/console_${VERSION}_macos_${ARCH}_headless.pkg"
echo ""
echo "After installation:"
echo "  - UI version auto-launches with system tray icon"
echo "  - Headless version: run 'dmt-console' manually"
echo "  - Reconfigure: sudo dmt-configure"
echo "  - Uninstall:   sudo dmt-uninstall"
