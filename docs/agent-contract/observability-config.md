# Agent Contract: Observability Configuration Completion (Tasks 3.3, 4.3, 5.2, 5.3, 6.2, 6.3)

## Spec Reference
- Primary: `openspec/changes/terraform-observability-stack/specs/observability/prometheus-metrics/spec.md`
- Primary: `openspec/changes/terraform-observability-stack/specs/observability/grafana-dashboards/spec.md`
- Primary: `openspec/changes/terraform-observability-stack/specs/database/postgresql-persistence/spec.md`
- Primary: `openspec/changes/terraform-observability-stack/specs/networking/traefik-reverse-proxy/spec.md`
- Tasks: `openspec/changes/terraform-observability-stack/tasks.md` (Tasks 3.3, 4.3, 5.2, 5.3, 6.2, 6.3)

## Permitted Files
**MUST ONLY MODIFY/CREATE THESE FILES:**
- `compose/prometheus/prometheus.yml` (add remote write)
- `compose/grafana/provisioning/dashboards/` (add dashboard JSON files)
- `compose/grafana/provisioning/dashboards/dashboards.yml` (update if needed)
- `compose/docker-compose.yml` (add PostgreSQL resource limits, Traefik middleware)
- `compose/traefik/traefik.yml` (add HTTP->HTTPS redirect middleware, basic auth)
- `compose/README.md` (documentation)
- Any new files under `compose/`

**NEVER MODIFY:**
- Any spec files under `openspec/`
- Terraform files in `terraform/`
- Existing working configurations unless required

## Interface Contract

### Task 3.3: Prometheus Remote Write (Optional)
- Add `remote_write` section to `prometheus.yml` conditioned on `REMOTE_WRITE_URL` environment variable
- Use templating or conditional logic to include only when variable is set

### Task 4.3: Grafana Dashboard JSON Files
Create 4 dashboard JSON files in `compose/grafana/provisioning/dashboards/`:
1. **traefik-dashboard.json**: Traefik proxy metrics (requests, latency, errors, entrypoints)
2. **app-dashboard.json**: Application metrics (request count, latency, errors, active connections)
3. **postgres-dashboard.json**: PostgreSQL metrics (connections, queries, cache hit ratio, size)
4. **node-exporter-dashboard.json**: System metrics (CPU, memory, disk, network)

Each dashboard must:
- Have unique `uid` field
- Use Prometheus datasource (provisioned)
- Be valid Grafana JSON format
- Include appropriate panels for the service

### Task 5.2: PostgreSQL Backup Strategy Documentation
- Create `compose/backup/postgres-backup.sh` script
- Document usage in `compose/README.md`
- Script should use `pg_dump` via `docker exec`
- Support both backup and restore operations

### Task 5.3: PostgreSQL Resource Limits
- Add `deploy.resources.limits` and `deploy.resources.reservations` to postgres service in `docker-compose.yml`
- Memory limit: 512M, reservation: 256M
- CPU limit: 0.5, reservation: 0.25

### Task 6.2: HTTP to HTTPS Redirect Middleware
- Add redirect middleware to `traefik.yml`
- Configure entrypoints: web (80) -> websecure (443) redirect
- Since no real TLS certs in dev, use header-based simulation

### Task 6.3: Traefik Dashboard Basic Auth
- Add basic auth middleware to `traefik.yml`
- Configure dashboard router with auth middleware
- Credentials via environment variables (`TRAEFIK_DASHBOARD_USER`, `TRAEFIK_DASHBOARD_PASSWORD`)

## Verification Commands
```bash
# Prometheus config validation
promtool check config compose/prometheus/prometheus.yml

# Docker Compose validation
docker compose config --quiet

# Traefik config validation
traefik --configFile=compose/traefik/traefik.yml --validate 2>/dev/null || echo "traefik binary not available, skipping"

# Grafana dashboard JSON validation
python3 -m json.tool compose/grafana/provisioning/dashboards/*.json > /dev/null && echo "All JSON valid"

# Backup script syntax
bash -n compose/backup/postgres-backup.sh
```

## Definition of Done
- [ ] Task 3.3: Remote write in prometheus.yml (conditional on env var)
- [ ] Task 4.3: 4 dashboard JSON files created and valid
- [ ] Task 5.2: Backup script created and documented
- [ ] Task 5.3: PostgreSQL resource limits in docker-compose.yml
- [ ] Task 6.2: HTTP->HTTPS redirect middleware in traefik.yml
- [ ] Task 6.3: Basic auth for Traefik dashboard in traefik.yml
- [ ] All verification commands pass
- [ ] All files documented per code-doc-standard
- [ ] No secrets in code

## Project Profile
**Type:** IaC (Docker Compose / Observability)
**Verification:** Docker Compose config, promtool, JSON validation
**Skills:** grafana-dashboards, prometheus-configuration, code-doc-standard

## Report Format
Return summary with:
1. Task completion status (3.3, 4.3, 5.2, 5.3, 6.2, 6.3)
2. Command outputs proving verification passes
3. Any blockers
4. List of files created/modified