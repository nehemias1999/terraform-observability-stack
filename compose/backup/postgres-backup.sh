#!/bin/bash
# ==============================================================================
# Description: PostgreSQL backup and restore script for the observability stack.
#   Uses pg_dump/pg_restore via docker exec to backup/restore the PostgreSQL
#   database running in the docker-compose stack.
# Author: Infrastructure Team
# Usage:
#   Backup:  ./postgres-backup.sh backup [output_file]
#   Restore: ./postgres-backup.sh restore <input_file>
#   List:    ./postgres-backup.sh list
# Dependencies: docker, docker-compose, postgresql-client (in container)
# Environment: POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB (from .env)
# ==============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"
ENV_FILE="$COMPOSE_DIR/.env"
BACKUP_DIR="$COMPOSE_DIR/backups"

# Default values
CONTAINER_NAME="postgres"
DB_USER="${POSTGRES_USER:-observability}"
DB_NAME="${POSTGRES_DB:-observability}"
DB_PASSWORD="${POSTGRES_PASSWORD:-}"
BACKUP_PREFIX="observability_backup"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ==============================================================================
# Helper Functions
# ==============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

usage() {
    cat <<EOF
Usage: $0 <command> [options]

Commands:
  backup [output_file]    Create a database backup
                          If output_file not specified, uses timestamped name in $BACKUP_DIR
  restore <input_file>    Restore database from backup file
  list                    List available backups in $BACKUP_DIR

Environment Variables (from .env or docker-compose):
  POSTGRES_USER           Database user (default: observability)
  POSTGRES_DB             Database name (default: observability)
  POSTGRES_PASSWORD       Database password (required)

Examples:
  $0 backup                                    # Backup to timestamped file
  $0 backup my_backup.dump                     # Backup to specific file
  $0 restore backups/observability_backup_20240101_120000.dump
  $0 list

Notes:
  - Requires docker and docker-compose to be available
  - The PostgreSQL container must be running
  - Backup files are stored in $BACKUP_DIR by default
EOF
}

check_dependencies() {
    if ! command -v docker &> /dev/null; then
        log_error "docker not found in PATH"
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        log_error "docker compose not available"
        exit 1
    fi
}

check_container_running() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_error "PostgreSQL container '$CONTAINER_NAME' is not running"
        log_info "Start it with: docker compose -f $COMPOSE_FILE up -d postgres"
        exit 1
    fi
}

load_env() {
    if [ -f "$ENV_FILE" ]; then
        # shellcheck source=/dev/null
        set -a
        source "$ENV_FILE"
        set +a
    else
        log_warn "No .env file found at $ENV_FILE, using defaults"
    fi
    
    if [ -z "$DB_PASSWORD" ]; then
        log_error "POSTGRES_PASSWORD is not set. Please set it in .env or export it."
        exit 1
    fi
}

ensure_backup_dir() {
    mkdir -p "$BACKUP_DIR"
}

# ==============================================================================
# Backup Command
# ==============================================================================

