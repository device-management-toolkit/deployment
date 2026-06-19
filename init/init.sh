#!/bin/sh
set -e

GEN=/generated
TPL=/templates
HOST=${MPS_COMMON_NAME:-localhost}
REALM_EXPORT_PATH=$GEN/keycloak/realm-export.json
KONG_CONFIG_PATH=$GEN/kong/kong.yaml

mkdir -p "$GEN/keycloak/tls" "$GEN/keycloak" "$GEN/kong"

normalize_output_path() {
  output_path=$1

  if [ -d "$output_path" ]; then
    rmdir "$output_path" 2>/dev/null || rm -rf "$output_path"
  fi
}

normalize_output_path "$REALM_EXPORT_PATH"
normalize_output_path "$KONG_CONFIG_PATH"

if [ ! -f "$GEN/keycloak/tls/tls.crt" ]; then
  # An IPv4 literal must go in an IP SAN, not a DNS SAN — and the auto-detected
  # MPS_COMMON_NAME is usually a LAN IP.
  case "$HOST" in
    *[!0-9.]*) HOST_SAN="DNS:$HOST" ;;
    *)         HOST_SAN="IP:$HOST" ;;
  esac
  echo "[init] generating Keycloak TLS cert (CN=$HOST)"
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -subj "/CN=$HOST" \
    -addext "subjectAltName=$HOST_SAN,DNS:keycloak,DNS:localhost,IP:127.0.0.1" \
    -keyout "$GEN/keycloak/tls/tls.key" \
    -out "$GEN/keycloak/tls/tls.crt" 2>/dev/null
fi

chmod 644 "$GEN/keycloak/tls/tls.key" "$GEN/keycloak/tls/tls.crt"

if [ ! -f "$REALM_EXPORT_PATH" ] || [ ! -f "$KONG_CONFIG_PATH" ]; then
  echo "[init] generating token signing keypair and templating configs"
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -subj "/CN=keycloak-token-signer" \
    -keyout /tmp/sign.key -out /tmp/sign.crt 2>/dev/null

  PRIV=$(openssl pkcs8 -topk8 -nocrypt -in /tmp/sign.key -outform DER | base64 | tr -d '\n')
  CERT=$(openssl x509 -in /tmp/sign.crt -outform DER | base64 | tr -d '\n')
  PUB_INDENTED=$(openssl x509 -in /tmp/sign.crt -pubkey -noout | sed 's/^/      /')
  TENANT_HEADER=${KONG_TENANT_HEADER_VALUE:-}

  PASS=${CONSOLE_USER_PASSWORD:-}
  [ -z "$PASS" ] && echo "[init] WARNING: CONSOLE_USER_PASSWORD is empty; run scripts/bootstrap-env.sh or set it in .env"

  awk -v priv="$PRIV" -v cert="$CERT" -v host="$HOST" -v pass="$PASS" '
    { gsub(/__SIGNING_PRIVATE_KEY__/, priv);
      gsub(/__SIGNING_CERTIFICATE__/, cert);
      gsub(/__CONSOLE_USER_PASSWORD__/, pass);
      gsub(/__MPS_COMMON_NAME__/, host);
      print }
  ' "$TPL/realm-export.json.tpl" > "$REALM_EXPORT_PATH"

  awk -v pub="$PUB_INDENTED" -v host="$HOST" -v tenant_header="$TENANT_HEADER" '
    /# BEGIN_TENANT_HEADER_PLUGIN/ { skip = (tenant_header == ""); next }
    /# END_TENANT_HEADER_PLUGIN/ { skip = 0; next }
    skip { next }
    { gsub(/__KEYCLOAK_PUBKEY__/, pub);
      gsub(/__MPS_COMMON_NAME__/, host);
      gsub(/\$\{KONG_TENANT_HEADER_VALUE\}/, tenant_header);
      print }
  ' "$TPL/kong.yaml.tpl" > "$KONG_CONFIG_PATH"

  rm -f /tmp/sign.key /tmp/sign.crt
fi

echo "[init] done"
