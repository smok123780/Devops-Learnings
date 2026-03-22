output "repository_id" {
  description = "Artifact Registry repository ID"
  value       = google_artifact_registry_repository.maven.repository_id
}

output "repository_url" {
  description = "Artifact Registry repository URL"
  value       = "${var.region}-maven.pkg.dev/${var.project_id}/${google_artifact_registry_repository.maven.repository_id}"
}
