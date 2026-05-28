#!/bin/sh
# Waits for the stack to answer, then opens the browser at the host IP and
# prints which self-signed certs to accept. Usage: open-app.sh [keycloak]
#
# Both modes serve the app over HTTPS via Kong on :443 with a self-signed cert,
# so the browser warns once. Keycloak mode adds a second cert on :8443 — the
# SPA's silent token fetches fail until that one is accepted too.

# Run from the repo root regardless of where the script is invoked from.
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

MODE=${1:-simple}
IP=$(awk -F= '/^MPS_COMMON_NAME=/{print $2}' .env 2>/dev/null)
[ -z "$IP" ] && IP=localhost

open_url() {
  if   command -v open          >/dev/null 2>&1; then open "$1"                                          # macOS
  elif command -v wslview       >/dev/null 2>&1; then wslview "$1"                                        # WSL (wslu)
  elif command -v xdg-open      >/dev/null 2>&1; then xdg-open "$1" >/dev/null 2>&1                       # Linux
  elif command -v powershell.exe >/dev/null 2>&1; then powershell.exe -NoProfile Start-Process "$1" >/dev/null 2>&1  # WSL fallback
  else return 1; fi
}

wait_for() {  # url — poll up to ~60s
  i=0
  while [ "$i" -lt 60 ]; do
    curl -k -s -o /dev/null --max-time 2 "$1" && return 0
    i=$((i + 1)); sleep 1
  done
  return 1
}

echo
if [ "$MODE" = keycloak ]; then
  echo "[open] waiting for Keycloak at https://$IP:8443/ (first start takes ~30s) ..."
  wait_for "https://$IP:8443/" || echo "[open] Keycloak not up yet — give it a moment, then reload."
  echo "[open] Keycloak mode has TWO self-signed certs — accept BOTH or login will hang:"
  echo "       1. https://$IP:8443/   (Keycloak — accept first, login redirects here)"
  echo "       2. https://$IP/        (the app, via Kong)"
  open_url "https://$IP:8443/" || true
  sleep 1
fi

echo "[open] waiting for the app at https://$IP/ ..."
wait_for "https://$IP/" || echo "[open] app not responding yet — it may still be starting."
echo "[open] App: https://$IP/  (accept the self-signed cert warning)"
open_url "https://$IP/" || echo "[open] couldn't auto-open a browser — open https://$IP/ manually."
