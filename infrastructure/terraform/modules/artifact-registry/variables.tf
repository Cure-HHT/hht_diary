# modules/artifact-registry/variables.tf

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
  default     = "europe-west9"
}

variable "cicd_service_account" {
  description = "CI/CD service account email (for push access)"
  type        = string
  default     = ""
}

variable "cloud_run_service_account" {
  description = "Cloud Run service account email (for pull access)"
  type        = string
  default     = ""
}
