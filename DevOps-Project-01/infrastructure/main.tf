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
  app_sa_email  = module.iam.app_sa_email

  depends_on = [module.project_services, module.iam]
}

module "backend_tier" {
  source = "./modules/backend_tier"

  project_id            = var.project_id
  region                = var.region
  zone                  = var.zone
  environment           = var.environment
  network_name          = module.networking.primary_vpc_name
  private_subnet_name   = module.networking.private_subnet_name
  app_sa_email          = module.iam.app_sa_email
  backend_ilb_ip        = var.backend_ilb_ip
  instance_type         = var.instance_type
  mig_min_size          = var.backend_mig_min_size
  mig_max_size          = var.backend_mig_max_size
  startup_script_path   = var.backend_startup_script_path
  ar_project_id         = var.project_id
  ar_location           = var.region
  ar_repository         = var.artifact_repository_id
  app_maven_group_id    = var.app_maven_group_id
  app_maven_artifact_id = var.app_maven_artifact_id
  app_maven_version     = var.app_maven_version

  depends_on = [module.networking, module.iam, module.artifact_registry]
}

module "frontend_tier" {
  source = "./modules/frontend_tier"

  project_id             = var.project_id
  region                 = var.region
  zone                   = var.zone
  environment            = var.environment
  network_name           = module.networking.primary_vpc_name
  public_subnet_name     = module.networking.public_subnet_name
  backend_ilb_ip         = module.backend_tier.ilb_ip
  instance_type          = var.instance_type
  mig_min_size           = var.frontend_mig_min_size
  mig_max_size           = var.frontend_mig_max_size
  target_cpu_utilization = var.frontend_target_cpu_utilization
  startup_script_path    = var.frontend_startup_script_path

  depends_on = [module.networking, module.backend_tier]
}

module "monitoring" {
  source = "./modules/monitoring"

  project_id  = var.project_id
  environment = var.environment
  ops_email   = var.ops_email
}