cmd_backup() {
    local output_file="${1:-}"
    
    check_dependencies
    load_env
    check_container_running
    ensure_backup_dir
    
    # Generate default filename with timestamp
    if [ -z "$output_file" ]; then
        local timestamp
        timestamp=$(date +"%Y%m%d_%H%M%S")
        output_file="$BACKUP_DIR/${BACKUP_PREFIX}_${timestamp}.dump"
    elif [[ "$output_file" != /* ]]; then
        # Relative path, make it relative to BACKUP_DIR
        output_file="$BACKUP_DIR/$output_file"
    fi
    
    # Ensure directory exists
    mkdir -p "$(dirname "$output_file")"
    
    log_info "Starting backup of database '$DB_NAME'..."
    log_info "Output file: $output_file"
    
    # Run pg_dump inside the container
    # Use PGPASSWORD environment variable for password
    docker exec -e PGPASSWORD="$DB_PASSWORD" "$CONTAINER_NAME" \
        pg_dump -U "$DB_USER" -d "$DB_NAME" \
        --format=custom \
        --compress=9 \
        --no-owner \
        --no-privileges \
        --file="/tmp/backup.dump" 2>/dev/null
    
    # Copy from container to host
    docker cp "$CONTAINER_NAME:/tmp/backup.dump" "$output_file"
    
    # Clean up temp file in container
    docker exec "$CONTAINER_NAME" rm -f /tmp/backup.dump
    
    # Verify backup
    if [ -f "$output_file" ] && [ -s "$output_file" ]; then
        local size
        size=$(du -h "$output_file" | cut -f1)
        log_info "Backup completed successfully!"
        log_info "File: $output_file (${size})"
    else
        log_error "Backup failed or produced empty file"
        exit 1
    fi
}

# ==============================================================================
# Restore Command
# ==============================================================================

cmd_restore() {
    local input_file="${1:-}"
    
    if [ -z "$input_file" ]; then
        log_error "Input file required for restore"
        usage
        exit 1
    fi
    
    # Resolve path
    if [[ "$input_file" != /* ]]; then
        # Check relative to BACKUP_DIR first
        if [ -f "$BACKUP_DIR/$input_file" ]; then
            input_file="$BACKUP_DIR/$input_file"
        elif [ -f "$input_file" ]; then
            # Relative to current directory
            input_file="$(pwd)/$input_file"
        else
            log_error "Backup file not found: $input_file"
            exit 1
        fi
    fi
    
    if [ ! -f "$input_file" ]; then
        log_error "Backup file not found: $input_file"
        exit 1
    fi
    
    check_dependencies
    load_env
    check_container_running
    
    log_warn "This will REPLACE all data in database '$DB_NAME'!"
    log_warn "Backup file: $input_file"
    
    read -rp "Are you sure you want to continue? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "Restore cancelled"
        exit 0
    fi
    
    log_info "Starting restore of database '$DB_NAME'..."
    
    # Copy backup file to container
    docker cp "$input_file" "$CONTAINER_NAME:/tmp/restore.dump"
    
    # Terminate existing connections
    log_info "Terminating existing connections..."
    docker exec -e PGPASSWORD="$DB_PASSWORD" "$CONTAINER_NAME" \
        psql -U "$DB_USER" -d postgres -c "
            SELECT pg_terminate_backend(pid)
            FROM pg_stat_activity
            WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();
        " 2>/dev/null || true
    
    # Drop and recreate database
    log_info "Dropping and recreating database..."
    docker exec -e PGPASSWORD="$DB_PASSWORD" "$CONTAINER_NAME" \
        psql -U "$DB_USER" -d postgres -c "
            DROP DATABASE IF EXISTS \"$DB_NAME\";
            CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";
        "
    
    # Restore using pg_restore
    log_info "Restoring data..."
    docker exec -e PGPASSWORD="$DB_PASSWORD" "$CONTAINER_NAME" \
        pg_restore -U "$DB_USER" -d "$DB_NAME" \
        --clean \
        --if-exists \
        --no-owner \
        --no-privileges \
        /tmp/restore.dump
    
    # Clean up temp file in container
    docker exec "$CONTAINER_NAME" rm -f /tmp/restore.dump
    
    log_info "Restore completed successfully!"
}

# ==============================================================================
# List Command
# ==============================================================================

cmd_list() {
    ensure_backup_dir
    
    log_info "Available backups in $BACKUP_DIR:"
    
    if [ -d "$BACKUP_DIR" ] && [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        ls -lh "$BACKUP_DIR"/*.dump 2>/dev/null | awk '{print $9 "  " $5 "  " $6 " " $7 " " $8}' | while IFS= read -r line; do
            if [ -n "$line" ]; then
                echo "  $line"
            fi
        done
    else
        log_info "  No backups found"
    fi
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    local command="${1:-}"
    
    case "$command" in
        backup)
            shift
            cmd_backup "$@"
            ;;
        restore)
            shift
            cmd_restore "$@"
            ;;
        list)
            cmd_list
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

main "$@"