variable "project_id" {
  description = "GCP project where resources will be created"
  type        = string
}

variable "region" {
  description = "GCP region for regional resources"
  type        = string
  default     = "europe-central2"
}

variable "zone" {
  description = "GCP zone for zonal resources"
  type        = string
  default     = "europe-central2-a"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "db_name" {
  description = "Name of the Cloud SQL database"
  type        = string
  default     = "javaapp"
}

variable "db_root_password" {
  description = "Password for the Cloud SQL root user"
  type        = string
  sensitive   = true
}

variable "cloud_sql_deletion_protection" {
  description = "Prevent accidental deletion of Cloud SQL instance"
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "GCE machine type for compute instances"
  type        = string
  default     = "e2-micro"
}

variable "backend_ilb_ip" {
  description = "Reserved internal IP for the backend load balancer"
  type        = string
  default     = "192.168.2.10"
}

variable "sql_import_bucket" {
  description = "GCS bucket name for SQL import (default: {project_id}-sql-import)"
  type        = string
  default     = ""
}

variable "artifact_repository_id" {
  description = "Artifact Registry repository ID for Maven artifacts"
  type        = string
  default     = "maven-releases"
}

variable "app_maven_group_id" {
  description = "Maven groupId for the WAR deployed to backend Tomcat (metadata for startup script)"
  type        = string
  default     = "com.devopsrealtime"
}

variable "app_maven_artifact_id" {
  description = "Maven artifactId for the WAR deployed to backend Tomcat"
  type        = string
  default     = "dptweb"
}

variable "app_maven_version" {
  description = "Maven version of the WAR to pull from Artifact Registry"
  type        = string
  default     = "1.0"
}

variable "ops_email" {
  description = "Email address for monitoring notifications"
  type        = string
}

variable "sql_init_file_path" {
  description = "Path to javaapp_init.sql relative to infrastructure/ (use ../ for project root)"
  type        = string
  default     = "../scripts/sql/javaapp_init.sql"
}

variable "backend_startup_script_path" {
  description = "Path to setup_tomcat.sh relative to infrastructure/"
  type        = string
  default     = "../scripts/setup_tomcat.sh"
}

variable "frontend_startup_script_path" {
  description = "Path to vm_startup_script.sh relative to infrastructure/"
  type        = string
  default     = "../scripts/vm_startup_script.sh"
}

variable "backend_mig_min_size" {
  description = "Minimum number of backend instances"
  type        = number
  default     = 2
}

variable "backend_mig_max_size" {
  description = "Maximum number of backend instances"
  type        = number
  default     = 2
}

variable "frontend_mig_min_size" {
  description = "Minimum number of frontend instances"
  type        = number
  default     = 2
}

variable "frontend_mig_max_size" {
  description = "Maximum number of frontend instances"
  type        = number
  default     = 6
}

variable "frontend_target_cpu_utilization" {
  description = "Target CPU utilization for frontend autoscaling (0.0-1.0)"
  type        = number
  default     = 0.6
}
