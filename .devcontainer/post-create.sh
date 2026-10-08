#!/bin/bash
set -e

echo "Starting DevContainer post-create setup..."

# Get workspace root (volume mounted from host)
WORKSPACE_ROOT="${PWD}"
TEMPLATE_FILE="$WORKSPACE_ROOT/.env.template"
OUTPUT_FILE="$WORKSPACE_ROOT/.env"
KONG_FILE="$WORKSPACE_ROOT/kong.yaml"
CYPRESS_CONFIG="$WORKSPACE_ROOT/sample-web-ui/cypress.config.ts"
DOCKER_COMPOSE_FILE="$WORKSPACE_ROOT/docker-compose.yml"
README_FILE="$WORKSPACE_ROOT/Readme.md"

# Function to check if setup is already done
is_setup_complete() {
    if [ -f "$OUTPUT_FILE" ] && grep -qE "^MPS_JWT_SECRET=.+$" "$OUTPUT_FILE"; then
        return 0  # Setup is complete
    fi
    return 1  # Setup needed
}

# Function to generate random 32-character string (cross-platform)
generate_random_string() {
    if command -v openssl &> /dev/null; then
        openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | cut -c1-32
    elif [[ -c /dev/urandom ]]; then
        tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32
    elif command -v python3 &> /dev/null; then
        python3 -c "import random; import string; print(''.join(random.choices(string.ascii_letters + string.digits, k=32)))"
    else
        # Fallback: use timestamp
        date +%s%N | sha256sum | tr -dc 'a-zA-Z0-9' | head -c 32
    fi
}

# Function to get the host IP address
get_host_ip() {
    if command -v hostname &> /dev/null; then
        local ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        if [ -n "$ip" ]; then
            echo "$ip"
            return 0
        fi
    fi
    echo "localhost"
}

# Cross-platform sed replacement
sed_replace() {
    local file="$1"
    local pattern="$2"
    local replacement="$3"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|$pattern|$replacement|g" "$file"
    else
        sed -i "s|$pattern|$replacement|g" "$file"
    fi
}

# Function to validate repository
validate_repository() {
    if [ -f "$README_FILE" ] && grep -q "Device Management Toolkit (formerly known as Open AMT Cloud Toolkit)" "$README_FILE"; then
        echo "✓ Detected: Device Management Toolkit repository"
        return 0
    fi
    echo "✗ Error: Unrecognized repository"
    exit 1
}

# Function to generate default values for DMT
generate_defaults() {
    DEFAULT_MPS_COMMON_NAME=$(get_host_ip)
    DEFAULT_MPS_WEB_ADMIN_USER="hspeoob"
    DEFAULT_MPS_WEB_ADMIN_PASSWORD="Apple-1234"
    DEFAULT_MPS_JWT_SECRET=$(generate_random_string)
    DEFAULT_MPS_JWT_ISSUER=$(generate_random_string)
    DEFAULT_POSTGRES_PASSWORD="Apple-1234"
    DEFAULT_VAULT_TOKEN=$(generate_random_string)
}

# Function to populate .env file
populate_env_file() {
    echo "Creating and populating .env file..."
    cp "$TEMPLATE_FILE" "$OUTPUT_FILE"

    sed_replace "$OUTPUT_FILE" "^MPS_COMMON_NAME=.*" "MPS_COMMON_NAME=$DEFAULT_MPS_COMMON_NAME"
    sed_replace "$OUTPUT_FILE" "^MPS_WEB_ADMIN_USER=.*" "MPS_WEB_ADMIN_USER=$DEFAULT_MPS_WEB_ADMIN_USER"
    sed_replace "$OUTPUT_FILE" "^MPS_WEB_ADMIN_PASSWORD=.*" "MPS_WEB_ADMIN_PASSWORD=$DEFAULT_MPS_WEB_ADMIN_PASSWORD"
    sed_replace "$OUTPUT_FILE" "^MPS_JWT_SECRET=.*" "MPS_JWT_SECRET=$DEFAULT_MPS_JWT_SECRET"
    sed_replace "$OUTPUT_FILE" "^MPS_JWT_ISSUER=.*" "MPS_JWT_ISSUER=$DEFAULT_MPS_JWT_ISSUER"
    sed_replace "$OUTPUT_FILE" "^POSTGRES_PASSWORD=.*" "POSTGRES_PASSWORD=$DEFAULT_POSTGRES_PASSWORD"
    sed_replace "$OUTPUT_FILE" "^VAULT_TOKEN=.*" "VAULT_TOKEN=$DEFAULT_VAULT_TOKEN"
    
    echo "✓ .env file has been created and populated"
}

