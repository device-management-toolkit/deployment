#!/bin/sh
# Device Management Toolkit Console - postinstall scriptlet (deb + rpm)
# Copyright (c) Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
# Tray-mode install (mirrors macOS PKG postinstall):
#   - on first install: generate /etc/dmt-console/config/config.yml with a random JWT,
#     encryption key, and admin password; write INITIAL_CREDENTIALS.txt
#   - auto-launch `dmt-console --tray` as the detected desktop user (if any)
#   - XDG autostart entry (shipped under /etc/xdg/autostart/) handles future
#     logins; no systemd service.

set -e

APP_DIR=/opt/dmt-console
# Machine-wide seed, world-readable like %ProgramData% on Windows, so every
# user's tray seeds the same credentials. Per-user copy stays owner-only.
CONFIG_DIR=/etc/dmt-console/config
CONFIG_FILE="$CONFIG_DIR/config.yml"
TEMPLATE=/usr/share/dmt-console/config.yml.tmpl

# Detect packager. deb = verb in $1, rpm = integer in $1.
case "$1" in
    configure|abort-upgrade|abort-remove|abort-deconfigure)
        DEB=1
        ;;
    *)
        DEB=0
        ;;
esac

FIRST_INSTALL=0
if [ "$DEB" = "1" ]; then
    [ -z "$2" ] && FIRST_INSTALL=1
else
    [ "$1" = "1" ] && FIRST_INSTALL=1
fi

# Detect the desktop user, mirroring macOS's resolve_install_user but using
# Linux idioms. apt/dpkg sets SUDO_USER when run via sudo; loginctl is the
# fallback for non-sudo invocations.
detect_gui_user() {
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        echo "$SUDO_USER"
        return
    fi
    if command -v loginctl >/dev/null 2>&1; then
        loginctl list-sessions --no-legend 2>/dev/null | \
            awk '$3 != "" && $3 != "root" {print $3; exit}'
        return
    fi
    who 2>/dev/null | awk '$1 != "root" {print $1; exit}'
}

CONSOLE_USER=$(detect_gui_user)

if [ "$FIRST_INSTALL" = "1" ] && [ ! -f "$CONFIG_FILE" ]; then
    JWT=$(openssl rand -hex 32)
    # 24 bytes -> 32-char base64, used directly as a 32-byte AES-256 key
    # (aes.NewCipher rejects any other length). Matches the binary's GenerateKey.
    ENC_KEY=$(openssl rand -base64 24)
    ADMIN_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)
    ADMIN_USER=standalone

    umask 077
    install -d -m 0755 "$CONFIG_DIR"

    sed -e "s|@JWT@|$JWT|" \
        -e "s|@ENC_KEY@|$ENC_KEY|" \
        -e "s|@ADMIN_USER@|$ADMIN_USER|" \
        -e "s|@ADMIN_PASS@|$ADMIN_PASS|" \
        -e "s|@PORT@|8181|" \
        -e "s|@TLS@|true|" \
        -e "s|@VERSION@|installed|" \
        "$TEMPLATE" > "$CONFIG_FILE"
    # World-readable, root-owned seed (POSIX analog of %ProgramData%): every
    # user's tray reads it to seed its own owner-only copy.
    chmod 0644 "$CONFIG_FILE"

    # Initial credentials file. Stash in the app dir and chown to the desktop
    # user so they can read it without sudo.
    CREDS_FILE="$APP_DIR/INITIAL_CREDENTIALS.txt"
    cat > "$CREDS_FILE" <<CREDS
Device Management Toolkit Console - Initial Credentials
========================================================
These credentials were generated at install time. Change them with
\`dmt-configure\` and delete this file once recorded.

  Username: $ADMIN_USER
  Password: $ADMIN_PASS
CREDS
    chmod 0600 "$CREDS_FILE"
    if [ -n "$CONSOLE_USER" ]; then
        chown "$CONSOLE_USER" "$CREDS_FILE" 2>/dev/null || true
    fi

    echo ""
    echo "======================================================="
    echo "Device Management Toolkit Console installed."
    echo "Initial admin credentials saved to:"
    echo "  $CREDS_FILE"
    echo "Read with:    cat $CREDS_FILE   (sudo if not the desktop user)"
    echo "Reconfigure:  dmt-configure   (sudo only on server installs with no desktop user)"
    echo "======================================================="
fi

# Auto-launch the tray for the detected desktop user, mirroring macOS.
# Skip if no GUI user (server install) or no $DISPLAY/$WAYLAND_DISPLAY in
# the target session.
if [ -n "$CONSOLE_USER" ] && [ "$CONSOLE_USER" != "root" ]; then
    USER_UID=$(id -u "$CONSOLE_USER" 2>/dev/null || true)
    if [ -n "$USER_UID" ] && [ -d "/run/user/$USER_UID" ]; then
        echo "Launching dmt-console --tray as $CONSOLE_USER..."
        # Carry DISPLAY/WAYLAND_DISPLAY (for the tray's xdg-open) plus the
        # session bus. Harvest from the user's systemd --user env, falling back
        # to logind's Display. Errors are non-fatal.
        SESSION_ENV=$(su - "$CONSOLE_USER" -c \
            "XDG_RUNTIME_DIR=/run/user/$USER_UID systemctl --user show-environment 2>/dev/null" 2>/dev/null)
        GUI_DISPLAY=$(printf '%s\n' "$SESSION_ENV" | sed -n 's/^DISPLAY=//p' | head -n1)
        GUI_WAYLAND=$(printf '%s\n' "$SESSION_ENV" | sed -n 's/^WAYLAND_DISPLAY=//p' | head -n1)
        if [ -z "$GUI_DISPLAY" ] && [ -z "$GUI_WAYLAND" ]; then
            GUI_SESSION=$(loginctl show-user "$CONSOLE_USER" -p Display --value 2>/dev/null)
            [ -n "$GUI_SESSION" ] && \
                GUI_DISPLAY=$(loginctl show-session "$GUI_SESSION" -p Display --value 2>/dev/null)
        fi
        su - "$CONSOLE_USER" -c "
            export XDG_RUNTIME_DIR=/run/user/$USER_UID
            export DBUS_SESSION_BUS_ADDRESS=\"unix:path=\$XDG_RUNTIME_DIR/bus\"
            ${GUI_DISPLAY:+export DISPLAY='$GUI_DISPLAY'}
            ${GUI_WAYLAND:+export WAYLAND_DISPLAY='$GUI_WAYLAND'}
            nohup /usr/bin/dmt-console --tray >/dev/null 2>&1 &
        " >/dev/null 2>&1 || true
    else
        echo "No active graphical session for $CONSOLE_USER."
        echo "Run 'dmt-console --tray' from a desktop session to start the tray."
    fi
else
    echo "No desktop user detected. Run 'dmt-console --tray' as your user once logged in."
    echo "(XDG autostart will pick it up at next login.)"
fi

exit 0
