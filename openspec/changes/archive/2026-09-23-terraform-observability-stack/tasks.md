# Tasks

## 1. Terraform Infrastructure ✅ COMPLETED (PR #1)

- [x] 1.1 Create terraform/main.tf with provider configuration (AWS/GCP), VM resource, security groups/firewall rules, and outputs. Verify: `terraform fmt -check && terraform validate` passes
- [x] 1.2 Create terraform/variables.tf with all input variables (cloud_provider, region, instance_type, ssh_key, etc.). Verify: `terraform validate` passes with example tfvars
- [x] 1.3 Create terraform/outputs.tf with public_ip, private_ip, instance_id outputs. Verify: `terraform apply -auto-approve` (in test) produces expected outputs
- [x] 1.4 Create terraform/user_data.sh with cloud-init script to install Docker, Docker Compose, pull compose file, and start stack. Verify: script is syntactically valid bash and installs Docker on target OS
- [x] 1.5 Create terraform/backend.tf or backend configuration for S3/GCS remote state with DynamoDB/Cloud Storage locking. Verify: `terraform init` configures backend correctly
- [x] 1.6 Create terraform/versions.tf with required provider versions. Verify: `terraform init` downloads correct provider versions

## 2. Docker Compose Stack ✅ COMPLETED (PR #2)

- [x] 2.1 Create compose/docker-compose.yml with all services (traefik, prometheus, grafana, postgres, app, node-exporter, postgres-exporter). Verify: `docker compose config` validates without errors
- [x] 2.2 Create compose/.env.example with all required environment variables. Verify: all variables documented with descriptions
- [x] 2.3 Define named volumes (postgres_data, grafana_data, prometheus_data) in docker-compose.yml. Verify: `docker volume ls` shows volumes after `docker compose up -d`
- [x] 2.4 Configure service health checks for all services in docker-compose.yml. Verify: `docker compose ps` shows all services as healthy
- [x] 2.5 Configure Traefik labels on each service for automatic routing. Verify: Traefik dashboard shows routes for all services

## 3. Prometheus Configuration (PARTIALLY COMPLETED)

- [x] 3.1 Create compose/prometheus/prometheus.yml with scrape configs for traefik, app, postgres-exporter, node-exporter. Verify: `promtool check config compose/prometheus/prometheus.yml` passes
- [x] 3.2 Configure scrape intervals, timeouts, and retention via environment variables. Verify: Prometheus UI shows targets with correct scrape intervals
- [ ] 3.3 Add Prometheus remote write configuration (optional). Verify: if REMOTE_WRITE_URL set, samples forwarded

## 4. Grafana Provisioning (PARTIALLY COMPLETED)

- [x] 4.1 Create compose/grafana/provisioning/datasources/datasources.yml with Prometheus datasource. Verify: Grafana UI shows Prometheus datasource configured
- [x] 4.2 Create compose/grafana/provisioning/dashboards/dashboard-provider.yml. Verify: Grafana loads dashboards from provisioned path
- [ ] 4.3 Add pre-configured dashboard JSON files for Traefik, App, PostgreSQL, Node Exporter. Verify: Dashboards visible in Grafana UI with data
- [x] 4.4 Configure admin credentials via environment variables. Verify: Can login with GF_SECURITY_ADMIN_USER/PASSWORD

## 5. PostgreSQL Setup (PARTIALLY COMPLETED)

- [x] 5.1 Configure PostgreSQL service with POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD from environment. Verify: Database and user created on first startup
- [ ] 5.2 Configure pg_dump/pg_restore backup strategy documentation. Verify: Backup script produces valid SQL dump
- [ ] 5.3 Add resource limits (memory, CPU) for PostgreSQL container. Verify: `docker stats` shows limits respected

## 6. Traefik Configuration (PARTIALLY COMPLETED)

- [x] 6.1 Create compose/traefik/traefik.yml with entrypoints, API, metrics, and Docker provider config. Verify: `traefik --version` and config validation passes
- [ ] 6.2 Configure HTTP to HTTPS redirect middleware (simulated). Verify: Requests to port 80 redirect to 443
- [ ] 6.3 Configure basic auth for Traefik dashboard. Verify: Dashboard requires authentication
- [x] 6.4 Verify Prometheus metrics endpoint at :8080/metrics. Verify: `curl localhost:8080/metrics` returns Prometheus format

## 7. Dummy Application

- [ ] 7.1 Create a simple HTTP application (Go/Python/Node) that exposes /metrics endpoint. Verify: Application starts and /metrics returns Prometheus format
- [ ] 7.2 Add application to docker-compose.yml with Traefik labels. Verify: Accessible via Traefik routing
- [ ] 7.3 Instrument application with basic metrics (request count, latency, errors). Verify: Metrics appear in Prometheus

## 8. CI/CD Pipeline

- [ ] 8.1 Create .github/workflows/terraform-ci.yml with fmt, validate, plan jobs. Verify: Workflow runs on PR and passes for valid code
- [ ] 8.2 Add plan comment posting on PRs. Verify: PR comment appears with terraform plan output
- [ ] 8.3 Add apply job with manual approval gate (Environment). Verify: Workflow pauses for approval on merge to main
- [ ] 8.4 Configure OIDC authentication for AWS/GCP in workflow. Verify: Workflow authenticates without static credentials
- [ ] 8.5 Add scheduled drift detection workflow (optional). Verify: Scheduled run detects drift if any

## 9. Documentation & Verification

- [ ] 9.1 Create root README.md with project description, architecture, setup, and verification commands. Verify: README renders correctly on GitHub
- [ ] 9.2 Create terraform/README.md with usage instructions. Verify: Instructions work for fresh clone
- [ ] 9.3 Create compose/README.md with service details and configuration. Verify: All services documented
- [ ] 9.4 Run full integration test: `terraform apply` → verify all services accessible → `terraform destroy`. Verify: End-to-end deployment works
- [ ] 9.5 Verify `openspec validate` passes and all specs archived. Verify: `openspec archive terraform-observability-stack` succeeds