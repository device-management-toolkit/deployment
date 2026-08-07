#!/bin/bash
# Device Management Toolkit Console - Uninstall Script
# Copyright (c) Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -e

APP_DIR="/usr/local/device-management-toolkit"
CONFIG_DIR="/Library/Application Support/device-management-toolkit"
CREDS_FILE="$APP_DIR/INITIAL_CREDENTIALS.txt"
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

# Pick the user whose Library/keychain holds the DMT data ($SUDO_USER under sudo, else GUI console user).
resolve_install_user() {
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        echo "$SUDO_USER"
        return
    fi
    stat -f "%Su" /dev/console 2>/dev/null
}

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
echo "  - Configuration: $CONFIG_DIR/"
echo "  - Database:      ~/Library/Application Support/device-management-toolkit/"
echo "  - Encryption key from the user's login keychain"
echo ""
echo "Choosing No preserves $CONFIG_DIR/ (config.yml and anything else there)."
echo "The binary, CLI symlinks, and management scripts are removed in both cases."
echo ""
read -p "Remove all data? [y/N]: " REMOVE_DATA

# Stop any running instance. Match both launch paths (binary and dmt-console symlink).
echo ""
echo "Stopping any running instances..."
pkill -f "$APP_DIR/console" 2>/dev/null || true
pkill -f "/usr/local/bin/dmt-console" 2>/dev/null || true

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
rm -f "$CREDS_FILE"

# DB and encryption key are tied together — removed as a unit when opted in.
if [[ "$REMOVE_DATA" =~ ^[Yy]$ ]]; then
    echo "Removing configuration and data..."
    rm -rf "$CONFIG_DIR"
    rmdir "$APP_DIR" 2>/dev/null || true

    CONSOLE_USER=$(resolve_install_user)
    if [ -n "$CONSOLE_USER" ] && [ "$CONSOLE_USER" != "root" ]; then
        CONSOLE_USER_HOME=$(dscl . -read "/Users/$CONSOLE_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
        if [ -n "$CONSOLE_USER_HOME" ]; then
            USER_DATA_DIR="$CONSOLE_USER_HOME/Library/Application Support/device-management-toolkit"
            if [ -d "$USER_DATA_DIR" ]; then
                echo "Removing user data directory: $USER_DATA_DIR"
                rm -rf "$USER_DATA_DIR"
            fi
        fi

        # Mirror Windows Credential Manager cleanup: drop the encryption key from the user's login keychain.
        if sudo -u "$CONSOLE_USER" security delete-generic-password \
            -s "device-management-toolkit" \
            -a "default-security-key" >/dev/null 2>&1; then
            echo "Removed encryption key from $CONSOLE_USER's login keychain"
        fi
    fi
else
    echo "Keeping configuration at $CONFIG_DIR/ (binary and CLI tools removed)."
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
    echo "Configuration preserved at: $CONFIG_DIR/"
    echo "(The database in ~/Library/Application Support/ and the keychain entry are also untouched.)"
    echo ""
    echo "For a full cleanup, rerun 'sudo dmt-uninstall' and answer 'y' to remove all data."
fi
echo "=============================================="

exit 0
