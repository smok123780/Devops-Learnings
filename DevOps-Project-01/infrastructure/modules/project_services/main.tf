#modules/project_services/main.tf
locals {
  apis = toset([
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "iam.googleapis.com",
    "artifactregistry.googleapis.com",
  ])
}

resource "google_project_service" "enabled" {
  for_each = local.apis
  project  = var.project_id
  service  = each.value

  disable_on_destroy = false
}
