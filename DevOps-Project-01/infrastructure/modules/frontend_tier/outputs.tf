output "frontend_ip" {
  description = "External IP of the global HTTP(S) load balancer"
  value       = google_compute_global_address.frontend.address
}
