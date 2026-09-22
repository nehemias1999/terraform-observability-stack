# ==============================================================================
# Description: Terraform backend configuration for remote state storage with
#   locking. Uses local backend for testing/development. For production, override
#   with S3 (AWS) or GCS (GCP) backend via -backend-config flags or by editing
#   this file directly.
# Author: Infrastructure Team
# Usage: 
#   Development: terraform init (uses local backend)
#   AWS Production: terraform init -backend-config="bucket=my-tf-state" \
#                        -backend-config="key=observability/terraform.tfstate" \
#                        -backend-config="region=us-east-1" \
#                        -backend-config="dynamodb_table=tf-lock" \
#                        -backend-config="encrypt=true" -reconfigure
#   GCP Production: terraform init -backend-config="bucket=my-tf-state-bucket" \
#                        -backend-config="prefix=observability/terraform.tfstate" \
#                        -reconfigure
# Dependencies: terraform >= 1.5, AWS S3/DynamoDB or GCP Cloud Storage
# ==============================================================================

terraform {
  # Local backend for development/testing (no external dependencies)
  backend "local" {
    path = "terraform.tfstate"
  }

  # AWS S3 Backend with DynamoDB locking (for production AWS deployments)
  # Uncomment and configure for production use:
  # backend "s3" {
  #   bucket         = "terraform-state-bucket"
  #   key            = "observability-stack/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-state-lock"
  #   encrypt        = true
  # }

  # GCP GCS Backend with locking (for production GCP deployments)
  # Uncomment and configure for production use:
  # backend "gcs" {
  #   bucket  = "terraform-state-bucket"
  #   prefix  = "observability-stack/terraform.tfstate"
  # }
}