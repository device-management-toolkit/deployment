#!/bin/sh
# Device Management Toolkit Console - preremove scriptlet (deb + rpm)
# Copyright (c) Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
# Kills any running tray instance before files are removed. Runs on both
# remove and upgrade (postinstall relaunches the tray after upgrade).

set -e

pkill -x dmt-console >/dev/null 2>&1 || true

exit 0
