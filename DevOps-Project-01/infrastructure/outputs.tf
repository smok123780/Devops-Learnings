output "cloud_sql_connection_name" {
  description = "Cloud SQL instance connection name"
  value       = module.cloud_sql.connection_name
}

output "cloud_sql_private_ip" {
  description = "Cloud SQL private IP address"
  value       = module.cloud_sql.private_ip
}

output "backend_ilb_ip" {
  description = "Internal load balancer IP for backend tier"
  value       = module.backend_tier.ilb_ip
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository ID"
  value       = module.artifact_registry.repository_id
}

output "artifact_registry_url" {
  description = "Artifact Registry repository URL for Maven"
  value       = module.artifact_registry.repository_url
}

output "frontend_lb_ip" {
  description = "Frontend load balancer external IP"
  value       = module.frontend_tier.frontend_ip
}

output "frontend_url" {
  description = "URL of the frontend load balancer (HTTP)"
  value       = "http://${module.frontend_tier.frontend_ip}"
}

output "sql_import_bucket" {
  description = "GCS bucket holding javaapp_init.sql for manual import"
  value       = module.storage.bucket_name
}
