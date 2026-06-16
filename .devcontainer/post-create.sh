#!/bin/bash
set -e

# Unset empty proxy variables
for var in HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy; do
  eval v="\${$var}"
  if [ -z "$v" ]; then unset $var; fi
done

# Strip all trailing '/' or '\\' from proxy URLs for apt config
strip_trailing_slash() {
  local url="$1"
  # Remove all trailing / or \
  url="${url%%*(/|\\)}"
  # Fallback for Bash < 4.0 (no extglob): use sed
  echo "$url" | sed 's%[\\/]*$%%'
}

if [ -n "$HTTP_PROXY" ] || [ -n "$http_proxy" ] || [ -n "$HTTPS_PROXY" ] || [ -n "$https_proxy" ]; then
  echo "Configuring apt to use proxy..."
  sudo mkdir -p /etc/apt/apt.conf.d
  # Remove all trailing / or \\ from proxy URLs
  apt_http_proxy="$(strip_trailing_slash "${HTTP_PROXY:-${http_proxy:-}}")"
  apt_https_proxy="$(strip_trailing_slash "${HTTPS_PROXY:-${https_proxy:-}}")"
  sudo tee /etc/apt/apt.conf.d/99proxy > /dev/null <<EOF
Acquire::http::Proxy "$apt_http_proxy";
Acquire::https::Proxy "$apt_https_proxy";
EOF
fi

sudo apt-get update && sudo apt-get install -y build-essential cmake

go install github.com/air-verse/air@latest
go install github.com/go-delve/delve/cmd/dlv@latest
go install github.com/google/go-licenses@latest