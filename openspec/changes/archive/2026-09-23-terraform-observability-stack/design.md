# Design

## Context

See proposal.md - Why. This is a new project (greenfield) with no existing infrastructure code. The target is a single VM running Docker Compose with an observability stack.

Constraints:
- Must support both AWS and GCP providers
- Single-node architecture (no HA)
- Cost-effective for dev/QA environments
- Terraform for infrastructure, Docker Compose for orchestration
- Remote state with locking required

## Goals / Non-Goals

**Goals:**
- Provision VM with networking via Terraform (AWS EC2 / GCP Compute Engine)
- Deploy full observability stack via Docker Compose (Traefik, Prometheus, Grafana, PostgreSQL, dummy app)
- Configure Prometheus scraping for all services
- Provision Grafana with dashboards as code
- Implement CI/CD pipeline with GitHub Actions (fmt, validate, plan, apply)
- Use remote state backend (S3/GCS + DynamoDB/Cloud Storage locking)
- All configuration via environment variables/.env files

**Non-Goals:**
- High availability / multi-node clustering
- Real TLS certificates (simulated SSL termination)
- Kubernetes or other orchestration platforms
- Advanced alerting/notification rules (basic dashboards only)
- Multi-region deployment

## Decisions

### 1. Terraform Structure
**Decision:** Use a flat module structure with provider-specific resources behind a `cloud_provider` variable.
**Rationale:** Simpler for single-node deployment; avoids over-engineering with modules for this scope.
**Alternatives:** Separate modules per provider, or Terragrunt for DRY.

### 2. Docker Compose Version
**Decision:** Use Docker Compose v2 (docker compose plugin) with compose file version 3.8+.
**Rationale:** v1 is deprecated; v2 is standard and included with Docker Engine.

### 3. Service Discovery
**Decision:** Use Docker Compose internal DNS (container names) for inter-service communication.
**Rationale:** Zero-config, works out of the box with user-defined networks.

### 4. Traefik Configuration
**Decision:** Static configuration via traefik.yml + dynamic via Docker labels.
**Rationale:** Labels enable automatic routing without config reloads; static file for entrypoints/certificates.

### 5. Prometheus Configuration
**Decision:** File-based static scrape config (prometheus.yml) with container names as targets.
**Rationale:** Simple, no service discovery overhead for fixed stack.

### 6. Grafana Provisioning
**Decision:** File-based provisioning for datasources and dashboards (JSON files in /etc/grafana/provisioning).
**Rationale:** Dashboards as code, version controlled, reproducible.

### 7. PostgreSQL Persistence
**Decision:** Named Docker volumes (postgres_data, grafana_data).
**Rationale:** Survives container recreation; simple backup/restore via docker exec.

### 8. CI/CD Pipeline
**Decision:** GitHub Actions with OIDC for cloud auth, Environments for approval gates.
**Rationale:** Native GitHub integration; OIDC eliminates static credentials; Environments provide manual approval.

### 9. Remote State
**Decision:** S3 bucket (AWS) or GCS bucket (GCP) with DynamoDB table (AWS) or Cloud Storage locking (GCP).
**Rationale:** Provider-native locking; standard Terraform pattern.

### 10. VM Provisioning
**Decision:** cloud-init/user_data script installs Docker, pulls compose file, runs docker compose up.
**Rationale:** Immutable infrastructure pattern; no SSH required for app deployment.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Single point of failure (single VM) | Acceptable for dev/QA scope; documented in proposal |
| No real TLS in development | Use Traefik self-signed certs or simulate via headers; document limitation |
| Terraform state lock contention | DynamoDB/Cloud Storage locking; keep apply serial |
| Docker Compose not production-grade | Document as dev/QA only; recommend K8s for production |
| Cloud provider credential management | OIDC + GitHub Environments; no static keys in repo |
| Data loss on VM termination | Named volumes persist; backup strategy documented |
| Drift between Terraform and actual state | Periodic drift detection workflow; manual remediation |

## Migration Plan

1. Initialize Terraform backend (run once per environment)
2. Run `terraform init` → `terraform plan` → `terraform apply`
3. SSH to VM (or use SSM/Serial Console) to verify Docker Compose startup
4. Access services via Traefik dashboard (port 8080) and Grafana (port 3000)
5. For updates: modify Terraform/Docker Compose → PR → review plan → merge → auto-apply

Rollback: `terraform destroy` removes infrastructure; Docker volumes persist unless explicitly removed.

## Open Questions

1. Should the dummy application be a simple HTTP server or a more realistic microservice?
2. Do we need log aggregation (Loki) in addition to metrics?
3. Should we add a Makefile or script for common operations (deploy, destroy, logs)?