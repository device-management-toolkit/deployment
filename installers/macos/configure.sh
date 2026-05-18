#!/bin/bash
# Device Management Toolkit Console - Configuration Script
# Copyright (c) Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -e

APP_DIR="/usr/local/device-management-toolkit"
CONFIG_FILE="$APP_DIR/config/config.yml"
VERSION="VERSION_PLACEHOLDER"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}=================================================="
echo "Device Management Toolkit Console Configuration"
echo -e "==================================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo dmt-configure)${NC}"
    exit 1
fi

# Function to prompt with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local result

    read -p "$prompt [$default]: " result
    echo "${result:-$default}"
}

# Function to prompt yes/no
prompt_yes_no() {
    local prompt="$1"
    local default="$2"
    local result

    # Validation goes to stderr so command substitution captures only the answer.
    while true; do
        read -p "$prompt (y/n) [$default]: " result
        result="${result:-$default}"
        case "$result" in
            [Yy]* ) echo "true"; return;;
            [Nn]* ) echo "false"; return;;
            * ) echo "Please answer y or n." >&2;;
        esac
    done
}

# YAML-escape a value for use inside a double-quoted scalar.
yaml_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

echo -e "${YELLOW}Step 1: Network Configuration${NC}"
echo ""

while :; do
    HTTP_PORT=$(prompt_with_default "HTTP Port" "8181")
    # Must be an integer in the TCP port range (matches Windows ValidatePort).
    if [[ "$HTTP_PORT" =~ ^[0-9]+$ ]] && [ "$HTTP_PORT" -ge 1 ] && [ "$HTTP_PORT" -le 65535 ]; then
        break
    fi
    echo -e "${RED}Port must be a number between 1 and 65535.${NC}"
done

TLS_ENABLED=$(prompt_yes_no "Enable TLS/HTTPS (recommended)" "y")
if [ "$TLS_ENABLED" = "true" ]; then
    echo "  A self-signed certificate will be generated if none is provided."
fi

echo ""
echo -e "${YELLOW}Step 2: Administrator Credentials${NC}"
echo "  (Used for standalone authentication)"
echo ""

while :; do
    ADMIN_USERNAME=$(prompt_with_default "Admin Username" "standalone")
    # Strip whitespace and reject empty (matches Windows non-empty check).
    if [ -n "${ADMIN_USERNAME// /}" ]; then
        break
    fi
    echo -e "${RED}Administrator username is required.${NC}"
done

while :; do
    read -s -p "Admin Password (min 8 chars): " ADMIN_PASSWORD
    echo ""
    if [ "${#ADMIN_PASSWORD}" -lt 8 ]; then
        echo -e "${RED}Password must be at least 8 characters.${NC}"
        continue
    fi
    read -s -p "Confirm Admin Password: " ADMIN_PASSWORD_CONFIRM
    echo ""
    if [ "$ADMIN_PASSWORD" != "$ADMIN_PASSWORD_CONFIRM" ]; then
        echo -e "${RED}Passwords do not match.${NC}"
        continue
    fi
    break
done

# Drop any inherited JWT_KEY env var before deciding whether to keep/generate one.
JWT_KEY=""
if [ -f "$CONFIG_FILE" ]; then
    JWT_KEY=$(awk '/^[[:space:]]*jwtKey:/ {print $2; exit}' "$CONFIG_FILE")
fi
if [ -z "$JWT_KEY" ] || [ "$JWT_KEY" = "your_secret_jwt_key" ]; then
    JWT_KEY=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 48)
fi

echo ""
echo -e "${YELLOW}Configuration Summary${NC}"
echo "  Port:       $HTTP_PORT"
echo "  TLS:        $TLS_ENABLED"
echo "  Username:   $ADMIN_USERNAME"
echo "  Password:   ********"
echo ""

read -p "Apply this configuration? (y/n) [y]: " confirm
confirm="${confirm:-y}"

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Configuration cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}Applying configuration...${NC}"

# Escape backslash and double-quote for YAML double-quoted scalars.
ADMIN_USERNAME_YAML=$(yaml_escape "$ADMIN_USERNAME")
ADMIN_PASSWORD_YAML=$(yaml_escape "$ADMIN_PASSWORD")

# Generate config file
cat > "$CONFIG_FILE" << EOF
app:
  name: console
  repo: device-management-toolkit/console
  version: $VERSION
  encryption_key: ""
  allow_insecure_ciphers: false
http:
  host: localhost
  port: "$HTTP_PORT"
  ws_compression: false
  tls:
    enabled: $TLS_ENABLED
    certFile: ""
    keyFile: ""
  allowed_origins:
    - "*"
  allowed_headers:
    - "*"
logger:
  log_level: info
secrets:
  address: http://localhost:8200
  token: ""
postgres:
  pool_max: 2
  url: ""
ea:
  url: http://localhost:8000
  username: ""
  password: ""
auth:
  disabled: false
  adminUsername: "$ADMIN_USERNAME_YAML"
  adminPassword: "$ADMIN_PASSWORD_YAML"
  jwtKey: $JWT_KEY
  jwtExpiration: 24h0m0s
  redirectionJWTExpiration: 5m0s
  clientId: ""
  issuer: ""
  ui:
    clientId: ""
    issuer: ""
    scope: ""
    redirectUri: ""
    responseType: "code"
    requireHttps: false
    strictDiscoveryDocumentValidation: true
ui:
  externalUrl: ""
EOF

# Restrict config to root (contains secrets)
chmod 600 "$CONFIG_FILE"
echo "  Configuration saved to $CONFIG_FILE"

# Restart the console if it's running. Match both launch paths (binary and dmt-console symlink).
WAS_RUNNING=false
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    CONSOLE_USER="$SUDO_USER"
else
    CONSOLE_USER=$(stat -f "%Su" /dev/console)
fi
if pgrep -f "$APP_DIR/console" > /dev/null 2>&1 || pgrep -f "/usr/local/bin/dmt-console" > /dev/null 2>&1; then
    WAS_RUNNING=true
    echo "  Stopping running instance..."
    pkill -f "$APP_DIR/console" 2>/dev/null || true
    pkill -f "/usr/local/bin/dmt-console" 2>/dev/null || true
    sleep 2

    if [ -n "$CONSOLE_USER" ] && [ "$CONSOLE_USER" != "root" ]; then
        echo "  Restarting DMT Console for user: $CONSOLE_USER"
        sudo -u "$CONSOLE_USER" nohup "$APP_DIR/console" --tray > /dev/null 2>&1 &
        sleep 1
    fi
fi

echo ""
echo -e "${GREEN}=================================================="
echo "Configuration complete!"
echo -e "==================================================${NC}"
echo ""

SCHEME="http"
if [ "$TLS_ENABLED" = "true" ]; then
    SCHEME="https"
fi

if [ "$WAS_RUNNING" = true ] && { pgrep -f "$APP_DIR/console" > /dev/null 2>&1 || pgrep -f "/usr/local/bin/dmt-console" > /dev/null 2>&1; }; then
    echo "DMT Console has been restarted with the new configuration."
else
    echo "To start the console:"
    echo "  dmt-console --tray"
fi
echo ""
echo "Access the web interface at:"
echo "  $SCHEME://localhost:$HTTP_PORT"
echo ""
