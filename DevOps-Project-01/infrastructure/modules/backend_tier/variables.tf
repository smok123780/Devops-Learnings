variable "project_id" {
  description = "Google project Id"
  type        = string
}

variable "region" {
  description = "Google region"
  type        = string
}

variable "zone" {
  description = "Google zone"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "network_name" {
  description = "VPC network name"
  type        = string
}

variable "private_subnet_name" {
  description = "Private subnet name"
  type        = string
}

variable "app_sa_email" {
  description = "App service account email"
  type        = string
}

variable "backend_ilb_ip" {
  description = "Backend internal load balancer IP"
  type        = string
}

variable "instance_type" {
  description = "Instance type"
  type        = string
  default     = "e2-micro"
}

variable "mig_min_size" {
  description = "Minimum number of instances in the managed instance group"
  type        = number
  default     = 2
}

variable "mig_max_size" {
  description = "Maximum number of instances in the managed instance group"
  type        = number
  default     = 2
}

variable "startup_script_path" {
  description = "Path to startup script"
  type        = string
}

variable "ar_project_id" {
  description = "GCP project ID for Artifact Registry (Maven repo host)"
  type        = string
}

variable "ar_location" {
  description = "Artifact Registry location (region)"
  type        = string
}

variable "ar_repository" {
  description = "Artifact Registry Maven repository ID"
  type        = string
}

variable "app_maven_group_id" {
  description = "Maven groupId for the WAR"
  type        = string
}

variable "app_maven_artifact_id" {
  description = "Maven artifactId for the WAR"
  type        = string
}

variable "app_maven_version" {
  description = "Maven version for the WAR"
  type        = string
}
