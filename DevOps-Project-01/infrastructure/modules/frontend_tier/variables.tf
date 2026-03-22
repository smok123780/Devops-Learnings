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

variable "public_subnet_name" {
  description = "Public subnet name"
  type        = string
}

variable "backend_ilb_ip" {
  description = "Backend internal load balancer IP (Nginx upstream)"
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
  default     = 6
}

variable "target_cpu_utilization" {
  description = "Target CPU utilization for the autoscaler (0.0-1.0)"
  type        = number
  default     = 0.6
}

variable "startup_script_path" {
  description = "Path to startup script relative to infrastructure/ (Terraform root)"
  type        = string
}
