#!/bin/sh
# ==============================================================================
# Description: Prometheus entrypoint script that generates prometheus.yml from
#   template with optional remote_write configuration based on environment
#   variables.
# Author: Infrastructure Team
# Usage: Called as entrypoint in docker-compose.yml for prometheus service
# Dependencies: promtool for config validation
# ==============================================================================

set -e

# Configuration - use environment variables with defaults for container paths
TEMPLATE_FILE="${PROMETHEUS_TEMPLATE_FILE:-/etc/prometheus/prometheus.yml.tmpl}"
OUTPUT_FILE="${PROMETHEUS_CONFIG_FILE:-/etc/prometheus/prometheus.yml}"

# For local testing, allow override
if [ -n "$TEST_MODE" ]; then
    TEMPLATE_FILE="./prometheus.yml.tmpl"
    OUTPUT_FILE="./prometheus.yml.generated"
fi

# Parse REMOTE_WRITE_URL and related variables
REMOTE_WRITE_URL="${REMOTE_WRITE_URL:-}"

# If no remote write URL, generate config without remote_write section
if [ -z "$REMOTE_WRITE_URL" ]; then
    echo "No REMOTE_WRITE_URL set, generating config without remote_write"
    # Extract everything before the remote_write template block
    awk '/^{{.*if .RemoteWriteURL/ {exit} {print}' "$TEMPLATE_FILE" > "$OUTPUT_FILE"
else
    echo "REMOTE_WRITE_URL set, generating config with remote_write"
    
    # Build remote_write YAML block
    REMOTE_WRITE_YAML="remote_write:\n  - url: \"$REMOTE_WRITE_URL\""
    
    # Add custom headers if provided (excluding Authorization which uses dedicated fields)
    if [ -n "$REMOTE_WRITE_HEADER_CONTENT_TYPE" ] || [ -n "$REMOTE_WRITE_HEADER_CUSTOM" ]; then
        REMOTE_WRITE_YAML="$REMOTE_WRITE_YAML\n    headers:"
        if [ -n "$REMOTE_WRITE_HEADER_CONTENT_TYPE" ]; then
            REMOTE_WRITE_YAML="$REMOTE_WRITE_YAML\n      Content-Type: \"$REMOTE_WRITE_HEADER_CONTENT_TYPE\""
        fi
        if [ -n "$REMOTE_WRITE_HEADER_CUSTOM" ]; then
            # Allow custom headers in format "Key: Value"
            echo "$REMOTE_WRITE_HEADER_CUSTOM" | while IFS=',' read -ra HEADERS; do
                for h in "${HEADERS[@]}"; do
                    key=$(echo "$h" | cut -d: -f1 | xargs)
                    value=$(echo "$h" | cut -d: -f2- | xargs)
                    if [ -n "$key" ] && [ -n "$value" ]; then
                        REMOTE_WRITE_YAML="$REMOTE_WRITE_YAML\n      $key: \"$value\""
                    fi
                done
            done
        fi
    fi
    
    # Add authorization (Bearer token) if provided
    if [ -n "$REMOTE_WRITE_AUTHORIZATION" ]; then
        REMOTE_WRITE_YAML="$REMOTE_WRITE_YAML\n    authorization:\n      type: \"Bearer\"\n      credentials: \"$REMOTE_WRITE_AUTHORIZATION\""
    fi
    
    # Add basic auth if provided
    if [ -n "$REMOTE_WRITE_BASIC_AUTH_USER" ] && [ -n "$REMOTE_WRITE_BASIC_AUTH_PASSWORD" ]; then
        REMOTE_WRITE_YAML="$REMOTE_WRITE_YAML\n    basic_auth:\n      username: \"$REMOTE_WRITE_BASIC_AUTH_USER\"\n      password: \"$REMOTE_WRITE_BASIC_AUTH_PASSWORD\""
    fi
    
    # Add TLS config if provided
    if [ -n "$REMOTE_WRITE_TLS_INSECURE_SKIP_VERIFY" ] || [ -n "$REMOTE_WRITE_TLS_CA_FILE" ] || [ -n "$REMOTE_WRITE_TLS_CERT_FILE" ] || [ -n "$REMOTE_WRITE_TLS_KEY_FILE" ]; then
        REMOTE_WRITE_YAML="$REMOTE_WRITE_YAML\n    tls_config:"
        if [ -n "$REMOTE_WRITE_TLS_INSECURE_SKIP_VERIFY" ]; then
            REMOTE_WRITE_YAML="$REMOTE_WRITE_YAML\n      insecure_skip_verify: $REMOTE_WRITE_TLS_INSECURE_SKIP_VERIFY"
        fi
        if [ -n "$REMOTE_WRITE_TLS_CA_FILE" ]; then
            REMOTE_WRITE_YAML="$REMOTE_WRITE_YAML\n      ca_file: \"$REMOTE_WRITE_TLS_CA_FILE\""
        fi
        if [ -n "$REMOTE_WRITE_TLS_CERT_FILE" ]; then
            REMOTE_WRITE_YAML="$REMOTE_WRITE_YAML\n      cert_file: \"$REMOTE_WRITE_TLS_CERT_FILE\""
        fi
        if [ -n "$REMOTE_WRITE_TLS_KEY_FILE" ]; then
            REMOTE_WRITE_YAML="$REMOTE_WRITE_YAML\n      key_file: \"$REMOTE_WRITE_TLS_KEY_FILE\""
        fi
    fi
    
    # Generate final config: base config + remote_write block
    # Get base config (everything before the template conditional)
    awk '/^{{.*if .RemoteWriteURL/ {exit} {print}' "$TEMPLATE_FILE" > "$OUTPUT_FILE"
    # Append remote_write block
    printf "%b\n" "$REMOTE_WRITE_YAML" >> "$OUTPUT_FILE"
fi

# Validate generated config
echo "Validating generated Prometheus config..."
promtool check config "$OUTPUT_FILE"

# If test mode, show the generated config
if [ -n "$TEST_MODE" ]; then
    echo "=== Generated Config ==="
    cat "$OUTPUT_FILE"
    echo "========================"
fi

# If not test mode, start Prometheus
if [ -z "$TEST_MODE" ]; then
    echo "Starting Prometheus..."
    exec "$@"
fi