# Function to update kong.yaml
update_kong_config() {
    if [ -f "$KONG_FILE" ]; then
        echo "Updating kong.yaml with JWT secrets..."
        ACTUAL_JWT_SECRET=$(grep "^MPS_JWT_SECRET=" "$OUTPUT_FILE" | cut -d'=' -f2)
        ACTUAL_JWT_ISSUER=$(grep "^MPS_JWT_ISSUER=" "$OUTPUT_FILE" | cut -d'=' -f2)
        
        sed_replace "$KONG_FILE" "key: [a-zA-Z0-9]* #sample key" "key: $ACTUAL_JWT_ISSUER #sample key"
        sed_replace "$KONG_FILE" "secret:.*" "secret: \"$ACTUAL_JWT_SECRET\""
        echo "✓ kong.yaml has been updated"
    else
        echo "⚠ Warning: kong.yaml not found"
    fi
}

# Function to update cypress.config.ts
update_cypress_config() {
    if [ -f "$CYPRESS_CONFIG" ]; then
        echo "Updating cypress.config.ts with credentials..."
        sed_replace "$CYPRESS_CONFIG" "MPS_USERNAME: '.*'" "MPS_USERNAME: '$DEFAULT_MPS_WEB_ADMIN_USER'"
        sed_replace "$CYPRESS_CONFIG" "MPS_PASSWORD: '.*'" "MPS_PASSWORD: '$DEFAULT_MPS_WEB_ADMIN_PASSWORD'"
        sed_replace "$CYPRESS_CONFIG" "VAULT_TOKEN: '.*'" "VAULT_TOKEN: '$DEFAULT_VAULT_TOKEN'"
        echo "✓ cypress.config.ts has been updated"
    else
        echo "⚠ Warning: cypress.config.ts not found"
    fi
}

# Function to update docker-compose.yml
update_docker_compose() {
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        echo "Updating docker-compose.yml with workspace folder variable..."
        sed_replace "$DOCKER_COMPOSE_FILE" "- \\./nginx\\.conf:" "- \${LOCAL_WORKSPACE_FOLDER:-.}/nginx.conf:"
        sed_replace "$DOCKER_COMPOSE_FILE" "- \\./data:" "- \${LOCAL_WORKSPACE_FOLDER:-.}/data:"
        sed_replace "$DOCKER_COMPOSE_FILE" "- \\./kong\\.yaml:" "- \${LOCAL_WORKSPACE_FOLDER:-.}/kong.yaml:"
        sed_replace "$DOCKER_COMPOSE_FILE" "- \\./mosquitto\\.conf:" "- \${LOCAL_WORKSPACE_FOLDER:-.}/mosquitto.conf:"
        echo "✓ docker-compose.yml has been updated"
    else
        echo "⚠ Warning: docker-compose.yml not found"
    fi
}

# Main execution
main() {
    validate_repository
    
    # Check if setup is already done
    if is_setup_complete; then
        echo "✓ Setup already completed. Skipping configuration..."
    else
        echo "Configuration setup required..."
        echo "=========================================="
        echo "Environment Configuration Setup"
        echo "=========================================="
        
        generate_defaults
        populate_env_file
        update_kong_config
        update_cypress_config
        update_docker_compose
        
        echo "=========================================="
        echo "Configuration complete!"
        echo "=========================================="
    fi
}

# Configure apt proxy if needed
for var in HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy; do
  eval v="\${$var}"
  if [ -z "$v" ]; then unset $var; fi
done

strip_trailing_slash() {
  local url="$1"
  echo "$url" | sed 's%[\\/]*$%%'
}

if [ -n "$HTTP_PROXY" ] || [ -n "$http_proxy" ] || [ -n "$HTTPS_PROXY" ] || [ -n "$https_proxy" ]; then
  echo "Configuring apt to use proxy..."
  sudo mkdir -p /etc/apt/apt.conf.d
  apt_http_proxy="$(strip_trailing_slash "${HTTP_PROXY:-${http_proxy:-}}")"
  apt_https_proxy="$(strip_trailing_slash "${HTTPS_PROXY:-${https_proxy:-}}")"
  sudo tee /etc/apt/apt.conf.d/99proxy > /dev/null <<EOF
Acquire::http::Proxy "$apt_http_proxy";
Acquire::https::Proxy "$apt_https_proxy";
EOF
fi

# Run configuration setup
main

# Install build tools and Go tools
echo "Installing build tools..."
sudo apt-get update && sudo apt-get install -y build-essential cmake

echo "Installing Go tools..."
go install github.com/air-verse/air@latest
go install github.com/go-delve/delve/cmd/dlv@latest
go install github.com/google/go-licenses@latest

echo "✓ Post-create setup completed successfully"