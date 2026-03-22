output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.prod_mysql.name
}

output "connection_name" {
  description = "Cloud SQL instance connection name"
  value       = google_sql_database_instance.prod_mysql.connection_name
}

output "private_ip" {
  description = "Cloud SQL private IP"
  value       = google_sql_database_instance.prod_mysql.private_ip_address
}

output "service_account_email" {
  description = "Cloud SQL instance service account email (for GCS import)"
  value       = google_sql_database_instance.prod_mysql.service_account_email_address
}
