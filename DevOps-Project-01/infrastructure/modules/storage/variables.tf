variable "project_id" {
  description = "Google project Id"
  type        = string
}

variable "region" {
  description = "Google region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "sql_import_bucket_name" {
  description = "GCS bucket name for SQL import (empty = {project_id}-sql-import)"
  type        = string
  default     = ""
}

variable "sql_instance_sa_email" {
  description = "Cloud SQL instance service account email"
  type        = string
}

variable "sql_init_file_path" {
  description = "Path to javaapp_init.sql relative to root module"
  type        = string
}
