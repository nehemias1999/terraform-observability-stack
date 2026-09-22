# ==============================================================================
# Description: Output values for the observability stack infrastructure.
#   Exposes VM public IP, private IP, and instance ID for both AWS and GCP
#   deployments. Uses conditional logic to return provider-specific values.
#   For both providers, uses resource attributes directly (no data sources).
# Author: Infrastructure Team
# Usage: Run 'terraform output' after apply to retrieve values. Reference in
#   other modules with module.<name>.public_ip, etc.
# Dependencies: main.tf resources (aws_instance, google_compute_instance)
# ==============================================================================

output "public_ip" {
  description = "Public IP address of the observability stack VM"
  value       = local.is_aws ? aws_instance.observability_vm[0].public_ip : google_compute_instance.observability_vm[0].network_interface[0].access_config[0].nat_ip
}

output "private_ip" {
  description = "Private IP address of the observability stack VM"
  value       = local.is_aws ? aws_instance.observability_vm[0].private_ip : google_compute_instance.observability_vm[0].network_interface[0].network_ip
}

output "instance_id" {
  description = "Cloud provider instance ID of the observability stack VM"
  value       = local.is_aws ? aws_instance.observability_vm[0].id : google_compute_instance.observability_vm[0].id
}