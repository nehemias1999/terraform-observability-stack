# terraform-observability-stack

IaC deployment using Terraform and Docker Compose. Provisions an immutable environment with Traefik, Prometheus, Grafana, and PostgreSQL optimized for standard Linux LTS hosts.

[![CI](https://github.com/nsalazar/terraform-observability-stack/actions/workflows/terraform-ci.yml/badge.svg)](https://github.com/nsalazar/terraform-observability-stack/actions/workflows/terraform-ci.yml)
[![Terraform](https://img.shields.io/badge/terraform-1.5+-623CE4.svg)](https://www.terraform.io/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Table of Contents

- [Background](#background)
  - [Technologies](#technologies)
  - [Architecture / Flow](#architecture--flow)
  - [Spec Reference](#spec-reference)
- [Install](#install)
  - [Prerequisites](#prerequisites)
  - [Quick Start](#quick-start)
- [Usage](#usage)
  - [Terraform (Infrastructure)](#terraform-infrastructure)
  - [Docker Compose (Services)](#docker-compose-services)
- [API / Configuration](#api--configuration)
  - [Environment Variables](#environment-variables)
  - [Terraform Variables](#terraform-variables)
- [Contributing](#contributing)
  - [Verification Commands](#verification-commands)
- [Integration Test Procedure](#integration-test-procedure)
- [License](#license)

## Background

### Technologies

| Category | Technology | Version |
|----------|------------|---------|
| Infrastructure as Code | Terraform | ≥ 1.5 |
| Cloud Providers | AWS, GCP | Provider ~> 5.0 |
| Container Orchestration | Docker Compose | v2 (plugin) |
| Reverse Proxy | Traefik | v3.0 |
| Metrics Collection | Prometheus | v2.47 |
| Visualization | Grafana | 10.1 |
| Database | PostgreSQL | 15-alpine |
| Application Runtime | Python/FastAPI | 3.11+ |
| Exporters | Node Exporter v1.6, Postgres Exporter v0.15 | |

### Architecture / Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CLOUD INFRASTRUCTURE (Terraform)                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                     │
│  │   AWS/GCP   │    │  Networking │    │   Compute   │                     │
│  │  Provider   │───▶│ (SG/Firewall)│───▶│    VM       │                     │
│  └─────────────┘    └─────────────┘    └──────┬──────┘                     │
│                                                │                            │
│                                                ▼                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    USER_DATA.SH (cloud-init)                        │   │
│  │  • Install Docker & Docker Compose                                  │   │
│  │  • Pull docker-compose.yml                                          │   │
│  │  • Start observability stack                                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        OBSERVABILITY STACK (Docker Compose)                 │
│                                                                             │
│  ┌──────────┐    ┌─────────────┐    ┌──────────┐    ┌──────────────┐      │
│  │ Traefik  │◀───│   Internet  │    │  Client  │    │   DNS        │      │
│  │ :80/:443 │    │   Traffic   │    │          │    │   (DOMAIN)   │      │
│  └────┬─────┘    └─────────────┘    └──────────┘    └──────────────┘      │
│       │                                                                      │
│       ├──▶ grafana.DOMAIN:3000      (Dashboards)                            │
│       ├──▶ prometheus.DOMAIN:9090   (Metrics)                               │
│       ├──▶ traefik.DOMAIN:8080      (Dashboard - auth)                      │
│       ├──▶ app.DOMAIN:8000          (Application)                           │
│       ├──▶ postgres-exporter.DOMAIN:9187 (DB Metrics)                       │
│       └──▶ postgres:5432            (Internal)                              │
│                                                                             │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────┐  ┌─────────────────┐   │
│  │ Prometheus  │◀─│ Node Exporter│  │  App       │  │ PostgreSQL      │   │
│  │ :9090       │  │ :9100        │  │ :8000      │  │ :5432           │   │
│  └──────┬──────┘  └──────────────┘  └────────────┘  └────────┬────────┘   │
│         │                                                      │            │
│         │                    ┌─────────────────────────────────┘            │
│         ▼                    ▼                                                │
│  ┌─────────────┐    ┌──────────────┐                                         │
│  │   Grafana   │    │Postgres Exp. │                                         │
│  │   :3000     │    │  :9187       │                                         │
│  └─────────────┘    └──────────────┘                                         │
│                                                                             │
│  Volumes: postgres_data, grafana_data, prometheus_data, traefik_letsencrypt │
│  Network: observability (bridge)                                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Spec Reference

This project is specified using [OpenSpec](https://github.com/openspec/openspec). The source of truth for requirements lives in `openspec/changes/terraform-observability-stack/`:

- **Tasks**: `openspec/changes/terraform-observability-stack/tasks.md`
- **Infrastructure Specs**: `openspec/changes/terraform-observability-stack/specs/infrastructure/`
- **Observability Specs**: `openspec/changes/terraform-observability-stack/specs/observability/`
- **Database Specs**: `openspec/changes/terraform-observability-stack/specs/database/`
- **Networking Specs**: `openspec/changes/terraform-observability-stack/specs/networking/`
- **CI/CD Specs**: `openspec/changes/terraform-observability-stack/specs/ci-cd/`

## Install

### Prerequisites

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| Terraform | 1.5+ | Infrastructure provisioning |
| Docker | 24+ | Container runtime |
| Docker Compose | v2 (plugin) | Service orchestration |
| promtool | 2.47+ | Prometheus config validation |
| openspec | latest | Spec validation |
| AWS CLI / gcloud | latest | Cloud authentication (for real apply) |

### Quick Start

```bash
# 1. Clone and enter the project
git clone <repository-url>
cd terraform-observability-stack

# 2. Provision infrastructure (dry-run)
cd terraform
terraform init
terraform plan -var-file=example-dryrun.tfvars  # See terraform/README.md for tfvars

# 3. Configure and start services (dry-run)
cd ../compose
cp .env.example .env
# Edit .env with required values: POSTGRES_PASSWORD, GRAFANA_ADMIN_PASSWORD
docker compose config --quiet

# 4. Validate configurations
promtool check config prometheus/prometheus.yml.tmpl
python3 -m json.tool grafana/provisioning/dashboards/*.json > /dev/null
bash -n backup/postgres-backup.sh

# 5. Start the stack
docker compose up -d

# 6. Verify all services healthy
docker compose ps
```

## Usage

### Terraform (Infrastructure)

Provisions a VM with networking on AWS or GCP. The VM runs the observability stack via `user_data.sh`.

```bash
cd terraform

# Initialize (uses local backend by default)
terraform init

# Plan with example variables (AWS)
terraform plan -var-file=example-aws.tfvars

# Plan with example variables (GCP)
terraform plan -var-file=example-gcp.tfvars

# Apply (requires real cloud credentials)
terraform apply -var-file=example-aws.tfvars

# Outputs after apply
terraform output public_ip
terraform output private_ip
terraform output instance_id
```

See [terraform/README.md](terraform/README.md) for detailed usage, variables, backend configuration, and example tfvars files.

### Docker Compose (Services)

Runs the full observability stack locally or on the provisioned VM.

```bash
cd compose

# Configure environment
cp .env.example .env
# Required: POSTGRES_PASSWORD, GRAFANA_ADMIN_PASSWORD
# Optional: DOMAIN, TRAEFIK_ACME_EMAIL, REMOTE_WRITE_URL, etc.

# Start all services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f <service>

# Stop and remove
docker compose down
```

See [compose/README.md](compose/README.md) for service details, configuration, and troubleshooting.

## API / Configuration

### Environment Variables

All secrets and configuration are provided via environment variables. No secrets are stored in configuration files.

#### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `POSTGRES_PASSWORD` | PostgreSQL superuser password | `openssl rand -base64 32` |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password | `openssl rand -base64 32` |

#### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DOMAIN` | Base domain for Traefik routing | `localhost` |
| `TRAEFIK_ACME_EMAIL` | Email for Let's Encrypt certificates | `admin@example.com` |
| `TRAEFIK_DASHBOARD_USER` | Traefik dashboard basic auth user | (none) |
| `TRAEFIK_DASHBOARD_PASSWORD` | Traefik dashboard basic auth password | (none) |
| `POSTGRES_DB` | PostgreSQL database name | `observability` |
| `POSTGRES_USER` | PostgreSQL username | `observability` |
| `GRAFANA_ADMIN_USER` | Grafana admin username | `admin` |
| `GRAFANA_PLUGINS` | Comma-separated Grafana plugins | (none) |
| `ENVIRONMENT` | Environment label (production/staging/dev) | `production` |
| `REMOTE_WRITE_URL` | Prometheus remote write endpoint | (none) |
| `REMOTE_WRITE_AUTHORIZATION` | Bearer token for remote write | (none) |
| `REMOTE_WRITE_BASIC_AUTH_USER` | Basic auth username for remote write | (none) |
| `REMOTE_WRITE_BASIC_AUTH_PASSWORD` | Basic auth password for remote write | (none) |
| `REMOTE_WRITE_HEADER_CONTENT_TYPE` | Custom Content-Type header | (none) |
| `REMOTE_WRITE_HEADER_CUSTOM` | Custom headers (Key:Value) | (none) |
| `REMOTE_WRITE_TLS_INSECURE_SKIP_VERIFY` | Skip TLS verification | `false` |
| `REMOTE_WRITE_TLS_CA_FILE` | CA certificate path | (none) |
| `REMOTE_WRITE_TLS_CERT_FILE` | Client certificate path | (none) |
| `REMOTE_WRITE_TLS_KEY_FILE` | Client key path | (none) |

### Terraform Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `cloud_provider` | Target cloud: `aws` or `gcp` | Yes | - |
| `region` | Cloud region (e.g., `us-east-1`, `us-central1`) | Yes | - |
| `instance_type` | VM type (e.g., `t3.medium`, `e2-medium`) | Yes | - |
| `ssh_public_key` | SSH public key for VM access (OpenSSH format) | Yes | - |
| `project_id` | GCP project ID | When GCP | - |
| `aws_ami` | AWS AMI ID for Ubuntu 22.04 LTS | When AWS | - |
| `gcp_image_family` | GCP image family | When GCP | `ubuntu-2204-lts` |
| `aws_vpc_id` | AWS VPC ID (mock for dry-run) | No | `vpc-mock12345` |
| `aws_subnet_id` | AWS Subnet ID (mock for dry-run) | No | `subnet-mock12345` |
| `tags` | Map of tags for all resources | No | See variables.tf |
| `volume_size` | Root volume size in GB (≥20) | No | `20` |

See [terraform/README.md](terraform/README.md) for complete variable reference and example tfvars files.

## Contributing

### Verification Commands

Run all verification commands before submitting changes:

```bash
# README validation (readme-standard)
readme-standard validate README.md
readme-standard validate terraform/README.md
readme-standard validate compose/README.md

# Terraform validation
cd terraform && terraform fmt -check && terraform validate

# Docker Compose validation
docker compose -f compose/docker-compose.yml config --quiet

# Prometheus config validation
promtool check config compose/prometheus/prometheus.yml.tmpl

# OpenSpec validation
openspec validate --changes

# JSON dashboard validation
python3 -m json.tool compose/grafana/provisioning/dashboards/*.json > /dev/null

# Backup script syntax
bash -n compose/backup/postgres-backup.sh
```

## Integration Test Procedure

This section documents the full end-to-end integration test procedure for validating the observability stack deployment. **All commands below are dry-run safe** — they validate configuration without applying real infrastructure changes or requiring cloud credentials.

### Prerequisites for Testing

```bash
# Required tools
terraform >= 1.5
docker >= 24 with compose plugin
promtool >= 2.47
openspec (for spec validation)
```

### Phase 1: Terraform Infrastructure Validation (Dry-Run)

```bash
cd terraform

# Initialize with local backend (no cloud credentials needed)
terraform init

# Validate formatting and syntax
terraform fmt -check
terraform validate

# Plan with mock variables (no real cloud resources created)
# Uses example-dryrun.tfvars with mock VPC/subnet/AMI values
terraform plan -var-file=example-dryrun.tfvars

# Expected: Plan succeeds, shows VM + networking resources to be created
# No real apply performed — this is a dry-run validation only
```

### Phase 2: Docker Compose Configuration Validation

```bash
cd ../compose

# Validate compose file syntax and variable interpolation
docker compose config --quiet

# Expected: Exits with code 0, no output = valid configuration
```

### Phase 3: Prometheus Configuration Validation

```bash
# Validate Prometheus config template (processed at runtime by entrypoint)
promtool check config prometheus/prometheus.yml.tmpl

# Expected: "Checking prometheus/prometheus.yml.tmpl\n  SUCCESS: ... is valid"
```

### Phase 4: Grafana Dashboard JSON Validation

```bash
# Validate all dashboard JSON files are syntactically correct
python3 -m json.tool grafana/provisioning/dashboards/*.json > /dev/null && echo "All JSON valid"

# Expected: "All JSON valid"
```

### Phase 5: Backup Script Syntax Validation

```bash
# Validate bash syntax of backup script
bash -n backup/postgres-backup.sh

# Expected: No output = syntax OK
```

### Phase 6: Traefik Configuration Validation (Optional)

```bash
# If traefik binary is available
traefik --configFile=traefik/traefik.yml --validate 2>/dev/null || echo "traefik binary not available"
```

### Phase 7: Service Startup & Health Verification (Local)

```bash
# Configure required environment variables
cp .env.example .env
# Set required values:
export POSTGRES_PASSWORD="test-password-123"
export GRAFANA_ADMIN_PASSWORD="test-password-123"
# Optional for local testing:
export DOMAIN="localhost"

# Start all services in background
docker compose up -d

# Wait for services to become healthy (30-60 seconds)
sleep 45

# Verify all services report healthy status
docker compose ps
# Expected: All 7 services show "healthy" or "running" status
```

### Phase 8: Service Endpoint Verification

```bash
# Traefik API & Dashboard
curl -f http://localhost:8080/ping                    # Health check
curl -f http://localhost:8080/api/overview            # API overview

# Prometheus
curl -f http://localhost:9090/-/healthy               # Health check
curl -f http://localhost:9090/api/v1/targets          # Scrape targets status

# Grafana
curl -f http://localhost:3000/api/health              # Health check

# Application
curl -f http://localhost:8000/health                  # Health check
curl -f http://localhost:8000/                        # Root endpoint
curl -f http://localhost:8000/metrics                 # Prometheus metrics

# Node Exporter
curl -f http://localhost:9100/metrics                 # Host metrics

# Postgres Exporter
curl -f http://localhost:9187/metrics                 # PostgreSQL metrics

# All curl commands should return HTTP 200 with valid responses
```

### Phase 9: Metrics Collection Verification

```bash
# Verify Prometheus is scraping all targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Expected: All 7 jobs (prometheus, node-exporter, postgres-exporter, grafana, app, traefik, cadvisor) show "up"

# Verify custom application metrics
curl -s http://localhost:9090/api/v1/query?query=http_requests_total | jq '.data.result[] | {metric: .metric, value: .value}'

# Expected: http_requests_total metric present with method/path/status labels
```

### Phase 10: Cleanup

```bash
# Stop and remove all containers, networks
docker compose down

# Remove volumes (optional - destroys data)
docker compose down -v

# Terraform destroy (dry-run - shows what would be destroyed)
cd ../terraform
terraform destroy -var-file=example-dryrun.tfvars

# Expected: Plan shows all resources to be destroyed, no real apply
```

### Phase 11: Spec Validation

```bash
# Validate all OpenSpec specifications
cd /home/nsalazar/Documents/Projects/terraform-observability-stack-feat-documentation-verification
openspec validate --changes

# Expected: "1 passed, 0 failed" (warnings acceptable)
```

### Notes

| Aspect | Detail |
|--------|--------|
| **Real Apply** | Requires valid AWS/GCP credentials, real VPC/subnet/AMI values. Not executed in CI. |
| **Local Testing** | All service verification runs locally via Docker Compose. No cloud VM needed. |
| **Mock Values** | `example-dryrun.tfvars` uses mock IDs (`vpc-mock12345`, `subnet-mock12345`, `ami-mock12345`) for `terraform plan` without credentials. |
| **CI Integration** | GitHub Actions workflow (`.github/workflows/terraform-ci.yml`) runs Phases 1-3, 5, 11 on every PR. |
| **Data Persistence** | `docker compose down -v` removes all volumes. Omit `-v` to preserve data between test runs. |

---

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

*Generated with [OpenSpec](https://github.com/openspec/openspec) • Spec: `openspec/changes/terraform-observability-stack/`*
