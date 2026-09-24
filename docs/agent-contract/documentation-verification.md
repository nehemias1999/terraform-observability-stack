# Agent Contract: Documentation & Verification (Tasks 9.1-9.5)

## Spec Reference
- Primary: `openspec/changes/terraform-observability-stack/tasks.md` (Tasks 9.1-9.5)
- No separate spec file; tasks defined in tasks.md

## Permitted Files
**MUST ONLY MODIFY/CREATE THESE FILES:**
- `README.md` (root - update with full project documentation)
- `terraform/README.md` (new - Terraform usage instructions)
- `compose/README.md` (update - ensure all services documented)
- Any new documentation files under `docs/` if needed

**NEVER MODIFY:**
- Any spec files under `openspec/`
- Terraform configuration files in `terraform/`
- Docker Compose files in `compose/`
- Application files in `compose/app/`
- CI/CD workflows in `.github/workflows/`

## Interface Contract

### Task 9.1: Root README.md
Create comprehensive root `README.md` following `readme-standard` skill:
- **Description**: Project purpose, architecture overview, tech stack
- **Technologies**: Terraform, Docker Compose, Prometheus, Grafana, PostgreSQL, Traefik
- **Architecture/Flow**: Diagram or description of components and data flow
- **Commands**: All verification commands (terraform, docker compose, promtool, etc.)
- **Setup**: Prerequisites, quick start, environment variables
- **Spec Reference**: Link to OpenSpec change
- **Verification**: `readme-standard` checklist passes, renders on GitHub

### Task 9.2: Terraform README.md
Create `terraform/README.md`:
- Usage instructions for Terraform module
- Required variables (cloud_provider, region, instance_type, etc.)
- Example tfvars files
- Backend configuration (S3/GCS)
- Outputs reference
- Verification: `terraform fmt -check && terraform validate` passes

### Task 9.3: Compose README.md (Verify/Update)
Ensure `compose/README.md` documents all services:
- Traefik: routing, middleware, entrypoints, dashboard auth
- Prometheus: scrape configs, remote write, retention
- Grafana: datasources, dashboards, provisioning
- PostgreSQL: configuration, backup script, resource limits
- App: endpoints, metrics, Traefik labels
- Node Exporter / Postgres Exporter: metrics exposed
- Environment variables reference
- Verification commands for each service

### Task 9.4: Full Integration Test
Document the integration test procedure (dry-run, no real apply):
- `terraform init` → `terraform plan` (with example tfvars)
- `docker compose config --quiet`
- `promtool check config compose/prometheus/prometheus.yml`
- `docker compose up -d` → verify all services healthy
- `curl` checks for each service endpoint
- `docker compose down` → `terraform destroy` (dry-run)
- Note: Real apply requires cloud credentials (documented but not executed)

### Task 9.5: OpenSpec Validate & Archive
- Run `openspec validate --all` (or `--changes`)
- Run `openspec archive terraform-observability-stack`
- Verify all specs archived successfully

## Verification Commands
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
promtool check config compose/prometheus/prometheus.yml

# OpenSpec validation
openspec validate --changes
openspec archive terraform-observability-stack

# JSON dashboard validation
python3 -m json.tool compose/grafana/provisioning/dashboards/*.json > /dev/null

# Backup script syntax
bash -n compose/backup/postgres-backup.sh
```

## Definition of Done
- [ ] Task 9.1: Root README.md complete per readme-standard
- [ ] Task 9.2: terraform/README.md created with usage instructions
- [ ] Task 9.3: compose/README.md verified complete for all services
- [ ] Task 9.4: Integration test procedure documented (dry-run commands)
- [ ] Task 9.5: openspec validate passes, specs archived
- [ ] All verification commands pass
- [ ] All files documented per code-doc-standard
- [ ] No secrets in documentation

## Project Profile
**Type:** Documentation / Verification
**Verification:** readme-standard, terraform fmt/validate, docker compose config, promtool, openspec
**Skills:** readme-standard, code-doc-standard, terraform-module-library, openspec

## Report Format
Return summary with:
1. Task completion status (9.1, 9.2, 9.3, 9.4, 9.5)
2. Command outputs proving verification passes
3. Any blockers
3. List of files created/modified