output "app_sa_email" {
  description = "App service account email"
  value       = google_service_account.app_sa.email
}
