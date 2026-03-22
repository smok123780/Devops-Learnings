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

variable "network_id" {
  description = "VPC network self link or ID for private IP"
  type        = string
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

variable "deletion_protection" {
  description = "Prevent accidental deletion of Cloud SQL instance"
  type        = bool
  default     = false
}
