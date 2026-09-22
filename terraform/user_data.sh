#!/usr/bin/env bash
# ==============================================================================
# Description: Cloud-init user data script for observability stack VM. Installs
#   Docker Engine, Docker Compose plugin, creates application directory, pulls
#   docker-compose.yml from repository, and starts the monitoring stack.
# Author: Infrastructure Team
# Usage: This script is executed automatically by cloud-init on VM first boot.
#   Not intended for direct execution.
# Dependencies: curl, apt-get, systemd, docker.io, docker-compose-plugin
# Output: Logs to /var/log/user-data.log
# Exit Codes: 0 on success, non-zero on failure
# ==============================================================================

set -euo pipefail

# Redirect all output to log file
exec > /var/log/user-data.log 2>&1

echo "=== Starting observability stack bootstrap at $(date) ==="

# Update package index
echo "Updating package index..."
apt-get update -y

# Install prerequisites for Docker
echo "Installing prerequisites..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
echo "Adding Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine and Compose plugin
echo "Installing Docker Engine and Compose plugin..."
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker service
echo "Enabling Docker service..."
systemctl enable docker
systemctl start docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Create application directory
echo "Creating application directory..."
mkdir -p /opt/observability-stack
cd /opt/observability-stack

# Create docker-compose.yml for observability stack
echo "Creating docker-compose.yml..."
cat > docker-compose.yml << 'COMPOSE_EOF'
version: '3.8'

services:
  # Traefik reverse proxy for HTTP/HTTPS entrypoints
  traefik:
    image: traefik:v3.0
    container_name: traefik
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=admin@example.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
      - "8081:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik_letsencrypt:/letsencrypt
    restart: unless-stopped

  # Prometheus for metrics collection
  prometheus:
    image: prom/prometheus:v2.47.0
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.prometheus.rule=Host(`prometheus.local`)"
      - "traefik.http.routers.prometheus.entrypoints=web"
      - "traefik.http.services.prometheus.loadbalancer.server.port=9090"

  # Grafana for visualization
  grafana:
    image: grafana/grafana:10.1.0
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
    restart: unless-stopped
    depends_on:
      - prometheus
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.rule=Host(`grafana.local`)"
      - "traefik.http.routers.grafana.entrypoints=web"
      - "traefik.http.services.grafana.loadbalancer.server.port=3000"

  # Loki for log aggregation
  loki:
    image: grafana/loki:2.9.0
    container_name: loki
    ports:
      - "3100:3100"
    volumes:
      - ./loki-config.yml:/etc/loki/local-config.yaml
      - loki_data:/loki
    command: -config.file=/etc/loki/local-config.yaml
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.loki.rule=Host(`loki.local`)"
      - "traefik.http.routers.loki.entrypoints=web"
      - "traefik.http.services.loki.loadbalancer.server.port=3100"

  # Promtail for log shipping
  promtail:
    image: grafana/promtail:2.9.0
    container_name: promtail
    volumes:
      - /var/log:/var/log
      - ./promtail-config.yml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml
    restart: unless-stopped

  # PostgreSQL for data persistence
  postgres:
    image: postgres:15-alpine
    container_name: postgres
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_DB=observability
      - POSTGRES_USER=observability
      - POSTGRES_PASSWORD=observability
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  # Node Exporter for host metrics
  node-exporter:
    image: prom/node-exporter:v1.6.1
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    restart: unless-stopped

  # cAdvisor for container metrics
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.47.0
    container_name: cadvisor
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    restart: unless-stopped

volumes:
  prometheus_data:
  grafana_data:
  loki_data:
  postgres_data:
  traefik_letsencrypt:
COMPOSE_EOF

# Create Prometheus configuration
echo "Creating Prometheus configuration..."
cat > prometheus.yml << 'PROM_EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']

  - job_name: 'loki'
    static_configs:
      - targets: ['loki:3100']
PROM_EOF

# Create Loki configuration
echo "Creating Loki configuration..."
cat > loki-config.yml << 'LOKI_EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
LOKI_EOF

# Create Promtail configuration
echo "Creating Promtail configuration..."
cat > promtail-config.yml << 'PROMTAIL_EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log
PROMTAIL_EOF

# Start the stack
echo "Starting observability stack with Docker Compose..."
docker compose up -d

echo "=== Bootstrap completed at $(date) ==="
echo "Observability stack services:"
echo "  - Traefik:      http://<public-ip>:8081 (dashboard)"
echo "  - Grafana:      http://<public-ip>:3000 (admin/admin)"
echo "  - Prometheus:   http://<public-ip>:9090"
echo "  - Loki:         http://<public-ip>:3100"
echo "  - Node Exporter: http://<public-ip>:9100"
echo "  - cAdvisor:     http://<public-ip>:8080"
echo "  - PostgreSQL:   <public-ip>:5432"
echo "  - HTTP/HTTPS:   http://<public-ip>:80 / https://<public-ip>:443 (via Traefik)"