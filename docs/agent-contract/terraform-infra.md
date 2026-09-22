# Agent Contract: Terraform Infrastructure (Tasks 1.1-1.6)

## Spec Reference
- Primary: `openspec/changes/terraform-observability-stack/specs/infrastructure/terraform-provisioning/spec.md`
- Related: `openspec/changes/terraform-observability-stack/design.md` (Decisions 1, 5, 9, 10)
- Tasks: `openspec/changes/terraform-observability-stack/tasks.md` (Tasks 1.1-1.6)

## Permitted Files
**MUST ONLY MODIFY THESE FILES:**
- `terraform/main.tf`
- `terraform/variables.tf`
- `terraform/outputs.tf`
- `terraform/user_data.sh`
- `terraform/backend.tf` (or backend config in main.tf)
- `terraform/versions.tf`
- `terraform/.gitignore` (for Terraform state files)

**NEVER MODIFY:**
- Any spec files under `openspec/`
- Any files outside `terraform/` directory
- Tests for other requirements

## Interface Contract

### Terraform Configuration (main.tf)
- Provider configuration for AWS and GCP (conditional on `var.cloud_provider`)
- VM resource: `aws_instance` or `google_compute_instance`
- Networking: Security Group (AWS) / Firewall Rules (GCP) allowing ports 22, 80, 443, 8080, 9090, 3000, 5432
- Outputs: `public_ip`, `private_ip`, `instance_id`
- Use `count` or `for_each` with `var.cloud_provider` for conditional resources

### Variables (variables.tf)
Required variables:
- `cloud_provider` (string): "aws" or "gcp"
- `region` (string): Cloud region
- `instance_type` (string): VM size (e.g., "t3.medium", "e2-medium")
- `ssh_public_key` (string): SSH public key for access
- `project_id` (string, GCP only): GCP project ID
- `aws_ami` (string, AWS only): AMI ID for Ubuntu 22.04 LTS
- `gcp_image_family` (string, GCP only): Image family (e.g., "ubuntu-2204-lts")

Optional variables with defaults:
- `tags` (map(string)): Resource tags
- `volume_size` (number): Root volume size in GB (default: 20)

### Outputs (outputs.tf)
- `public_ip` (string): VM public IP address
- `private_ip` (string): VM private IP address
- `instance_id` (string): Cloud provider instance ID

### User Data Script (user_data.sh)
- Cloud-init compatible bash script
- Installs Docker Engine, Docker Compose plugin
- Creates `/opt/observability-stack` directory
- Pulls docker-compose.yml from repository (or embedded)
- Runs `docker compose up -d`
- Logs to `/var/log/user-data.log`

### Backend Configuration (backend.tf)
- S3 backend for AWS: bucket, key, region, dynamodb_table for locking
- GCS backend for GCP: bucket, prefix, credentials
- Use `terraform { backend "s3" {} }` or `backend "gcs" {}`

### Versions (versions.tf)
- Required providers: `aws` ~> 5.0, `google` ~> 5.0
- Required Terraform version: >= 1.5

## Verification Commands (IaC Profile)
```bash
# Format check
terraform fmt -check

# Validate configuration
terraform validate

# Lint (if tflint available)
tflint

# Security scan (if checkov available)
checkov -d .

# Plan (dry-run only - NO REAL APPLY)
terraform plan -var-file=example.tfvars
```

## Definition of Done
- [ ] All 6 tasks (1.1-1.6) completed
- [ ] `terraform fmt -check` passes
- [ ] `terraform validate` passes
- [ ] `terraform plan` runs without errors (with mock credentials)
- [ ] All files documented per `code-doc-standard` skill
- [ ] No secrets or credentials in any file

## Project Profile
**Type:** IaC (Terraform)
**Verification:** Terraform fmt, validate, plan (dry-run only)
**Skills:** terraform-module-library, secrets-management, cost-optimization, code-doc-standard

## Report Format
The implementer MUST return a summary with:
1. Task completion status (which tasks done)
2. Command outputs showing verification passed
3. Any blockers or context needed
4. List of files created/modified