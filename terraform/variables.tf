# ==============================================================================
# Description: Input variables for the observability stack Terraform configuration.
#   Defines all required and optional variables for provisioning VM infrastructure
#   on AWS or GCP with conditional provider-specific settings.
# Author: Infrastructure Team
# Usage: Variables are referenced in main.tf and outputs.tf. Provide values via
#   terraform.tfvars, -var flags, or environment variables (TF_VAR_<name>).
# Dependencies: terraform >= 1.5, aws provider ~> 5.0, google provider ~> 5.0
# ==============================================================================

variable "cloud_provider" {
  description = "Target cloud provider for infrastructure provisioning"
  type        = string
  validation {
    condition     = contains(["aws", "gcp"], var.cloud_provider)
    error_message = "cloud_provider must be 'aws' or 'gcp'."
  }
}

variable "region" {
  description = "Cloud region for resource deployment (e.g., 'us-east-1' for AWS, 'us-central1' for GCP)"
  type        = string
  validation {
    condition     = length(var.region) > 0
    error_message = "region must not be empty."
  }
}

variable "instance_type" {
  description = "VM instance type/size (e.g., 't3.medium' for AWS, 'e2-medium' for GCP)"
  type        = string
  validation {
    condition     = length(var.instance_type) > 0
    error_message = "instance_type must not be empty."
  }
}

variable "ssh_public_key" {
  description = "SSH public key for VM access (OpenSSH format)"
  type        = string
  validation {
    condition     = length(var.ssh_public_key) > 0
    error_message = "ssh_public_key must not be empty."
  }
  sensitive = true
}

variable "project_id" {
  description = "GCP project ID (required when cloud_provider = 'gcp')"
  type        = string
  default     = ""
  validation {
    condition     = var.cloud_provider != "gcp" || length(var.project_id) > 0
    error_message = "project_id is required when cloud_provider is 'gcp'."
  }
}

variable "aws_ami" {
  description = "AWS AMI ID for Ubuntu 22.04 LTS (required when cloud_provider = 'aws')"
  type        = string
  default     = ""
  validation {
    condition     = var.cloud_provider != "aws" || length(var.aws_ami) > 0
    error_message = "aws_ami is required when cloud_provider is 'aws'."
  }
}

variable "gcp_image_family" {
  description = "GCP image family for Ubuntu 22.04 LTS (required when cloud_provider = 'gcp')"
  type        = string
  default     = "ubuntu-2204-lts"
  validation {
    condition     = var.cloud_provider != "gcp" || length(var.gcp_image_family) > 0
    error_message = "gcp_image_family is required when cloud_provider is 'gcp'."
  }
}

variable "aws_vpc_id" {
  description = "AWS VPC ID (optional, uses default VPC if not set). For dry-run with mock credentials, provide a mock value."
  type        = string
  default     = "vpc-mock12345"
}

variable "aws_subnet_id" {
  description = "AWS Subnet ID (optional, uses default subnet if not set). For dry-run with mock credentials, provide a mock value."
  type        = string
  default     = "subnet-mock12345"
}

variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "observability-stack"
    ManagedBy   = "terraform"
    Environment = "production"
  }
}

variable "volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20
  validation {
    condition     = var.volume_size >= 20
    error_message = "volume_size must be at least 20 GB."
  }
}