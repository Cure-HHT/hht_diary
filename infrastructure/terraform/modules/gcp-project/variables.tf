# modules/gcp-project/variables.tf

variable "project_id" {
  description = "The GCP project ID (must be globally unique)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be 6-30 characters, lowercase letters, digits, or hyphens, start with letter, end with letter or digit."
  }
}

variable "project_display_name" {
  description = "Human-readable project name"
  type        = string
}

variable "org_id" {
  description = "GCP Organization ID"
  type        = string
}

variable "folder_id" {
  description = "GCP Folder ID to place project in (optional)"
  type        = string
  default     = ""
}

variable "billing_account_id" {
  description = "GCP Billing Account ID"
  type        = string

  validation {
    condition     = can(regex("^[A-Z0-9]{6}-[A-Z0-9]{6}-[A-Z0-9]{6}$", var.billing_account_id))
    error_message = "Billing account ID must be in format XXXXXX-XXXXXX-XXXXXX."
  }
}

variable "sponsor" {
  description = "Sponsor name (for labels)"
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

variable "labels" {
  description = "Additional labels to apply to the project"
  type        = map(string)
  default     = {}
}
