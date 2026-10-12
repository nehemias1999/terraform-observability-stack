# Proposal

## Why

This project demonstrates Infrastructure as Code (IaC) and Observability mastery by provisioning a complete observability stack (Traefik, Prometheus, Grafana, PostgreSQL) on a single VM using Terraform and Docker Compose. It serves as a portfolio piece showing cost-effective, reproducible infrastructure deployment for development/QA environments.

## What Changes

- New Terraform configuration for provisioning cloud infrastructure (AWS EC2 / GCP Compute Engine)
- New Docker Compose stack with Traefik (reverse proxy), Prometheus (metrics), Grafana (dashboards), PostgreSQL (persistence), and a dummy consumer app
- New Prometheus scrape configuration for all services
- New Grafana dashboard provisioning as code
- New GitHub Actions CI/CD pipeline for Terraform validate/plan/apply
- New cloud-init/user_data script for VM provisioning (Docker installation, compose deployment)

## Capabilities

### New Capabilities
- `infrastructure/terraform-provisioning`: Terraform modules for cloud VM provisioning with networking (security groups, SSH access)
- `infrastructure/docker-compose-stack`: Docker Compose orchestration for the full observability stack
- `observability/prometheus-metrics`: Prometheus configuration for scraping Traefik, app, and PostgreSQL metrics
- `observability/grafana-dashboards`: Grafana dashboard provisioning with pre-configured dashboards
- `database/postgresql-persistence`: PostgreSQL with named Docker volumes for data persistence
- `networking/traefik-reverse-proxy`: Traefik configuration with SSL termination (simulated) and routing
- `ci-cd/terraform-pipeline`: GitHub Actions workflow for Terraform fmt, validate, plan, and apply

### Modified Capabilities
- None (this is a new project)

## Impact

- New directory structure: `terraform/`, `compose/`, `.github/workflows/`
- New files: main.tf, variables.tf, outputs.tf, user_data.sh, docker-compose.yml, prometheus.yml, Grafana provisioning files, terraform-ci.yml
- Cloud provider credentials required for actual deployment (AWS/GCP)
- Docker and Docker Compose required on target VM