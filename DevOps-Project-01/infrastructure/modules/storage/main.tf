locals {
  bucket_name = var.sql_import_bucket_name != "" ? var.sql_import_bucket_name : "${var.project_id}-sql-import"
}

resource "google_storage_bucket" "sql_import" {
  name     = local.bucket_name
  location = var.region
  project  = var.project_id

  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "sql_sa_viewer" {
  bucket = google_storage_bucket.sql_import.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.sql_instance_sa_email}"
}

resource "google_storage_bucket_object" "javaapp_init" {
  name   = "javaapp_init.sql"
  bucket = google_storage_bucket.sql_import.name
  source = "${path.root}/${var.sql_init_file_path}"
}
