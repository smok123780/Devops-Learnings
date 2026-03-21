output "primary_vpc_id" {
  description = "Primary VPC ID"
  value       = google_compute_network.primary_vpc.id
}

output "primary_vpc_name" {
  description = "Primary VPC name"
  value       = google_compute_network.primary_vpc.name
}

output "primary_vpc_self_link" {
  description = "Primary VPC self link (for Cloud SQL private_network)"
  value       = google_compute_network.primary_vpc.self_link
}

output "public_subnet_name" {
  description = "Public subnet name"
  value       = google_compute_subnetwork.public.name
}

output "private_subnet_name" {
  description = "Private subnet name"
  value       = google_compute_subnetwork.private.name
}

output "private_subnet_self_link" {
  description = "Private subnet self link"
  value       = google_compute_subnetwork.private.self_link
}

output "service_networking_connection" {
  description = "Service networking connection (for depends_on)"
  value       = google_service_networking_connection.private.id
}
