#!/usr/bin/env bash
# ==============================================================================
# Description: Test script to validate docker-compose.yml meets all requirements
#   for tasks 2.1-2.5. Validates service count, volumes, health checks,
#   and Traefik labels.
# Author: Infrastructure Team
# Usage: ./test_compose.sh
# Dependencies: docker, docker-compose, jq, yq
# Exit Codes: 0 on all tests pass, 1 on any test failure
# ==============================================================================

set -euo pipefail

COMPOSE_FILE="docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    if eval "$test_command"; then
        log_info "PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "FAIL: $test_name"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Check if compose file exists
run_test "Compose file exists" "[ -f \"$COMPOSE_FILE\" ]"

# Validate docker compose syntax
run_test "Docker compose syntax valid" "docker compose -f \"$COMPOSE_FILE\" config --quiet"

# Get service list
SERVICES=$(docker compose -f "$COMPOSE_FILE" config 2>/dev/null | grep -E "^  [a-z-]+:" | sed 's/^  //;s/:$//' | grep -v "^observability$")

# Task 2.1: Check all 7 required services exist
REQUIRED_SERVICES=("traefik" "prometheus" "grafana" "postgres" "app" "node-exporter" "postgres-exporter")

for service in "${REQUIRED_SERVICES[@]}"; do
    run_test "Service '$service' exists" "echo \"$SERVICES\" | grep -qx \"$service\""
done

# Task 2.3: Check named volumes
VOLUMES=$(docker compose -f "$COMPOSE_FILE" config --volumes 2>/dev/null || echo "")
REQUIRED_VOLUMES=("postgres_data" "grafana_data" "prometheus_data")

for volume in "${REQUIRED_VOLUMES[@]}"; do
    run_test "Volume '$volume' defined" "echo \"$VOLUMES\" | grep -qx \"$volume\""
done

# Task 2.4: Check health checks on all services
for service in "${REQUIRED_SERVICES[@]}"; do
    # Use docker compose config and grep for healthcheck in the output
    HEALTHCHECK=$(docker compose -f "$COMPOSE_FILE" config 2>/dev/null | grep -A 10 "^  $service:" | grep -c "healthcheck:" || echo "0")
    run_test "Service '$service' has healthcheck" "[ \"$HEALTHCHECK\" -gt 0 ]"
done

# Task 2.5: Check Traefik labels on services (except postgres and node-exporter which don't need routing)
SERVICES_NEEDING_TRAEFIK=("traefik" "prometheus" "grafana" "app" "postgres-exporter")

for service in "${SERVICES_NEEDING_TRAEFIK[@]}"; do
    # Check for traefik.enable label in the service config
    LABELS=$(docker compose -f "$COMPOSE_FILE" config 2>/dev/null | grep -A 20 "^  $service:" | grep -c "traefik.enable" || echo "0")
    run_test "Service '$service' has traefik.enable label" "[ \"$LABELS\" -gt 0 ]"
done

# Summary
echo ""
echo "========================================="
echo "Test Summary:"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo "========================================="

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
else
    exit 0
fi