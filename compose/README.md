# Observability Stack - Docker Compose

Docker Compose configuration for the full observability stack: Traefik (reverse proxy), Prometheus (metrics), Grafana (dashboards), PostgreSQL (database), and supporting exporters.

## Table of Contents

- [Services Overview](#services-overview)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
  - [Environment Variables](#environment-variables)
  - [Prometheus Remote Write](#prometheus-remote-write-optional)
- [Service Details](#service-details)
  - [Traefik](#traefik)
  - [Prometheus](#prometheus)
  - [Grafana](#grafana)
  - [PostgreSQL](#postgresql)
  - [Application](#application-service)
  - [Node Exporter](#node-exporter)
  - [Postgres Exporter](#postgres-exporter)
- [Grafana Dashboards](#grafana-dashboards)
- [PostgreSQL Backup & Restore](#postgresql-backup--restore)
- [Network & Volumes](#network--volumes)
- [Verification Commands](#verification-commands)
- [Troubleshooting](#troubleshooting)
- [Security Notes](#security-notes)

## Services Overview

| Service | Ports | Description |
|---------|-------|-------------|
| Traefik | 80, 443, 8080, 8081 | Reverse proxy, API, dashboard, metrics |
| Prometheus | 9090 | Metrics collection and storage |
| Grafana | 3000 | Dashboards and visualization |
| PostgreSQL | 5432 | Primary database |
| App | 8000 | Python FastAPI application with Prometheus metrics |
| Node Exporter | 9100 | Host system metrics (CPU, memory, disk, network) |
| Postgres Exporter | 9187 | PostgreSQL database metrics |

## Quick Start

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your values (REQUIRED: POSTGRES_PASSWORD, GRAFANA_ADMIN_PASSWORD)
vim .env

# Start the stack
docker compose up -d

# Verify all services are healthy
docker compose ps
```

## Configuration

### Environment Variables

See `.env.example` for all available configuration options. All variables:

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| **Domain & Traefik** | | | |
| `DOMAIN` | Base domain for Traefik routing (e.g., `example.com`) | No | `localhost` |
| `TRAEFIK_ACME_EMAIL` | Email for Let's Encrypt ACME registration | No | `admin@example.com` |
| `TRAEFIK_DASHBOARD_USER` | Basic auth username for Traefik dashboard | No | (none) |
| `TRAEFIK_DASHBOARD_PASSWORD` | Basic auth password for Traefik dashboard | No | (none) |
| **PostgreSQL** | | | |
| `POSTGRES_DB` | Database name | No | `observability` |
| `POSTGRES_USER` | Database username | No | `observability` |
| `POSTGRES_PASSWORD` | Database password | **Yes** | (none) |
| **Grafana** | | | |
| `GRAFANA_ADMIN_USER` | Admin username | No | `admin` |
| `GRAFANA_ADMIN_PASSWORD` | Admin password | **Yes** | (none) |
| `GRAFANA_PLUGINS` | Comma-separated plugins to install | No | (none) |
| **Environment** | | | |
| `ENVIRONMENT` | Environment label (production/staging/dev) | No | `production` |
| **Prometheus** | | | |
| `PROMETHEUS_SCRAPE_INTERVAL` | Scrape interval for metrics | No | `15s` |
| `PROMETHEUS_RETENTION` | Retention period for metrics data | No | `15d` |
| **Prometheus Remote Write** | | | |
| `REMOTE_WRITE_URL` | Remote write endpoint URL | No | (none) |
| `REMOTE_WRITE_AUTHORIZATION` | Bearer token for remote write | No | (none) |
| `REMOTE_WRITE_BASIC_AUTH_USER` | Basic auth username | No | (none) |
| `REMOTE_WRITE_BASIC_AUTH_PASSWORD` | Basic auth password | No | (none) |
| `REMOTE_WRITE_HEADER_CONTENT_TYPE` | Custom Content-Type header | No | (none) |
| `REMOTE_WRITE_HEADER_CUSTOM` | Custom headers (Key:Value, comma-separated) | No | (none) |
| `REMOTE_WRITE_TLS_INSECURE_SKIP_VERIFY` | Skip TLS certificate verification | No | `false` |
| `REMOTE_WRITE_TLS_CA_FILE` | CA certificate file path | No | (none) |
| `REMOTE_WRITE_TLS_CERT_FILE` | Client certificate file path | No | (none) |
| `REMOTE_WRITE_TLS_KEY_FILE` | Client key file path | No | (none) |

### Prometheus Remote Write (Optional)

Enable long-term metric storage (Grafana Cloud, Thanos, Cortex, etc.):

```bash
# In .env or export before running
export REMOTE_WRITE_URL="https://your-prometheus-endpoint/api/v1/write"
export REMOTE_WRITE_AUTHORIZATION="your-bearer-token"
# OR basic auth:
export REMOTE_WRITE_BASIC_AUTH_USER="username"
export REMOTE_WRITE_BASIC_AUTH_PASSWORD="password"
```

The Prometheus entrypoint script conditionally adds `remote_write` configuration only when `REMOTE_WRITE_URL` is set.

## Service Details

### Traefik

**Image**: `traefik:v3.0`  
**Container**: `traefik`  
**Entrypoint**: `/entrypoint.sh` (processes `dynamic.yml.tmpl`)

#### Entrypoints

| Name | Address | Purpose |
|------|---------|---------|
| `web` | `:80` | HTTP (redirects to HTTPS) |
| `websecure` | `:443` | HTTPS with Let's Encrypt TLS |

#### Middlewares (defined in `traefik/dynamic.yml.tmpl`)

| Middleware | Type | Purpose |
|------------|------|---------|
| `traefik-dashboard-auth` | BasicAuth | Protects Traefik dashboard |
| `https-redirect` | RedirectScheme | HTTP → HTTPS redirect |
| `security-headers` | Headers | Security headers (HSTS, XSS, etc.) |

#### Routing

Services are routed via Docker labels. Traefik discovers services with `traefik.enable=true` on the `observability` network.

| Route | Host Rule | Entrypoint | Middleware | Target |
|-------|-----------|------------|------------|--------|
| Traefik Dashboard | `traefik.{DOMAIN}` | websecure | `traefik-dashboard-auth` | `:8080` |
| Grafana | `grafana.{DOMAIN}` | web | - | `:3000` |
| Prometheus | `prometheus.{DOMAIN}` | web | - | `:9090` |
| Application | `app.{DOMAIN}` | websecure | - | `:8000` |
| Postgres Exporter | `postgres-exporter.{DOMAIN}` | web | - | `:9187` |

#### Health Check

```bash
wget -q --spider http://localhost:8080/ping
```

#### Access

- Dashboard: `https://traefik.{DOMAIN}` (basic auth required if configured)
- API: `http://traefik:8080/api`
- Metrics: `http://traefik:8081/metrics`

### Prometheus

**Image**: `prom/prometheus:v2.47`  
**Container**: `prometheus`  
**Entrypoint**: `/entrypoint.sh` (processes `prometheus.yml.tmpl`)

#### Scrape Configuration (`prometheus/prometheus.yml.tmpl`)

| Job | Targets | Interval | Path |
|-----|---------|----------|------|
| `prometheus` | `localhost:9090` | 15s | `/metrics` |
| `node-exporter` | `node-exporter:9100` | 15s | `/metrics` |
| `postgres-exporter` | `postgres-exporter:9187` | 15s | `/metrics` |
| `grafana` | `grafana:3000` | 15s | `/metrics` |
| `app` | `app:80` | 15s | `/metrics` |
| `traefik` | `traefik:8081` | 15s | `/metrics` |
| `cadvisor` | `cadvisor:8080` | 15s | `/metrics` |

#### Global Settings

- `scrape_interval`: `${PROMETHEUS_SCRAPE_INTERVAL:-15s}`
- `evaluation_interval`: `15s`
- `external_labels`: `cluster=observability-stack`, `environment=${ENVIRONMENT}`

#### Remote Write

Conditionally enabled via `REMOTE_WRITE_URL`. Supports:
- Bearer token authentication
- Basic authentication
- Custom headers
- TLS configuration (CA, cert, key, insecure skip verify)

#### Health Check

```bash
wget -q --spider http://localhost:9090/-/healthy
```

#### Storage

Persistent volume: `prometheus_data` at `/prometheus`

### Grafana

**Image**: `grafana/grafana:10.1`  
**Container**: `grafana`

#### Provisioning

| Type | File | Description |
|------|------|-------------|
| Datasources | `grafana/provisioning/datasources/datasources.yml` | Prometheus as default datasource |
| Dashboards | `grafana/provisioning/dashboards/dashboards.yml` | Loads JSON dashboards from `/etc/grafana/provisioning/dashboards` |

#### Datasource Configuration

```yaml
name: Prometheus
type: prometheus
access: proxy
url: http://prometheus:9090
isDefault: true
jsonData:
  timeInterval: "15s"
  queryTimeout: "60s"
  httpMethod: "POST"
```

#### Health Check

```bash
wget -q --spider http://localhost:3000/api/health
```

#### Access

- UI: `http://grafana.{DOMAIN}` (default: `http://localhost:3000`)
- Login: `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD`

### PostgreSQL

**Image**: `postgres:15-alpine`  
**Container**: `postgres`

#### Configuration

| Parameter | Value |
|-----------|-------|
| Database | `${POSTGRES_DB:-observability}` |
| User | `${POSTGRES_USER:-observability}` |
| Password | `${POSTGRES_PASSWORD}` (required) |

#### Resource Limits

```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 512M
    reservations:
      cpus: '0.25'
      memory: 256M
```

#### Health Check

```bash
pg_isready -U ${POSTGRES_USER:-observability} -d ${POSTGRES_DB:-observability}
```

#### Storage

Persistent volume: `postgres_data` at `/var/lib/postgresql/data`

### Application Service

**Build**: `./app/Dockerfile`  
**Container**: `app`  
**Network**: `observability` (no exposed ports; accessed via Traefik)

#### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Application info (name, version, description) |
| `/health` | GET | Health check (`{"status": "ok"}`) |
| `/metrics` | GET | Prometheus metrics endpoint |

#### Prometheus Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `http_requests_total` | Counter | method, path, status | Total HTTP requests |
| `http_request_duration_seconds` | Histogram | method, path | Request latency in seconds |
| `http_requests_in_progress` | Gauge | (none) | Currently processing requests |
| `http_errors_total` | Counter | error_type | Total HTTP errors by type |

#### Traefik Labels

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.app.rule=Host(`app.${DOMAIN:-localhost}`)"
  - "traefik.http.routers.app.entrypoints=websecure"
  - "traefik.http.services.app.loadbalancer.server.port=8000"
```

#### Health Check

```bash
wget -q --spider http://localhost:8000/health
```

#### Local Development

```bash
cd compose/app
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python main.py
# Available at http://localhost:8000
```

### Node Exporter

**Image**: `prom/node-exporter:v1.6`  
**Container**: `node-exporter`

#### Exposed Metrics

Host-level metrics via bind mounts:
- `/proc` → `/host/proc`
- `/sys` → `/host/sys`
- `/` → `/rootfs`

#### Collector Flags

```bash
--path.procfs=/host/proc
--path.sysfs=/host/sys
--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($|/)
```

#### Health Check

```bash
wget -q --spider http://localhost:9100/metrics
```

### Postgres Exporter

**Image**: `prometheuscommunity/postgres-exporter:v0.15`  
**Container**: `postgres-exporter`  
**Depends on**: `postgres` (condition: service_healthy)

#### Configuration

```yaml
environment:
  - DATA_SOURCE_NAME=postgresql://${POSTGRES_USER:-observability}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB:-observability}?sslmode=disable
```

#### Health Check

```bash
wget -q --spider http://localhost:9187/metrics
```

#### Traefik Labels

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.postgres-exporter.rule=Host(`postgres-exporter.${DOMAIN:-localhost}`)"
  - "traefik.http.routers.postgres-exporter.entrypoints=web"
  - "traefik.http.services.postgres-exporter.loadbalancer.server.port=9187"
```

## Grafana Dashboards

Pre-configured dashboards provisioned automatically in the "Observability" folder:

| Dashboard | UID | Description |
|-----------|-----|-------------|
| Traefik | `traefik-dashboard` | Request rates, latency, errors, connections |
| Application | `app-dashboard` | HTTP metrics, latency, error rates |
| PostgreSQL | `postgres-dashboard` | Connections, queries, cache hit ratio, size |
| Node Exporter | `node-exporter-dashboard` | CPU, memory, disk, network |

Access via Grafana at `http://grafana.{DOMAIN}` (default: `http://localhost:3000`)

## PostgreSQL Backup & Restore

Backup script: `backup/postgres-backup.sh`

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

Backups stored in `compose/backups/` with format: `observability_backup_YYYYMMDD_HHMMSS.dump`

### Restore

```bash
# List available backups
./backup/postgres-backup.sh list

# Restore from backup (REPLACES all data!)
./backup/postgres-backup.sh restore backups/observability_backup_20240101_120000.dump
```

⚠️ **Warning**: Restore drops and recreates the database. All existing data will be lost.

### Backup Details

- Uses `pg_dump` with custom format (`-Fc`) and maximum compression (`-Z9`)
- Excludes owner and privileges (`--no-owner --no-privileges`) for portability
- Restore uses `pg_restore` with `--clean --if-exists` for safe restoration
- Terminates existing connections before restore

## Network & Volumes

### Network

- Single bridge network: `observability`
- All services communicate via service names

### Volumes

| Volume | Purpose |
|--------|---------|
| `postgres_data` | PostgreSQL data directory |
| `grafana_data` | Grafana dashboards, plugins, config |
| `prometheus_data` | Prometheus TSDB |
| `traefik_letsencrypt` | Let's Encrypt certificates (ACME) |

## Verification Commands

```bash
# Validate Docker Compose configuration
docker compose config --quiet

# Validate Prometheus configuration (template)
promtool check config prometheus/prometheus.yml.tmpl

# Validate Grafana dashboard JSON syntax
python3 -m json.tool grafana/provisioning/dashboards/*.json > /dev/null && echo "All JSON valid"

# Validate backup script syntax
bash -n backup/postgres-backup.sh

# Validate Traefik configuration (if traefik binary available)
traefik --configFile=traefik/traefik.yml --validate 2>/dev/null || echo "traefik binary not available"

# Service-specific health checks (after docker compose up -d)
docker compose ps  # All services should show "healthy"
curl -f http://localhost:8080/ping  # Traefik
curl -f http://localhost:9090/-/healthy  # Prometheus
curl -f http://localhost:3000/api/health  # Grafana
curl -f http://localhost:8000/health  # App
curl -f http://localhost:9100/metrics  # Node Exporter
curl -f http://localhost:9187/metrics  # Postgres Exporter
```

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

### Traefik routing not working

- Verify `DOMAIN` is set correctly in `.env`
- Check Traefik logs: `docker compose logs traefik`
- Verify service labels in `docker-compose.yml`

## Security Notes

- All passwords/secrets must be provided via environment variables
- No secrets are stored in configuration files
- Traefik dashboard requires basic auth when credentials configured
- PostgreSQL only accessible within the `observability` network
- Let's Encrypt certificates stored in `traefik_letsencrypt` volume
- Security headers middleware applied to all routes

---

*Part of the [terraform-observability-stack](../README.md) project. Spec: `openspec/changes/terraform-observability-stack/specs/infrastructure/docker-compose-stack/`*
