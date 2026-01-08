# modules/cloud-run/variables.tf

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "sponsor" {
  description = "Sponsor name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, qa, uat, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "qa", "uat", "prod"], var.environment)
    error_message = "Environment must be one of: dev, qa, uat, prod."
  }
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "vpc_connector_id" {
  description = "VPC Access Connector ID"
  type        = string
}

variable "diary_server_image" {
  description = "Docker image for diary-server"
  type        = string
}

variable "portal_server_image" {
  description = "Docker image for portal-server"
  type        = string
}

variable "db_host" {
  description = "Database host (private IP)"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "clinical_diary"
}

variable "db_user" {
  description = "Database username"
  type        = string
  default     = "app_user"
}

variable "db_password_secret_id" {
  description = "Secret Manager secret ID for database password"
  type        = string
}

variable "min_instances" {
  description = "Minimum Cloud Run instances"
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "Maximum Cloud Run instances"
  type        = number
  default     = 10
}

variable "container_cpu" {
  description = "Container CPU (e.g., '1' or '2')"
  type        = string
  default     = "1"
}

variable "container_memory" {
  description = "Container memory (e.g., '512Mi' or '1Gi')"
  type        = string
  default     = "512Mi"
}

variable "allow_public_access" {
  description = "Allow unauthenticated access (app handles auth)"
  type        = bool
  default     = true
}
