#!/bin/sh
# ==============================================================================
# Description: Traefik entrypoint script that generates dynamic.yml from
#   template with basic auth configuration based on environment variables.
# Author: Infrastructure Team
# Usage: Called as entrypoint in docker-compose.yml for traefik service
# Dependencies: htpasswd (apache2-utils) for password hashing
# ==============================================================================

set -e

TEMPLATE_FILE="/etc/traefik/dynamic.yml.tmpl"
OUTPUT_FILE="/etc/traefik/dynamic.yml"

# For local testing
if [ -n "$TEST_MODE" ]; then
    TEMPLATE_FILE="./dynamic.yml.tmpl"
    OUTPUT_FILE="./dynamic.yml.generated"
fi

# Generate basic auth hash if credentials provided
TRAEFIK_DASHBOARD_USER="${TRAEFIK_DASHBOARD_USER:-}"
TRAEFIK_DASHBOARD_PASSWORD="${TRAEFIK_DASHBOARD_PASSWORD:-}"

if [ -n "$TRAEFIK_DASHBOARD_USER" ] && [ -n "$TRAEFIK_DASHBOARD_PASSWORD" ]; then
    echo "Generating basic auth hash for Traefik dashboard..."
    # Generate bcrypt hash using htpasswd
    if command -v htpasswd >/dev/null 2>&1; then
        AUTH_HASH=$(htpasswd -nbB -C 12 "$TRAEFIK_DASHBOARD_USER" "$TRAEFIK_DASHBOARD_PASSWORD" | cut -d: -f2)
    else
        # Fallback: use plain text (not recommended for production)
        echo "WARNING: htpasswd not available, using plain text password (NOT SECURE FOR PRODUCTION)"
        AUTH_HASH="$TRAEFIK_DASHBOARD_PASSWORD"
    fi
    
    # Replace template variables
    sed \
        -e "s|\\\${TRAEFIK_DASHBOARD_USER:-admin}|$TRAEFIK_DASHBOARD_USER|g" \
        -e "s|\\\${TRAEFIK_DASHBOARD_HASH:-}|$AUTH_HASH|g" \
        "$TEMPLATE_FILE" > "$OUTPUT_FILE"
else
    echo "No Traefik dashboard credentials provided, generating config without auth middleware"
    # Generate config without the traefik-dashboard-auth middleware
    cat > "$OUTPUT_FILE" <<'EOF'
# ==============================================================================
# Description: Traefik dynamic configuration for middlewares.
#   Defines middlewares such as HTTPS redirect and security headers.
# Author: Infrastructure Team
# Usage: Referenced by traefik.yml (static config) via file provider
# Dependencies: traefik:v3.0
# ==============================================================================

http:
  middlewares:
    # HTTPS redirect middleware (alternative to entryPoint redirection)
    https-redirect:
      redirectScheme:
        scheme: https
        permanent: true

    # Security headers middleware
    security-headers:
      headers:
        browserXssFilter: true
        contentTypeNosniff: true
        forceSTSHeader: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000
        customFrameOptionsValue: SAMEORIGIN
        referrerPolicy: "strict-origin-when-cross-origin"
EOF
fi

# If test mode, show generated config
if [ -n "$TEST_MODE" ]; then
    echo "=== Generated Dynamic Config ==="
    cat "$OUTPUT_FILE"
    echo "================================"
fi

# Start Traefik with original arguments
exec "$@"