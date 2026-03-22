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

module "storage" {
  source = "./modules/storage"

  project_id             = var.project_id
  region                 = var.region
  environment            = var.environment
  sql_import_bucket_name = var.sql_import_bucket
  sql_instance_sa_email  = module.cloud_sql.service_account_email
  sql_init_file_path     = var.sql_init_file_path

  depends_on = [module.cloud_sql]
}

module "artifact_registry" {
  source = "./modules/artifact_registry"

  project_id    = var.project_id
  region        = var.region
  repository_id = var.artifact_repository_id

  depends_on = [module.project_services]
}
