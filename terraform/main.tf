# ==============================================================================
# Description: Main Terraform configuration for observability stack infrastructure.
#   Provisions VM, networking (security groups/firewall), and associated resources
#   on AWS or GCP based on the cloud_provider variable. Uses conditional resource
#   creation with count to support multi-cloud deployments from a single config.
# Author: Infrastructure Team
# Usage: Run 'terraform init' then 'terraform plan -var-file=example.tfvars' to
#   preview changes. Apply with 'terraform apply -var-file=example.tfvars'.
# Dependencies: terraform >= 1.5, aws provider ~> 5.0, google provider ~> 5.0
# ==============================================================================

# ──────────────────────────────────────────────────────────────────────────────
# LOCALS: Computed values and conditional logic
# ──────────────────────────────────────────────────────────────────────────────

locals {
  is_aws = var.cloud_provider == "aws"
  is_gcp = var.cloud_provider == "gcp"

  # Common ports for observability stack: SSH, HTTP, HTTPS, Grafana, Prometheus,
  # Loki, PostgreSQL
  allowed_ports = [22, 80, 443, 3000, 8080, 9090, 5432]

  # Common tags merged with user-provided tags
  common_tags = merge(
    {
      Name        = "observability-stack-vm"
      Environment = "production"
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# ──────────────────────────────────────────────────────────────────────────────
# PROVIDER CONFIGURATIONS (aliased for conditional use)
# ──────────────────────────────────────────────────────────────────────────────

provider "aws" {
  alias                       = "aws"
  region                      = var.cloud_provider == "aws" ? var.region : "us-east-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

provider "google" {
  alias       = "gcp"
  project     = var.project_id != "" ? var.project_id : "mock-project"
  region      = var.region
  credentials = fileexists("mock-gcp-credentials.json") ? "mock-gcp-credentials.json" : null
}

# ──────────────────────────────────────────────────────────────────────────────
# AWS RESOURCES (created when cloud_provider == "aws")
# ──────────────────────────────────────────────────────────────────────────────

# Security Group allowing required ports
resource "aws_security_group" "observability_sg" {
  count       = local.is_aws ? 1 : 0
  name        = "observability-stack-sg"
  description = "Security group for observability stack VM"
  vpc_id      = var.aws_vpc_id
  provider    = aws.aws

  dynamic "ingress" {
    for_each = local.allowed_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow port ${ingress.value}"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = local.common_tags
}

# AWS EC2 Instance
resource "aws_instance" "observability_vm" {
  count                  = local.is_aws ? 1 : 0
  ami                    = var.aws_ami
  instance_type          = var.instance_type
  subnet_id              = var.aws_subnet_id
  vpc_security_group_ids = [aws_security_group.observability_sg[0].id]
  key_name               = "observability-key"
  user_data              = filebase64("${path.module}/user_data.sh")
  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
    encrypted   = true
  }
  provider = aws.aws

  tags = merge(local.common_tags, {
    Name = "observability-stack-vm"
  })
}

# AWS Key Pair for SSH access
resource "aws_key_pair" "observability_key" {
  count      = local.is_aws ? 1 : 0
  key_name   = "observability-key"
  public_key = var.ssh_public_key
  provider   = aws.aws
}

# ──────────────────────────────────────────────────────────────────────────────
# GCP RESOURCES (created when cloud_provider == "gcp")
# ──────────────────────────────────────────────────────────────────────────────

# GCP Compute Network (default network)
resource "google_compute_network" "default" {
  count                   = local.is_gcp ? 1 : 0
  name                    = "observability-network"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  project                 = var.project_id
  provider                = google.gcp
}

# GCP Subnetwork
resource "google_compute_subnetwork" "default" {
  count         = local.is_gcp ? 1 : 0
  name          = "observability-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.default[0].id
  project       = var.project_id
  provider      = google.gcp
}

# GCP Firewall Rules for allowed ports
resource "google_compute_firewall" "observability_firewall" {
  count         = local.is_gcp ? 1 : 0
  name          = "observability-stack-firewall"
  network       = google_compute_network.default[0].name
  project       = var.project_id
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]
  provider      = google.gcp

  dynamic "allow" {
    for_each = local.allowed_ports
    content {
      protocol = "tcp"
      ports    = [allow.value]
    }
  }

  target_tags = ["observability-vm"]
}

# GCP Compute Instance
resource "google_compute_instance" "observability_vm" {
  count        = local.is_gcp ? 1 : 0
  name         = "observability-stack-vm"
  machine_type = var.instance_type
  zone         = "${var.region}-a"
  project      = var.project_id
  provider     = google.gcp

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/${var.gcp_image_family}"
      size  = var.volume_size
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.default[0].id
    access_config {
      # Ephemeral public IP
    }
  }

  metadata = {
    ssh-keys  = "ubuntu:${var.ssh_public_key}"
    user-data = filebase64("${path.module}/user_data.sh")
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  tags = ["observability-vm"]

  labels = local.common_tags
}