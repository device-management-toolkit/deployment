#!/bin/sh
# Ensures .env exists, auto-detects host LAN IP for MPS_COMMON_NAME, and fills
# any blank password fields with random values.
set -e

# Run from the repo root regardless of where the script is invoked from.
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

ENV_FILE=.env
TPL_FILE=.env.template

if [ ! -f "$ENV_FILE" ]; then
  cp "$TPL_FILE" "$ENV_FILE"
  echo "[bootstrap] created $ENV_FILE from $TPL_FILE"
fi

# Normalize to LF in case the file was checked out with CRLF (e.g. a Windows
# checkout read from WSL). Otherwise values like MPS_COMMON_NAME carry a `\r`
# and the blank-value grep checks below never match.
tr -d '\r' < "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"

# The default-route source IP — the LAN address AMT devices reach this host on
# over CIRA. Has to match the cert; getting this wrong is a common gotcha.
detect_ip() {
  case "$(uname -s)" in
    Darwin)
      iface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
      [ -n "$iface" ] && ipconfig getifaddr "$iface" 2>/dev/null
      ;;
    Linux)
      # WSL sees only the Linux VM's network — ask Windows for its LAN IP
      if grep -qi microsoft /proc/version 2>/dev/null; then
        powershell.exe -NoProfile -Command \
          "(Find-NetRoute -RemoteIPAddress 1.1.1.1)[0].IPAddress" 2>/dev/null | tr -d '\r\n'
      else
        ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}'
      fi
      ;;
  esac
}

set_kv() {
  key=$1; val=$2
  awk -v k="$key" -v v="$val" '
    $0 ~ "^"k"=" { print k"="v; next } { print }
  ' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
}

current=$(awk -F= '/^MPS_COMMON_NAME=/{print $2}' "$ENV_FILE")
if [ -z "$current" ] || [ "$current" = "localhost" ]; then
  ip=$(detect_ip)
  if [ -n "$ip" ]; then
    set_kv MPS_COMMON_NAME "$ip"
    echo "[bootstrap] MPS_COMMON_NAME=$ip (auto-detected)"
  else
    echo "[bootstrap] could not auto-detect IP; leaving MPS_COMMON_NAME=$current"
  fi
fi

# Append a key (blank) if it is absent — an older .env predating new keys won't
# have them, and the blank-value generation below only fills keys that exist.
ensure_kv() {
  key=$1
  grep -q "^${key}=" "$ENV_FILE" || printf '%s=\n' "$key" >> "$ENV_FILE"
}

fill() {
  key=$1
  bytes=${2:-24}
  ensure_kv "$key"
  if grep -q "^${key}=$" "$ENV_FILE"; then
    set_kv "$key" "$(openssl rand -hex "$bytes")"
    echo "[bootstrap] generated $key"
  fi
}

# APP_ENCRYPTION_KEY must be exactly 32 chars — go-wsman-messages casts it to
# []byte for aes.NewCipher (AES-256 wants a 32-byte key). 16 bytes = 32 hex chars.
fill APP_ENCRYPTION_KEY 16
fill AUTH_JWT_KEY
fill AUTH_ADMIN_PASSWORD
fill KEYCLOAK_ADMIN_PASSWORD
fill CONSOLE_USER_PASSWORD
fill POSTGRES_PASSWORD
fill VAULT_TOKEN
