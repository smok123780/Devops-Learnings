resource "google_artifact_registry_repository" "maven" {
  location      = var.region
  repository_id = var.repository_id
  description   = "Maven repository for Java-Login-App"
  format        = "MAVEN"
  project       = var.project_id
}

resource "google_artifact_registry_repository_iam_member" "app_sa_reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.maven.repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.app_sa_email}"
}
