data "google_compute_subnetwork" "private" {
  name    = var.private_subnet_name
  region  = var.region
  project = var.project_id
}

resource "google_compute_instance_template" "backend" {
  name_prefix  = "${var.environment}-backend-"
  machine_type = var.instance_type
  region       = var.region
  project      = var.project_id
  tags         = ["backend"]

  disk {
    source_image = "debian-cloud/debian-12"
    auto_delete  = true
    boot         = true
  }

  metadata = {
    AR_PROJECT_ID         = var.ar_project_id
    AR_LOCATION           = var.ar_location
    AR_REPOSITORY         = var.ar_repository
    APP_MAVEN_GROUP_ID    = var.app_maven_group_id
    APP_MAVEN_ARTIFACT_ID = var.app_maven_artifact_id
    APP_MAVEN_VERSION     = var.app_maven_version
  }

  metadata_startup_script = file("${path.root}/${var.startup_script_path}")

  network_interface {
    network    = var.network_name
    subnetwork = data.google_compute_subnetwork.private.self_link
  }

  service_account {
    email  = var.app_sa_email
    scopes = ["cloud-platform"]
  }

  lifecycle { create_before_destroy = true }
}

resource "google_compute_instance_group_manager" "backend_mig" {
  name               = "${var.environment}-backend-mig"
  base_instance_name = "${var.environment}-backend"
  zone               = var.zone
  target_size        = var.mig_min_size
  project            = var.project_id

  version { instance_template = google_compute_instance_template.backend.id }
  named_port {
    name = "http"
    port = 8080
  }
}

resource "google_compute_region_health_check" "backend_tcp" {
  name    = "${var.environment}-backend-tcp-hc"
  region  = var.region
  project = var.project_id
  tcp_health_check { port = 8080 }
}

resource "google_compute_region_backend_service" "backend" {
  name                  = "${var.environment}-backend-ilb-service"
  region                = var.region
  project               = var.project_id
  load_balancing_scheme = "INTERNAL"
  protocol              = "TCP"
  health_checks         = [google_compute_region_health_check.backend_tcp.id]
  backend { group = google_compute_instance_group_manager.backend_mig.instance_group }
}

resource "google_compute_address" "backend_lb" {
  name         = "${var.environment}-backend-ilb-ip"
  region       = var.region
  project      = var.project_id
  subnetwork   = data.google_compute_subnetwork.private.id
  address_type = "INTERNAL"
  address      = var.backend_ilb_ip
}

resource "google_compute_forwarding_rule" "backend" {
  name                  = "${var.environment}-backend-ilb-fr"
  region                = var.region
  project               = var.project_id
  load_balancing_scheme = "INTERNAL"
  network               = var.network_name
  subnetwork            = data.google_compute_subnetwork.private.id
  ip_address            = google_compute_address.backend_lb.address
  ip_protocol           = "TCP"
  ports                 = ["8080"]
  backend_service       = google_compute_region_backend_service.backend.id
}
