# Spec Delta

## Purpose

Configures Traefik as a reverse proxy with automatic service discovery, SSL termination (simulated), and metrics exposition for the observability stack.

## ADDED Requirements

### Requirement: Automatic service discovery via Docker labels
The system SHALL automatically route traffic to services based on Docker Compose labels.

#### Scenario: New service routed automatically
- **WHEN** a service with traefik.enable=true label is added
- **THEN** Traefik creates routes without configuration reload

### Requirement: HTTP to HTTPS redirect (simulated)
The system SHALL redirect HTTP traffic to HTTPS entrypoint (simulated via headers since no real TLS certs in dev).

#### Scenario: HTTP requests redirected
- **WHEN** request arrives on port 80
- **THEN** response redirects to HTTPS (port 443) with appropriate headers

### Requirement: Dashboard and API exposure
The system SHALL expose Traefik dashboard on port 8080 and API on port 8080 with basic auth protection.

#### Scenario: Dashboard accessible with auth
- **WHEN** accessing traefik dashboard URL
- **THEN** basic auth challenge is presented and valid credentials grant access

### Requirement: Metrics exposition for Prometheus
The system SHALL expose Prometheus metrics on port 8080/metrics for scraping.

#### Scenario: Metrics endpoint returns Prometheus format
- **WHEN** GET /metrics on port 8080
- **THEN** response contains Traefik metrics in Prometheus exposition format

### Requirement: Middleware for common patterns
The system SHALL provide middleware for rate limiting, headers, and compression.

#### Scenario: Rate limiting applied
- **WHEN** rate limit middleware is attached to a route
- **THEN** requests exceeding limit receive 429 response