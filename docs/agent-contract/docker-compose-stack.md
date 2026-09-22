# Agent Contract: Docker Compose Stack (Tasks 2.1-2.5)

## Spec Reference
- Primary: `openspec/changes/terraform-observability-stack/specs/infrastructure/docker-compose-stack/spec.md`
- Related: `openspec/changes/terraform-observability-stack/design.md` (Decisions 2, 3)
- Tasks: `openspec/changes/terraform-observability-stack/tasks.md` (Tasks 2.1-2.5)

## Permitted Files
**MUST ONLY MODIFY/CREATE THESE FILES:**
- `compose/docker-compose.yml`
- `compose/.env.example`
- `compose/traefik/traefik.yml` (for Traefik labels reference)
- Any new files under `compose/`

**NEVER MODIFY:**
- Any spec files under `openspec/`
- Any files outside `compose/` directory (except docs/agent-contract/)
- Terraform files in `terraform/`

## Interface Contract

### Docker Compose File (compose/docker-compose.yml)
Services to define:
1. **traefik**: Reverse proxy (image: traefik:v3.0)
   - Ports: 80, 443, 8080 (dashboard), 8081 (metrics)
   - Labels: `traefik.enable=true`, dashboard routing
   - Volumes: /var/run/docker.sock:/var/run/docker.sock, ./traefik/traefik.yml:/etc/traefik/traefik.yml
   - Networks: observability

2. **prometheus**: Metrics collection (image: prom/prometheus:v2.47)
   - Ports: 9090
   - Volumes: ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml, prometheus_data:/prometheus
   - Command: --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus --web.enable-lifecycle
   - Networks: observability

3. **grafana**: Dashboards (image: grafana/grafana:10.1)
   - Ports: 3000
   - Volumes: grafana_data:/var/lib/grafana, ./grafana/provisioning:/etc/grafana/provisioning
   - Environment: GF_SECURITY_ADMIN_USER, GF_SECURITY_ADMIN_PASSWORD, GF_USERS_ALLOW_SIGN_UP=false
   - Networks: observability

4. **postgres**: Database (image: postgres:15-alpine)
   - Ports: 5432
   - Volumes: postgres_data:/var/lib/postgresql/data
   - Environment: POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD
   - Networks: observability

5. **app**: Dummy application (to be implemented in later task)
   - Ports: 8080 (internal)
   - Labels: Traefik routing labels
   - Networks: observability

6. **node-exporter**: Host metrics (image: prom/node-exporter:v1.6)
   - Ports: 9100
   - Volumes: /proc:/host/proc:ro, /sys:/host/sys:ro, /:/rootfs:ro
   - Networks: observability

7. **postgres-exporter**: PostgreSQL metrics (image: prometheuscommunity/postgres-exporter:v0.15)
   - Ports: 9187
   - Environment: DATA_SOURCE_NAME
   - Networks: observability

### Named Volumes (Task 2.3)
- `postgres_data`
- `grafana_data`
- `prometheus_data`

### Health Checks (Task 2.4)
Each service MUST have a healthcheck:
- traefik: `wget -q --spider http://localhost:8080/ping`
- prometheus: `wget -q --spider http://localhost:9090/-/healthy`
- grafana: `wget -q --spider http://localhost:3000/api/health`
- postgres: `pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}`
- node-exporter: `wget -q --spider http://localhost:9100/metrics`
- postgres-exporter: `wget -q --spider http://localhost:9187/metrics`

### Traefik Labels (Task 2.5)
Services must have labels for automatic routing:
- `traefik.enable=true`
- `traefik.http.routers.<service>.rule=Host(\`<domain>\`)`
- `traefik.http.services.<service>.loadbalancer.server.port=<port>`

### Environment Variables (Task 2.2)
`compose/.env.example` with all required variables:
- Cloud provider specific
- Domain names
- Passwords (marked sensitive)
- Retention periods
- Scrape intervals

## Verification Commands (IaC Profile + Docker)
```bash
# Validate compose file
docker compose config

# Check syntax
docker compose -f compose/docker-compose.yml config --quiet

# Verify volumes defined
docker compose -f compose/docker-compose.yml config --volumes

# Dry-run (requires Docker daemon)
docker compose -f compose/docker-compose.yml up --dry-run
```

## Definition of Done
- [ ] Task 2.1: compose/docker-compose.yml with all 7 services
- [ ] Task 2.2: compose/.env.example with all variables documented
- [ ] Task 2.3: Named volumes defined and referenced
- [ ] Task 2.4: Health checks on all services
- [ ] Task 2.5: Traefik labels for automatic routing
- [ ] `docker compose config` validates without errors
- [ ] All files documented per code-doc-standard
- [ ] No secrets in code

## Project Profile
**Type:** IaC (Docker Compose)
**Verification:** Docker Compose config validation
**Skills:** terraform-module-library, code-doc-standard, grafana-dashboards, prometheus-configuration

## Report Format
Return summary with:
1. Task completion status (2.1-2.5)
2. Command outputs showing verification passes
3. Any blockers
4. List of files created/modified