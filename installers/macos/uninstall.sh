#!/bin/bash
# Device Management Toolkit Console - Uninstall Script
# Copyright (c) Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -e

APP_DIR="/usr/local/device-management-toolkit"
SYMLINKS=(
    "/usr/local/bin/dmt-console"
    "/usr/local/bin/dmt-configure"
    "/usr/local/bin/dmt-uninstall"
)

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo dmt-uninstall"
    exit 1
fi

echo "Device Management Toolkit Console Uninstaller"
echo "=============================================="
echo ""

# Check if installed
if [ ! -d "$APP_DIR" ]; then
    echo "DMT Console does not appear to be installed."
    exit 0
fi

# Ask about data preservation
echo "Do you want to remove configuration and data files?"
echo "  - Configuration: $APP_DIR/config/"
echo "  - Data: $APP_DIR/data/"
echo ""
read -p "Remove all data? [y/N]: " REMOVE_DATA

# Stop any running instances
echo ""
echo "Stopping any running instances..."
pkill -x console 2>/dev/null || true

# Remove symlinks
echo "Removing symlinks..."
for link in "${SYMLINKS[@]}"; do
    if [ -L "$link" ]; then
        rm -f "$link"
        echo "  Removed: $link"
    fi
done

# Remove application files
echo "Removing application files..."
rm -f "$APP_DIR/console"
rm -f "$APP_DIR/console_full"
rm -f "$APP_DIR/console_headless"
rm -f "$APP_DIR/configure.sh"
rm -f "$APP_DIR/uninstall.sh"

# Handle data removal
if [[ "$REMOVE_DATA" =~ ^[Yy]$ ]]; then
    echo "Removing configuration and data..."
    rm -rf "$APP_DIR/config"
    rm -rf "$APP_DIR/data"

    # Remove entire directory if empty
    rmdir "$APP_DIR" 2>/dev/null || true

    # Also remove user-specific data
    USER_DATA_DIR="$HOME/Library/Application Support/device-management-toolkit"
    if [ -d "$USER_DATA_DIR" ]; then
        echo "Removing user data directory..."
        rm -rf "$USER_DATA_DIR"
    fi
else
    echo "Keeping configuration and data files at: $APP_DIR/"
fi

# Forget the package receipts (allows clean reinstall)
echo "Removing package receipts..."
pkgutil --forget com.intel.dmt-console-ui 2>/dev/null || true
pkgutil --forget com.intel.dmt-console-headless 2>/dev/null || true

echo ""
echo "=============================================="
echo "DMT Console has been uninstalled."
if [[ ! "$REMOVE_DATA" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Configuration and data preserved at:"
    echo "  $APP_DIR/"
    echo ""
    echo "To completely remove, run:"
    echo "  sudo rm -rf $APP_DIR"
fi
echo "=============================================="

exit 0
