# Observability Stack - Docker Compose

This directory contains the Docker Compose configuration for the observability stack, including Traefik, Prometheus, Grafana, PostgreSQL, and supporting services.

## Services

| Service | Port | Description |
|---------|------|-------------|
| Traefik | 80, 443, 8080, 8081 | Reverse proxy with dashboard |
| Prometheus | 9090 | Metrics collection |
| Grafana | 3000 | Dashboards and visualization |
| PostgreSQL | 5432 | Primary database |
| App | 8000 | Python HTTP application with Prometheus metrics |
| Node Exporter | 9100 | Host system metrics |
| Postgres Exporter | 9187 | PostgreSQL metrics |

## Quick Start

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your values (required: POSTGRES_PASSWORD, GRAFANA_ADMIN_PASSWORD)
vim .env

# Start the stack
docker compose up -d

# Verify all services are healthy
docker compose ps
```

## Configuration

### Environment Variables

See `.env.example` for all available configuration options. Key variables:

| Variable | Description | Required |
|----------|-------------|----------|
| `DOMAIN` | Base domain for Traefik routing | No (default: localhost) |
| `POSTGRES_PASSWORD` | PostgreSQL password | **Yes** |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password | **Yes** |
| `TRAEFIK_ACME_EMAIL` | Email for Let's Encrypt certificates | No |
| `REMOTE_WRITE_URL` | Prometheus remote write endpoint | No |
| `REMOTE_WRITE_AUTHORIZATION` | Bearer token for remote write | No |

### Prometheus Remote Write (Optional)

To enable remote write for long-term metric storage (e.g., Grafana Cloud, Thanos, Cortex):

```bash
# In .env or export before running
export REMOTE_WRITE_URL="https://your-prometheus-endpoint/api/v1/write"
export REMOTE_WRITE_AUTHORIZATION="your-bearer-token"
# OR use basic auth:
export REMOTE_WRITE_BASIC_AUTH_USER="username"
export REMOTE_WRITE_BASIC_AUTH_PASSWORD="password"
```

The Prometheus service uses an entrypoint script that conditionally adds the `remote_write` configuration only when `REMOTE_WRITE_URL` is set.

## Application Service

The `app` service is a Python FastAPI application that exposes Prometheus metrics for observability testing.

### Endpoints

| Endpoint | Description |
|----------|-------------|
| `/` | Returns basic application information (name, version, description) |
| `/health` | Health check endpoint returning `{"status": "ok"}` |
| `/metrics` | Prometheus metrics endpoint with custom application metrics |

### Prometheus Metrics

The application instruments the following metrics:

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `http_requests_total` | Counter | method, path, status | Total HTTP requests by method, path, and status code |
| `http_request_duration_seconds` | Histogram | method, path | HTTP request latency in seconds |
| `http_requests_in_progress` | Gauge | (none) | Number of HTTP requests currently being processed |
| `http_errors_total` | Counter | error_type | Total HTTP errors by error type |

### Accessing the Application

- **Direct (internal)**: `http://app:8000` (within Docker network)
- **Via Traefik (HTTPS)**: `https://app.<domain>` (e.g., `https://app.localhost`)
- **Metrics**: `http://app:8000/metrics` (scraped by Prometheus)

### Local Development

```bash
# From compose/app directory
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python main.py
```

The application will be available at `http://localhost:8000`.

## PostgreSQL Backup & Restore

The stack includes a backup script at `backup/postgres-backup.sh` for managing PostgreSQL backups.

### Prerequisites

- Docker and Docker Compose installed
- PostgreSQL container running (`docker compose up -d postgres`)
- `POSTGRES_PASSWORD` set in `.env` or environment

### Backup

```bash
# Create timestamped backup in ./backups/
./backup/postgres-backup.sh backup

# Create backup with custom name
./backup/postgres-backup.sh backup my_backup.dump
```

Backups are stored in `compose/backups/` by default with format: `observability_backup_YYYYMMDD_HHMMSS.dump`

### Restore

```bash
# List available backups
./backup/postgres-backup.sh list

# Restore from backup (will REPLACE all data!)
./backup/postgres-backup.sh restore backups/observability_backup_20240101_120000.dump
```

⚠️ **Warning**: Restore drops and recreates the database. All existing data will be lost.

### Backup Details

- Uses `pg_dump` with custom format (`-Fc`) and maximum compression (`-Z9`)
- Excludes owner and privileges (`--no-owner --no-privileges`) for portability
- Restore uses `pg_restore` with `--clean --if-exists` for safe restoration
- Terminates existing connections before restore

## Grafana Dashboards

Pre-configured dashboards are provisioned automatically:

| Dashboard | UID | Description |
|-----------|-----|-------------|
| Traefik | `traefik-dashboard` | Request rates, latency, errors, connections |
| Application | `app-dashboard` | HTTP metrics, latency, error rates |
| PostgreSQL | `postgres-dashboard` | Connections, queries, cache hit ratio, size |
| Node Exporter | `node-exporter-dashboard` | CPU, memory, disk, network |

Access via Grafana at `http://grafana.<domain>` (default: `http://localhost:3000`)

## Traefik Configuration

### HTTP to HTTPS Redirect

Traefik is configured with automatic HTTP to HTTPS redirect middleware. In development (without real TLS certificates), the redirect is simulated via headers.

### Traefik Dashboard Basic Auth

The Traefik dashboard (`traefik.<domain>`) is protected with basic auth. Configure credentials via:

```bash
# In .env or export before running
export TRAEFIK_DASHBOARD_USER="admin"
export TRAEFIK_DASHBOARD_PASSWORD="secure-password"
```

## Resource Limits

PostgreSQL has resource limits configured:
- Memory: 512M limit, 256M reservation
- CPU: 0.5 limit, 0.25 reservation

## Verification Commands

```bash
# Validate Docker Compose configuration
docker compose config --quiet

# Validate Prometheus configuration
promtool check config prometheus/prometheus.yml

# Validate Grafana dashboards
python3 -m json.tool grafana/provisioning/dashboards/*.json > /dev/null && echo "All JSON valid"

# Validate backup script syntax
bash -n backup/postgres-backup.sh

# Validate Traefik configuration (if traefik binary available)
traefik --configFile=traefik/traefik.yml --validate 2>/dev/null || echo "traefik binary not available"
```

## Network & Volumes

- All services share the `observability` bridge network
- Persistent volumes: `postgres_data`, `grafana_data`, `prometheus_data`, `traefik_letsencrypt`

## Troubleshooting

### Services won't start
```bash
# Check logs
docker compose logs -f <service_name>

# Check health status
docker compose ps
```

### Prometheus remote write not working
- Verify `REMOTE_WRITE_URL` is set and accessible
- Check Prometheus logs: `docker compose logs prometheus`
- Validate generated config: `docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml`

### Grafana dashboards not loading
- Ensure Prometheus datasource is configured (provisioned automatically)
- Check Grafana logs: `docker compose logs grafana`
- Verify dashboard JSON syntax

### PostgreSQL backup fails
- Ensure container is running: `docker compose ps postgres`
- Check `POSTGRES_PASSWORD` is set correctly
- Verify disk space for backup directory

## Security Notes

- All passwords/secrets must be provided via environment variables
- No secrets are stored in configuration files
- Traefik dashboard requires basic auth
- PostgreSQL only accessible within the observability network
- Let's Encrypt certificates stored in `traefik_letsencrypt` volume