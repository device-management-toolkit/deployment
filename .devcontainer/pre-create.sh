#!/bin/bash

# This script runs on the host machine BEFORE the container is created.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TEMPLATE_FILE="$REPO_ROOT/.env.template"
OUTPUT_FILE="$REPO_ROOT/.env"
KONG_FILE="$REPO_ROOT/kong.yaml"
CYPRESS_CONFIG="$REPO_ROOT/sample-web-ui/cypress.config.ts"
DOCKER_COMPOSE_FILE="$REPO_ROOT/docker-compose.yml"
README_FILE="$REPO_ROOT/Readme.md"
REPO_TYPE=""

# Function to validate repository
validate_repository() {
    if [ -f "$README_FILE" ] && grep -q "Device Management Toolkit (formerly known as Open AMT Cloud Toolkit)" "$README_FILE"; then
        REPO_TYPE="DMT"
        echo "✓ Detected: Device Management Toolkit repository"
        return 0
    fi

    echo "✗ Error: Unrecognized repository. This script must be run from the Device Management Toolkit repository."
    exit 1
}

# Function to handle DMT-specific operations
dmt_operations() {
    echo "=========================================="
    echo "Environment Configuration Setup"
    echo "=========================================="

    dmt_generate_defaults
    dmt_populate_env_file
    dmt_update_kong_config
    dmt_update_cypress_config
    dmt_update_docker_compose

    echo "=========================================="
    echo "Configuration complete!"
    echo "=========================================="
}

# Function to generate default values for DMT
dmt_generate_defaults() {
    DEFAULT_MPS_COMMON_NAME=$(hostname -I | awk '{print $1}')  # Automatically detected system IP address
    DEFAULT_MPS_WEB_ADMIN_USER="hspeoob"                      # Default admin username for MPS web interface
    DEFAULT_MPS_WEB_ADMIN_PASSWORD="Apple-1234"               # Default admin password for MPS web interface
    DEFAULT_MPS_JWT_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)  # Randomly generated 32-char JWT secret
    DEFAULT_MPS_JWT_ISSUER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)  # Randomly generated 32-char JWT issuer key
    DEFAULT_POSTGRES_PASSWORD="Apple-1234"                    # Default PostgreSQL database password
    DEFAULT_VAULT_TOKEN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)     # Randomly generated 32-char Vault token
}

# Function to populate .env file for DMT
dmt_populate_env_file() {
    if [ -f "$OUTPUT_FILE" ] && grep -qE "^MPS_JWT_SECRET=.+$" "$OUTPUT_FILE"; then
        echo "✓ Existing .env with MPS_JWT_SECRET found; skipping .env generation."
        return 0
    fi

    echo "Creating and populating .env file..."
    cp "$TEMPLATE_FILE" "$OUTPUT_FILE"

    sed -i "s|^MPS_COMMON_NAME=.*|MPS_COMMON_NAME=$DEFAULT_MPS_COMMON_NAME|" "$OUTPUT_FILE"
    sed -i "s|^MPS_WEB_ADMIN_USER=.*|MPS_WEB_ADMIN_USER=$DEFAULT_MPS_WEB_ADMIN_USER|" "$OUTPUT_FILE"
    sed -i "s|^MPS_WEB_ADMIN_PASSWORD=.*|MPS_WEB_ADMIN_PASSWORD=$DEFAULT_MPS_WEB_ADMIN_PASSWORD|" "$OUTPUT_FILE"
    sed -i "s|^MPS_JWT_SECRET=.*|MPS_JWT_SECRET=$DEFAULT_MPS_JWT_SECRET|" "$OUTPUT_FILE"
    sed -i "s|^MPS_JWT_ISSUER=.*|MPS_JWT_ISSUER=$DEFAULT_MPS_JWT_ISSUER|" "$OUTPUT_FILE"
    sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$DEFAULT_POSTGRES_PASSWORD|" "$OUTPUT_FILE"
    sed -i "s|^VAULT_TOKEN=.*|VAULT_TOKEN=$DEFAULT_VAULT_TOKEN|" "$OUTPUT_FILE"

    echo "✓ .env file has been created and populated with default values."
}

