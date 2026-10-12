# Spec Delta

## Purpose

Provides PostgreSQL database with persistent storage via Docker named volumes for the observability stack's data persistence needs.

## ADDED Requirements

### Requirement: PostgreSQL service with persistence
The system SHALL run PostgreSQL 15+ with a named Docker volume for data persistence.

#### Scenario: Data survives container recreation
- **WHEN** postgres container is recreated
- **THEN** database data is preserved in the named volume

### Requirement: Database initialization
The system SHALL support automatic database and user creation via environment variables (POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD).

#### Scenario: Database and user created on first run
- **WHEN** PostgreSQL starts for the first time
- **THEN** the specified database, user, and password are created

### Requirement: Connection accessibility
The system SHALL expose PostgreSQL on port 5432 within the Docker network for application connections.

#### Scenario: Application connects to PostgreSQL
- **WHEN** application uses postgres:5432 as connection string
- **THEN** connection succeeds with configured credentials

### Requirement: Backup and restore capability
The system SHALL support logical backup via pg_dump and restore via psql through Docker exec.

#### Scenario: Backup completes successfully
- **WHEN** pg_dump is executed against running container
- **THEN** SQL dump file is created with all database objects

### Requirement: Resource limits
The system SHALL configure memory and CPU limits for PostgreSQL container to prevent resource exhaustion.

#### Scenario: Container respects resource limits
- **WHEN** container runs under load
- **THEN** memory usage stays within configured limits