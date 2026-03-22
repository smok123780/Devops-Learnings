output "bucket_name" {
  description = "GCS bucket name for SQL import"
  value       = google_storage_bucket.sql_import.name
}

output "sql_init_object_uri" {
  description = "gs:// URI for the SQL init object"
  value       = "gs://${google_storage_bucket.sql_import.name}/${google_storage_bucket_object.javaapp_init.name}"
}
