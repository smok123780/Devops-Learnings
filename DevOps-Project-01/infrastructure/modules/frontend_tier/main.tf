data "google_compute_subnetwork" "public" {
  name    = var.public_subnet_name
  region  = var.region
  project = var.project_id
}

resource "google_compute_instance_template" "frontend" {
  name         = "${var.environment}-frontend-template"
  machine_type = var.instance_type
  region       = var.region
  project      = var.project_id
  tags         = ["frontend"]

  disk {
    source_image = "debian-cloud/debian-12"
    auto_delete  = true
    boot         = true
  }

  metadata = {
    # ILB and Tomcat listen on 8080; nginx upstream must include the port
    BACKEND_UPSTREAM = "${var.backend_ilb_ip}:8080"
  }

  metadata_startup_script = file("${path.root}/${var.startup_script_path}")

  network_interface {
    network    = var.network_name
    subnetwork = data.google_compute_subnetwork.public.self_link
  }

  lifecycle { create_before_destroy = true }
}

resource "google_compute_health_check" "frontend_http" {
  name                = "${var.environment}-frontend-http-hc"
  project             = var.project_id
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/health"
  }
}

resource "google_compute_instance_group_manager" "frontend_mig" {
  name               = "${var.environment}-frontend-mig"
  base_instance_name = "${var.environment}-frontend"
  zone               = var.zone
  project            = var.project_id
  target_size        = var.mig_min_size

  version {
    instance_template = google_compute_instance_template.frontend.id
  }

  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.frontend_http.id
    initial_delay_sec = 300
  }
}

resource "google_compute_autoscaler" "frontend" {
  name    = "${var.environment}-frontend-as"
  zone    = var.zone
  project = var.project_id
  target  = google_compute_instance_group_manager.frontend_mig.id

  autoscaling_policy {
    min_replicas = var.mig_min_size
    max_replicas = var.mig_max_size
    cpu_utilization {
      target = var.target_cpu_utilization
    }
  }
}

resource "google_compute_backend_service" "frontend" {
  name                  = "${var.environment}-frontend-backend"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_health_check.frontend_http.id]

  backend {
    group = google_compute_instance_group_manager.frontend_mig.instance_group
  }
}

resource "google_compute_url_map" "frontend" {
  name            = "${var.environment}-frontend-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.frontend.id
}

resource "google_compute_target_http_proxy" "frontend" {
  name    = "${var.environment}-frontend-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.frontend.id
}

resource "google_compute_global_address" "frontend" {
  name    = "${var.environment}-frontend-lb-ip"
  project = var.project_id
}

resource "google_compute_global_forwarding_rule" "frontend_http" {
  name                  = "${var.environment}-frontend-http-fr"
  project               = var.project_id
  target                = google_compute_target_http_proxy.frontend.id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.frontend.id
}
