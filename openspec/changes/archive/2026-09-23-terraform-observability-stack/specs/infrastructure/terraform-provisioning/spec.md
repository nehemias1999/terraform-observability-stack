# Spec Delta

## Purpose

Provisions cloud infrastructure (VM, networking, security groups) using Terraform for AWS EC2 or GCP Compute Engine to host the observability stack.

## ADDED Requirements

### Requirement: Cloud provider selection
The system SHALL support provisioning on either AWS or GCP through a configuration variable.

#### Scenario: AWS provider selected
- **WHEN** cloud_provider variable is set to "aws"
- **THEN** Terraform uses AWS provider and creates EC2 instance with security groups

#### Scenario: GCP provider selected
- **WHEN** cloud_provider variable is set to "gcp"
- **THEN** Terraform uses GCP provider and creates Compute Engine instance with firewall rules

### Requirement: VM provisioning
The system SHALL provision a single VM instance with specified instance type and OS image.

#### Scenario: VM created with correct configuration
- **WHEN** terraform apply is executed
- **THEN** a VM is created with the specified instance_type, image, and SSH key

### Requirement: Network security configuration
The system SHALL configure network security to allow SSH (port 22), HTTP (port 80), HTTPS (port 443), and application ports (8080, 9090, 3000, 5432) from authorized sources.

#### Scenario: Security groups allow required ports
- **WHEN** infrastructure is provisioned
- **THEN** security groups/firewall rules exist for ports 22, 80, 443, 8080, 9090, 3000, 5432

### Requirement: Remote state backend
The system SHALL configure Terraform remote state storage in cloud object storage (S3/GCS) with locking (DynamoDB/Cloud Storage).

#### Scenario: Remote state configured
- **WHEN** Terraform initializes
- **THEN** state is stored in remote backend with locking enabled

### Requirement: Outputs for downstream use
The system SHALL output VM public IP, private IP, and instance ID for use by provisioning scripts.

#### Scenario: Outputs available after apply
- **WHEN** terraform apply completes
- **THEN** outputs include public_ip, private_ip, and instance_id