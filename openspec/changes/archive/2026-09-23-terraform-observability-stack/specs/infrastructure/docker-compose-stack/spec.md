# Spec Delta

## Purpose

Orchestrates the full observability stack (Traefik, Prometheus, Grafana, PostgreSQL, dummy app) using Docker Compose on the provisioned VM.

## ADDED Requirements

### Requirement: Multi-service orchestration
The system SHALL define and run all observability services as Docker containers via Docker Compose.

#### Scenario: All services start successfully
- **WHEN** docker-compose up -d is executed
- **THEN** all containers (traefik, prometheus, grafana, postgres, app) are running and healthy

### Requirement: Named volumes for persistence
The system SHALL use named Docker volumes for PostgreSQL data and Grafana configuration to survive container recreation.

#### Scenario: Data persists after container restart
- **WHEN** containers are recreated (docker-compose down && docker-compose up -d)
- **THEN** PostgreSQL data and Grafana dashboards/configuration are preserved

### Requirement: Service networking
The system SHALL configure Docker network for inter-service communication with service discovery via container names.

#### Scenario: Services communicate via container names
- **WHEN** Prometheus scrapes targets
- **THEN** it resolves traefik, app, and postgres by container names

### Requirement: Environment-based configuration
The system SHALL support configuration via environment variables for all services (passwords, ports, feature flags).

#### Scenario: Configuration via .env file
- **WHEN** docker-compose reads .env file
- **THEN** all services use the configured values (passwords, domains, retention)

### Requirement: Health checks for all services
The system SHALL define health checks for each service to enable Docker Compose dependency management.

#### Scenario: Health checks pass for all services
- **WHEN** docker-compose ps shows healthy status
- **THEN** all services report healthy within configured intervals