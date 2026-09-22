# ==============================================================================
# Description: Example Terraform variables file with mock credentials for
#   dry-run planning. Replace with actual values for real deployments.
#   NEVER commit real credentials to version control.
# Author: Infrastructure Team
# Usage: terraform plan -var-file=example.tfvars
# Dependencies: variables.tf
# ==============================================================================

# Cloud provider: "aws" or "gcp"
cloud_provider = "aws"

# Region for deployment
region = "us-east-1"

# Instance type (AWS: t3.medium, GCP: e2-medium)
instance_type = "t3.medium"

# SSH public key (mock value for planning)
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQMockKeyForPlanningOnly user@example.com"

# AWS-specific (required when cloud_provider = "aws")
aws_ami = "ami-0c02fb55956c7d316" # Ubuntu 22.04 LTS in us-east-1 (mock)

# GCP-specific (required when cloud_provider = "gcp")
# project_id = "my-gcp-project"
# gcp_image_family = "ubuntu-2204-lts"

# Optional: Custom tags
tags = {
  Project     = "observability-stack"
  Environment = "test"
  ManagedBy   = "terraform"
}

# Optional: Root volume size in GB (default: 20)
volume_size = 20