#!/bin/sh
# Device Management Toolkit Console - postremove scriptlet (deb + rpm)
# Copyright (c) Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
# On purge (deb) or final erase (rpm), removes the app dir, including the
# runtime-generated config/ and INITIAL_CREDENTIALS.txt that the package itself
# doesn't track.
# Per-user Console state lives under $XDG_CONFIG_HOME (default ~/.config)
# and is left intact; document this in the README the same way the Windows
# uninstaller does.

set -e

PURGE=0
case "$1" in
    purge) PURGE=1 ;;
    0)     PURGE=1 ;;
esac

if [ "$PURGE" = "1" ]; then
    rm -rf /opt/dmt-console
fi

exit 0
