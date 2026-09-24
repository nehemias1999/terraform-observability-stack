# Terraform Module: Observability Stack Infrastructure

Provisions VM infrastructure (compute, networking, security) for the observability stack on AWS or GCP using a single configuration with conditional resource creation.

## Table of Contents

- [Usage](#usage)
- [Required Variables](#required-variables)
- [Optional Variables](#optional-variables)
- [Example tfvars Files](#example-tfvars-files)
- [Backend Configuration](#backend-configuration)
- [Outputs](#outputs)
- [Verification](#verification)

## Usage

```bash
cd terraform

# Initialize (local backend by default)
terraform init

# Plan with variables file
terraform plan -var-file=example-aws.tfvars

# Apply (requires real cloud credentials)
terraform apply -var-file=example-aws.tfvars

# View outputs
terraform output

# Destroy (when done)
terraform destroy -var-file=example-aws.tfvars
```

## Required Variables

| Variable | Description | Type | Validation |
|----------|-------------|------|------------|
| `cloud_provider` | Target cloud provider: `aws` or `gcp` | `string` | Must be `aws` or `gcp` |
| `region` | Cloud region for deployment | `string` | Non-empty |
| `instance_type` | VM instance type/size | `string` | Non-empty |
| `ssh_public_key` | SSH public key (OpenSSH format) | `string` | Non-empty, marked sensitive |

### Provider-Specific Required Variables

#### When `cloud_provider = "aws"`

| Variable | Description | Type | Validation |
|----------|-------------|------|------------|
| `aws_ami` | AWS AMI ID for Ubuntu 22.04 LTS | `string` | Non-empty when AWS |

#### When `cloud_provider = "gcp"`

| Variable | Description | Type | Validation |
|----------|-------------|------|------------|
| `project_id` | GCP project ID | `string` | Non-empty when GCP |

## Optional Variables

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `gcp_image_family` | GCP image family for Ubuntu 22.04 LTS | `string` | `ubuntu-2204-lts` |
| `aws_vpc_id` | AWS VPC ID (mock for dry-run) | `string` | `vpc-mock12345` |
| `aws_subnet_id` | AWS Subnet ID (mock for dry-run) | `string` | `subnet-mock12345` |
| `tags` | Map of tags applied to all resources | `map(string)` | See below |
| `volume_size` | Root volume size in GB | `number` | `20` (min 20) |

### Default Tags

```hcl
tags = {
  Project     = "observability-stack"
  ManagedBy   = "terraform"
  Environment = "production"
}
```

## Example tfvars Files

### AWS Example (`example-aws.tfvars`)

```hcl
cloud_provider  = "aws"
region          = "us-east-1"
instance_type   = "t3.medium"
ssh_public_key  = "ssh-rsa AAAAB3NzaC1yc2E... user@host"
aws_ami         = "ami-0abcdef1234567890"  # Ubuntu 22.04 LTS in us-east-1
aws_vpc_id      = "vpc-0123456789abcdef0"
aws_subnet_id   = "subnet-0123456789abcdef0"
volume_size     = 20
tags = {
  Project     = "observability-stack"
  Environment = "production"
  Owner       = "team-platform"
}
```

### GCP Example (`example-gcp.tfvars`)

```hcl
cloud_provider   = "gcp"
region           = "us-central1"
instance_type    = "e2-medium"
ssh_public_key   = "ssh-rsa AAAAB3NzaC1yc2E... user@host"
project_id       = "my-gcp-project-12345"
gcp_image_family = "ubuntu-2204-lts"
volume_size      = 20
tags = {
  Project     = "observability-stack"
  Environment = "production"
  Owner       = "team-platform"
}
```

### Minimal Dry-Run Example (`example-dryrun.tfvars`)

For `terraform plan` without real cloud credentials (uses mock values):

```hcl
cloud_provider  = "aws"
region          = "us-east-1"
instance_type   = "t3.medium"
ssh_public_key  = "ssh-rsa AAAAB3NzaC1yc2E... user@host"
aws_ami         = "ami-mock12345"
aws_vpc_id      = "vpc-mock12345"
aws_subnet_id   = "subnet-mock12345"
```

## Backend Configuration

The module uses a **local backend** by default for development/testing:

```hcl
# terraform/backend.tf
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

### Production: AWS S3 Backend with DynamoDB Locking

```bash
terraform init \
  -backend-config="bucket=my-terraform-state-bucket" \
  -backend-config="key=observability-stack/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=terraform-state-lock" \
  -backend-config="encrypt=true" \
  -reconfigure
```

Backend configuration (uncomment in `backend.tf` for permanent use):

```hcl
backend "s3" {
  bucket         = "my-terraform-state-bucket"
  key            = "observability-stack/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "terraform-state-lock"
  encrypt        = true
}
```

### Production: GCP GCS Backend with Locking

```bash
terraform init \
  -backend-config="bucket=my-terraform-state-bucket" \
  -backend-config="prefix=observability-stack/terraform.tfstate" \
  -reconfigure
```

Backend configuration (uncomment in `backend.tf` for permanent use):

```hcl
backend "gcs" {
  bucket  = "my-terraform-state-bucket"
  prefix  = "observability-stack/terraform.tfstate"
}
```

## Outputs

| Output | Description | Type |
|--------|-------------|------|
| `public_ip` | Public IP address of the observability stack VM | `string` |
| `private_ip` | Private IP address of the observability stack VM | `string` |
| `instance_id` | Cloud provider instance ID of the VM | `string` |

Example usage after apply:

```bash
$ terraform output public_ip
"54.123.45.67"

$ terraform output private_ip
"10.0.1.42"

$ terraform output instance_id
"i-0123456789abcdef0"
```

## Verification

Run these commands to validate the Terraform configuration:

```bash
# Format check
terraform fmt -check

# Validate configuration
terraform validate

# Plan with example variables (dry-run)
terraform plan -var-file=example-dryrun.tfvars

# Full validation pipeline
terraform fmt -check && terraform validate && terraform plan -var-file=example-dryrun.tfvars
```

### Provider Versions

Defined in `versions.tf`:

- `terraform` ≥ 1.5
- `aws` ~> 5.0
- `google` ~> 5.0

### Cloud-Init User Data

The `user_data.sh` script is executed on VM startup and:

1. Installs Docker and Docker Compose
2. Creates the `docker` group and adds the default user
3. Pulls the `docker-compose.yml` from the repository
4. Starts the observability stack with `docker compose up -d`

---

*Part of the [terraform-observability-stack](../README.md) project. Spec: `openspec/changes/terraform-observability-stack/specs/infrastructure/terraform-provisioning/`*