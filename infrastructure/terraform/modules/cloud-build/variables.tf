# modules/cloud-build/variables.tf

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

variable "github_org" {
  description = "GitHub organization"
  type        = string
  default     = "Cure-HHT"
}

variable "github_repo" {
  description = "GitHub repository"
  type        = string
  default     = "hht_diary"
}

variable "trigger_branch" {
  description = "Branch to trigger builds on"
  type        = string
  default     = "^main$"
}

variable "artifact_registry_url" {
  description = "Artifact Registry URL for images"
  type        = string
}

variable "cloud_build_service_account" {
  description = "Service account for Cloud Build"
  type        = string
  default     = ""
}
