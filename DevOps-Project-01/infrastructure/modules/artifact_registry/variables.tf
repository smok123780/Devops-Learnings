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