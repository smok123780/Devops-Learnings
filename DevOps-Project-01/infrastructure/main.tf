# Main Terraform configuration for GCP infrastructure

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "project_services" {
  source     = "./modules/project_services"
  project_id = var.project_id
}

module "networking" {
  source      = "./modules/networking"
  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  depends_on  = [module.project_services]
}

module "iam" {
  source     = "./modules/iam"
  project_id = var.project_id
  depends_on = [module.project_services]
}

module "cloud_sql" {
  source = "./modules/cloud_sql"

  project_id          = var.project_id
  region              = var.region
  environment         = var.environment
  network_id          = module.networking.primary_vpc_self_link
  db_name             = var.db_name
  db_root_password    = var.db_root_password
  deletion_protection = var.cloud_sql_deletion_protection

  depends_on = [module.project_services, module.networking]
}
