# Spec Delta

## Purpose

Configures Prometheus to scrape metrics from all observability stack components (Traefik, application, PostgreSQL, node exporter) with appropriate scrape intervals and retention policies.

## ADDED Requirements

### Requirement: Multi-target scraping
The system SHALL scrape metrics from Traefik (8080), application (8080/metrics), PostgreSQL (9187), and node-exporter (9100).

#### Scenario: All targets scraped successfully
- **WHEN** Prometheus runs scrape cycles
- **THEN** all configured targets return 200 OK with metrics in Prometheus format

### Requirement: Scrape interval configuration
The system SHALL use a default scrape interval of 15s with 10s timeout, configurable via environment variable.

#### Scenario: Custom scrape interval applied
- **WHEN** SCRAPE_INTERVAL environment variable is set
- **THEN** Prometheus uses the custom interval for all scrape jobs

### Requirement: Metrics retention policy
The system SHALL retain metrics for 15 days by default with configurable retention via environment variable.

#### Scenario: Retention period respected
- **WHEN** RETENTION_DAYS environment variable is set
- **THEN** Prometheus retains data for the specified number of days

### Requirement: Service discovery via static config
The system SHALL use static target configuration with container names for service discovery in Docker Compose network.

#### Scenario: Targets resolved via container names
- **WHEN** Prometheus reads scrape config
- **THEN** targets use container names (traefik:8080, app:8080, postgres-exporter:9187, node-exporter:9100)

### Requirement: Remote write capability (optional)
The system MAY support remote write to external Prometheus-compatible endpoints.

#### Scenario: Remote write configured
- **WHEN** REMOTE_WRITE_URL environment variable is set
- **THEN** Prometheus forwards samples to the remote endpoint