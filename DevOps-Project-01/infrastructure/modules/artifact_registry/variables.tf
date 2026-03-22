variable "project_id" {
  description = "Google project Id"
  type        = string
}

variable "region" {
  description = "Google region"
  type        = string
}

variable "repository_id" {
  description = "Artifact Registry repository ID for Maven artifacts"
  type        = string
  default     = "maven-releases"
}

variable "app_sa_email" {
  description = "Application VM service account email (Artifact Registry reader)"
  type        = string
}
