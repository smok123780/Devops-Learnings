resource "google_artifact_registry_repository" "maven" {
  location      = var.region
  repository_id = var.repository_id
  description   = "Maven repository for Java-Login-App"
  format        = "MAVEN"
  project       = var.project_id
}
