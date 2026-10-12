# ci-cd/terraform-pipeline Specification

## Purpose
Defines GitHub Actions CI/CD pipeline for Terraform validation, planning, and applying infrastructure changes with proper approval gates.

## Requirements

### Requirement: Format and validate on every push
The system SHALL run terraform fmt -check and terraform validate on every push and pull request.

#### Scenario: PR fails on format/validate errors
- **WHEN** PR contains unformatted or invalid Terraform
- **THEN** workflow fails with clear error messages

### Requirement: Plan on pull requests
The system SHALL run terraform plan on pull requests and post the plan as a comment for review.

#### Scenario: Plan comment posted on PR
- **WHEN** PR is opened or updated
- **THEN** workflow posts terraform plan output as PR comment

### Requirement: Apply on merge to main
The system SHALL run terraform apply automatically when changes are merged to main branch (with approval gate).

#### Scenario: Apply runs after merge
- **WHEN** PR is merged to main
- **THEN** terraform apply executes with approved plan

### Requirement: Manual approval for production
The system SHALL require manual approval before applying changes to production infrastructure.

#### Scenario: Workflow pauses for approval
- **WHEN** apply job starts
- **THEN** workflow waits for manual approval before executing terraform apply

### Requirement: Secure credential handling
The system SHALL use GitHub Environments and OIDC for cloud provider authentication (no static keys in repository).

#### Scenario: Authentication via OIDC
- **WHEN** workflow runs in configured environment
- **THEN** cloud provider credentials obtained via OIDC token exchange

### Requirement: Drift detection (optional)
The system MAY run periodic drift detection to alert on infrastructure drift.

#### Scenario: Drift detection scheduled
- **WHEN** scheduled workflow runs
- **THEN** terraform plan runs and alerts on drift
