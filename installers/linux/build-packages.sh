#!/bin/bash
# Device Management Toolkit Console - Linux deb/rpm build script
# Copyright (c) Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
# Builds four packages: UI + headless, each as .deb and .rpm. Both binaries
# include the system tray (matches macOS PKG and Windows NSIS).
#
# Requires:
#   - nfpm  - go install github.com/goreleaser/nfpm/v2/cmd/nfpm@latest
#   - gcc + libgtk-3-dev + libayatana-appindicator3-dev  (when building from source)

set -e

VERSION="${1:-0.0.0}"
ARCH="${2:-amd64}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/dist/linux"
STAGE_DIR="$SCRIPT_DIR/build"

CONSOLE_SRC="$REPO_ROOT/services/console"
WEBUI_SRC="$REPO_ROOT/services/sample-web-ui"
UI_EMBED_DIR="$CONSOLE_SRC/internal/controller/httpapi/ui"
BINARY_DIR="${BINARY_DIR:-$OUTPUT_DIR}"
UI_BINARY="$BINARY_DIR/console_linux_${ARCH}_tray"
HEADLESS_BINARY="$BINARY_DIR/console_linux_${ARCH}_headless_tray"

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

echo "Building Linux deb/rpm packages..."
echo "Version: $VERSION"
echo "Architecture: $ARCH"
echo "Binary dir: $BINARY_DIR"
echo ""

if [ "$ARCH" != "amd64" ]; then
    echo "Error: only amd64 is supported in v1." >&2
    exit 1
fi

if ! command -v nfpm >/dev/null 2>&1; then
    echo "Error: nfpm not found on PATH" >&2
    echo "Install with: go install github.com/goreleaser/nfpm/v2/cmd/nfpm@latest" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR" "$STAGE_DIR"

if [ -x "$UI_BINARY" ] && [ -x "$HEADLESS_BINARY" ]; then
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
        echo "    BINARY_DIR=/path/to/dist/linux $0 $VERSION $ARCH" >&2
        echo "  expected files: $(basename "$UI_BINARY"), $(basename "$HEADLESS_BINARY")" >&2
        exit 1
    fi

    mkdir -p "$BINARY_DIR"

    build_web_ui

    echo "Building UI binary with tray (CGO_ENABLED=1)..."
    (cd "$CONSOLE_SRC" && CGO_ENABLED=1 GOOS=linux GOARCH=amd64 \
        go build -tags=tray -ldflags "-s -w" -trimpath -o "$UI_BINARY" ./cmd/app)
    echo "  Built: $UI_BINARY"

    echo "Building headless binary with tray (CGO_ENABLED=1, -tags='tray noui')..."
    (cd "$CONSOLE_SRC" && CGO_ENABLED=1 GOOS=linux GOARCH=amd64 \
        go build -tags='tray noui' -ldflags "-s -w" -trimpath -o "$HEADLESS_BINARY" ./cmd/app)
    echo "  Built: $HEADLESS_BINARY"
fi

cp "$UI_BINARY" "$STAGE_DIR/console_linux_x64_tray"
cp "$HEADLESS_BINARY" "$STAGE_DIR/console_linux_x64_headless_tray"
chmod 0755 "$STAGE_DIR/console_linux_x64_tray" "$STAGE_DIR/console_linux_x64_headless_tray"

# Stamp the package version into the preinstall scriptlet (downgrade hard-stop).
sed "s/@PKG_VERSION@/$VERSION/g" "$SCRIPT_DIR/scripts/preinstall.sh" > "$STAGE_DIR/preinstall.sh"
chmod 0755 "$STAGE_DIR/preinstall.sh"

export VERSION

build_one() {
    local manifest="$1"
    local packager="$2"
    echo ""
    echo "=== nfpm pkg $manifest ($packager) ==="
    (cd "$SCRIPT_DIR" && nfpm pkg \
        --config "$manifest" \
        --packager "$packager" \
        --target "$OUTPUT_DIR/")
}

build_one nfpm.ui.yaml deb
build_one nfpm.ui.yaml rpm
build_one nfpm.headless.yaml deb
build_one nfpm.headless.yaml rpm

cd "$OUTPUT_DIR"
RENAME_PAIRS=(
    "dmt-console_${VERSION}_amd64.deb|console_${VERSION}_linux_amd64.deb"
    "dmt-console-${VERSION}-1.x86_64.rpm|console_${VERSION}_linux_amd64.rpm"
    "dmt-console-headless_${VERSION}_amd64.deb|console_${VERSION}_linux_amd64_headless.deb"
    "dmt-console-headless-${VERSION}-1.x86_64.rpm|console_${VERSION}_linux_amd64_headless.rpm"
)
for pair in "${RENAME_PAIRS[@]}"; do
    src="${pair%%|*}"
    dst="${pair##*|}"
    if [ -f "$src" ]; then
        mv -f "$src" "$dst"
        echo "Renamed: $src -> $dst"
    else
        echo "Warning: expected output not found: $src" >&2
    fi
done

echo ""
echo "=== Done ==="
ls -lh "$OUTPUT_DIR"/console_${VERSION}_linux_amd64*.deb "$OUTPUT_DIR"/console_${VERSION}_linux_amd64*.rpm 2>/dev/null || true
