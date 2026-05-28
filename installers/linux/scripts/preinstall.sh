#!/bin/sh
# Device Management Toolkit Console - preinstall scriptlet (deb + rpm)
# Copyright (c) Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
# Refuses downgrades (exit 1 aborts the package op) and stops a running tray
# before files are overwritten. Mirrors the macOS/Windows installers.
#
# @PKG_VERSION@ is substituted with the package version at build time.

set -e

NEW_VERSION="@PKG_VERSION@"

# Refuse to run if the version wasn't stamped (check for a digit, not the
# literal placeholder, which a build-time sed would also rewrite).
case "$NEW_VERSION" in
    *[0-9]*) ;;
    *)
        echo "Error: preinstall was not version-stamped at build time (got '$NEW_VERSION')." >&2
        echo "Build packages via build-packages.sh, which performs the substitution." >&2
        exit 1
        ;;
esac

# Installed version from the package DB under either package name. Empty on a
# fresh install.
installed_version() {
    if command -v dpkg-query >/dev/null 2>&1; then
        for p in dmt-console dmt-console-headless; do
            v=$(dpkg-query -W -f='${Version}' "$p" 2>/dev/null) || v=""
            [ -n "$v" ] && { echo "$v"; return; }
        done
    fi
    if command -v rpm >/dev/null 2>&1; then
        for p in dmt-console dmt-console-headless; do
            v=$(rpm -q --qf '%{VERSION}' "$p" 2>/dev/null) || v=""
            case "$v" in
                ""|*"not installed"*) ;;
                *) echo "$v"; return ;;
            esac
        done
    fi
}

# True when $1 is strictly newer than $2.
version_gt() {
    if command -v dpkg >/dev/null 2>&1; then
        dpkg --compare-versions "$1" gt "$2"
        return
    fi
    [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" = "$1" ]
}

INSTALLED_VERSION=$(installed_version)

if [ -n "$INSTALLED_VERSION" ] && version_gt "$INSTALLED_VERSION" "$NEW_VERSION"; then
    echo "Error: a newer version ($INSTALLED_VERSION) of Console is already installed;" >&2
    echo "refusing to downgrade to $NEW_VERSION. Uninstall first: sudo dmt-uninstall" >&2
    exit 1
fi

# Match by process name so we catch both /usr/bin/dmt-console (package
# autostart) and `dmt-console --tray` launched from PATH.
pkill -x dmt-console >/dev/null 2>&1 || true

exit 0
