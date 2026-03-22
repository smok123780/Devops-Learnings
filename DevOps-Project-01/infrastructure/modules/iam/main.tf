resource "google_service_account" "app_sa" {
  account_id   = "app-sa"
  display_name = "Application Service Account"
  project      = var.project_id
}

resource "google_service_account" "sql_sa" {
  account_id   = "sql-sa"
  display_name = "SQL Service Account"
  project      = var.project_id
}

resource "google_project_iam_member" "app_sa_storage" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

resource "google_project_iam_member" "sql_sa_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.sql_sa.email}"
}