# Function to update kong.yaml for DMT
dmt_update_kong_config() {
    if [ -f "$KONG_FILE" ]; then
        # Check if MPS_JWT_SECRET in .env is empty
        if grep -qE "^MPS_JWT_SECRET=.+$" "$OUTPUT_FILE"; then
            echo "Updating kong.yaml with JWT secrets..."
            # Read the actual values from .env file
            ACTUAL_JWT_SECRET=$(grep "^MPS_JWT_SECRET=" "$OUTPUT_FILE" | cut -d'=' -f2)
            ACTUAL_JWT_ISSUER=$(grep "^MPS_JWT_ISSUER=" "$OUTPUT_FILE" | cut -d'=' -f2)

            sed -i "s|key: [a-zA-Z0-9]* #sample key|key: $ACTUAL_JWT_ISSUER #sample key|" "$KONG_FILE"
            sed -i -E "s|^(\s*secret:)\s*.*$|\1 \"$ACTUAL_JWT_SECRET\"|" "$KONG_FILE"
            echo "✓ kong.yaml has been updated with JWT secrets."
        else
            echo "⚠ Warning: MPS_JWT_SECRET in .env is empty, skipping Kong configuration."
        fi
    else
        echo "⚠ Warning: kong.yaml not found, skipping Kong configuration."
    fi
}

# Function to update cypress.config.ts for DMT
dmt_update_cypress_config() {
    if [ -f "$CYPRESS_CONFIG" ]; then
        echo "Updating cypress.config.ts with credentials..."
        sed -i "s|MPS_USERNAME: '.*'|MPS_USERNAME: '$DEFAULT_MPS_WEB_ADMIN_USER'|" "$CYPRESS_CONFIG"
        sed -i "s|MPS_PASSWORD: '.*'|MPS_PASSWORD: '$DEFAULT_MPS_WEB_ADMIN_PASSWORD'|" "$CYPRESS_CONFIG"
        sed -i "s|VAULT_TOKEN: '.*'|VAULT_TOKEN: '$DEFAULT_VAULT_TOKEN'|" "$CYPRESS_CONFIG"
        echo "✓ cypress.config.ts has been updated with credentials."
    else
        echo "⚠ Warning: cypress.config.ts not found, skipping Cypress configuration."
    fi
}

# Function to update docker-compose.yml with proxy and workspace folder
dmt_update_docker_compose() {
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        echo "Updating docker-compose.yml with workspace folder variable..."

        # Replace relative volume paths with ${LOCAL_WORKSPACE_FOLDER:-.} literal variable reference
        sed -i 's|- \./nginx\.conf:|- ${LOCAL_WORKSPACE_FOLDER:-.}/nginx.conf:|' "$DOCKER_COMPOSE_FILE"
        sed -i 's|- \./data:|- ${LOCAL_WORKSPACE_FOLDER:-.}/data:|' "$DOCKER_COMPOSE_FILE"
        sed -i 's|- \./kong\.yaml:|- ${LOCAL_WORKSPACE_FOLDER:-.}/kong.yaml:|' "$DOCKER_COMPOSE_FILE"
        sed -i 's|- \./mosquitto\.conf:|- ${LOCAL_WORKSPACE_FOLDER:-.}/mosquitto.conf:|' "$DOCKER_COMPOSE_FILE"
        echo "  ✓ Volume paths updated with \${LOCAL_WORKSPACE_FOLDER:-.}"

        # Update proxy environment variables from host system
        HTTP_PROXY="${HTTP_PROXY:-}"
        HTTPS_PROXY="${HTTPS_PROXY:-}"
        NO_PROXY="${NO_PROXY:-}"
        http_proxy="${http_proxy:-}"
        https_proxy="${https_proxy:-}"
        no_proxy="${no_proxy:-}"

        if [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ] || [ -n "$NO_PROXY" ]; then
            echo "  Configuring HTTP proxy: $HTTP_PROXY"
            echo "  Configuring HTTPS proxy: $HTTPS_PROXY"
            echo "  Configuring NO_PROXY: $NO_PROXY"
        fi

        # Note: The proxy settings are already parameterized in docker-compose.yml
        # They will be picked up from the environment when docker-compose runs
        echo "✓ docker-compose.yml has been updated with workspace folder and proxy settings."
    else
        echo "⚠ Warning: docker-compose.yml not found, skipping Docker Compose configuration."
    fi
}

# Main execution
main() {
    validate_repository

    if [ "$REPO_TYPE" = "DMT" ]; then
        dmt_operations
    fi
}

# Run main function
main REPO_TYPE="DMT"