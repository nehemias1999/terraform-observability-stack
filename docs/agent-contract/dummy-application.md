# Agent Contract: Dummy Application (Tasks 7.1-7.3)

## Spec Reference
- Primary: `openspec/changes/terraform-observability-stack/tasks.md` (Tasks 7.1, 7.2, 7.3)
- No separate spec file; tasks defined in tasks.md

## Permitted Files
**MUST ONLY MODIFY/CREATE THESE FILES:**
- `compose/app/` (new directory for application code)
- `compose/app/main.py` (Python HTTP application with /metrics endpoint)
- `compose/app/requirements.txt` (Python dependencies)
- `compose/app/Dockerfile` (Container image for the app)
- `compose/docker-compose.yml` (add app service with Traefik labels)
- `compose/README.md` (documentation for the app service)

**NEVER MODIFY:**
- Any spec files under `openspec/`
- Terraform files in `terraform/`
- Existing working configurations unless required
- Prometheus, Grafana, Traefik, PostgreSQL configs

## Interface Contract

### Task 7.1: Simple HTTP Application with /metrics
- Create a Python HTTP application (FastAPI/Flask) in `compose/app/main.py`
- Expose `/metrics` endpoint returning Prometheus format
- Expose `/health` endpoint for health checks
- Expose `/` endpoint returning basic info
- Use `prometheus-client` library for metrics generation
- Application must start on port 8000

### Task 7.2: Add to docker-compose.yml with Traefik Labels
- Add `app` service to `compose/docker-compose.yml`
- Use the custom Dockerfile from `compose/app/Dockerfile`
- Configure Traefik labels for routing:
  - `traefik.enable=true`
  - `traefik.http.routers.app.rule=Host(\`app.${DOMAIN:-localhost}\`)`
  - `traefik.http.routers.app.entrypoints=websecure`
  - `traefik.http.services.app.loadbalancer.server.port=8000`
- Add health check endpoint
- Connect to `observability` network
- Set appropriate restart policy

### Task 7.3: Instrument with Basic Metrics
- Add Prometheus metrics using `prometheus-client`:
  - `http_requests_total` (Counter) - total requests by method, path, status
  - `http_request_duration_seconds` (Histogram) - request latency
  - `http_requests_in_progress` (Gauge) - active requests
  - `http_errors_total` (Counter) - errors by type
- Metrics must appear in Prometheus when scraped
- Verify: `curl localhost:9090/api/v1/query?query=http_requests_total` returns data

## Verification Commands
```bash
# Docker Compose validation
docker compose -f compose/docker-compose.yml config --quiet

# Application syntax check
python3 -m py_compile compose/app/main.py

# Dockerfile syntax
docker build -t test-app compose/app/ --no-cache 2>&1 | head -20

# Prometheus metrics format validation
python3 -c "
import prometheus_client
print('prometheus-client available')
"

# Full stack test (if Docker running)
# docker compose -f compose/docker-compose.yml up -d app
# sleep 10
# curl -s http://localhost:8000/metrics | head -20
# curl -s http://localhost:9090/api/v1/query?query=http_requests_total
```

## Definition of Done
- [ ] Task 7.1: Python HTTP app with /metrics endpoint in Prometheus format
- [ ] Task 7.2: App service in docker-compose.yml with Traefik labels
- [ ] Task 7.3: Instrumented with request count, latency, errors metrics
- [ ] All verification commands pass
- [ ] All files documented per code-doc-standard
- [ ] No secrets in code

## Project Profile
**Type:** IaC (Docker Compose / Observability) + Application
**Verification:** Docker Compose config, Python syntax, Docker build, Prometheus metrics format
**Skills:** python-code-style, python-testing-patterns, code-doc-standard, prometheus-configuration

## Report Format
Return summary with:
1. Task completion status (7.1, 7.2, 7.3)
2. Command outputs proving verification passes
3. Any blockers
4. List of files created/modified