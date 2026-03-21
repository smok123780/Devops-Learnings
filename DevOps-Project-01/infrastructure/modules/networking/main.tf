# Primary VPC
resource "google_compute_network" "primary_vpc" {
  name                    = "${var.environment}-primary-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Secondary VPC
resource "google_compute_network" "secondary_vpc" {
  name                    = "${var.environment}-secondary-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Public subnet 
resource "google_compute_subnetwork" "public" {
  name          = "${var.environment}-public-subnet-1"
  ip_cidr_range = "192.168.1.0/24"
  network       = google_compute_network.primary_vpc.id
  region        = var.region
  project       = var.project_id
}

# Private subnet
resource "google_compute_subnetwork" "private" {
  name          = "${var.environment}-private-subnet-1"
  ip_cidr_range = "192.168.2.0/24"
  network       = google_compute_network.primary_vpc.id
  region        = var.region
  project       = var.project_id
}

# Cloud Router
resource "google_compute_router" "primary" {
  name    = "${var.environment}-primary-router"
  network = google_compute_network.primary_vpc.id
  region  = var.region
  project = var.project_id
}

# Firewall: HTTP/HTTPS from Internet to Frontend
resource "google_compute_firewall" "allow_http_https" {
  name    = "${var.environment}-allow-http-https"
  network = google_compute_network.primary_vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["frontend"]
}

# Firewall: 8080 from Frontend to Backend
resource "google_compute_firewall" "allow_backend_8080" {
  name    = "${var.environment}-allow-backend-8080"
  network = google_compute_network.primary_vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_tags = ["frontend"]
  target_tags = ["backend"]
}

# Private Service Access for Cloud SQL 
resource "google_compute_global_address" "psa_range" {
  name          = "google-managed-services-${google_compute_network.primary_vpc.name}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.primary_vpc.id
}

resource "google_service_networking_connection" "private" {
  network                 = google_compute_network.primary_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa_range.name]
}
