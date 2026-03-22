output "ilb_ip" {
  description = "Internal load balancer IP"
  value       = google_compute_address.backend_lb.address
}
