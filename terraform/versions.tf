# ==============================================================================
# Description: Required Terraform version and provider versions for the
#   observability stack infrastructure. Pins AWS and GCP providers to compatible
#   major versions to ensure reproducible infrastructure deployments.
# Author: Infrastructure Team
# Usage: This file is automatically loaded by Terraform during initialization.
#   No direct execution needed.
# Dependencies: terraform >= 1.5, aws provider ~> 5.0, google provider ~> 5.0
# ==============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}