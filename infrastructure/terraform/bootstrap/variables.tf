# bootstrap/variables.tf
#
# Input variables for sponsor bootstrap
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00008: Multi-sponsor deployment model

# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "sponsor" {
  description = "Sponsor name (lowercase alphanumeric with hyphens)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.sponsor)) && length(var.sponsor) <= 20
    error_message = "Sponsor must be lowercase, start with letter, alphanumeric/hyphens only, max 20 chars."
  }
}

variable "sponsor_id" {
  description = "Unique sponsor ID for VPC CIDR allocation (1-254)"
  type        = number

  validation {
    condition     = var.sponsor_id >= 1 && var.sponsor_id <= 254
    error_message = "Sponsor ID must be between 1 and 254."
  }
}

variable "gcp_org_id" {
  description = "GCP Organization ID"
  type        = string
}

variable "billing_account_prod" {
  description = "Billing account ID for production environment"
  type        = string

  validation {
    condition     = can(regex("^[A-Z0-9]{6}-[A-Z0-9]{6}-[A-Z0-9]{6}$", var.billing_account_prod))
    error_message = "Billing account ID must be in format XXXXXX-XXXXXX-XXXXXX."
  }
}

variable "billing_account_dev" {
  description = "Billing account ID for dev/qa/uat environments"
  type        = string

  validation {
    condition     = can(regex("^[A-Z0-9]{6}-[A-Z0-9]{6}-[A-Z0-9]{6}$", var.billing_account_dev))
    error_message = "Billing account ID must be in format XXXXXX-XXXXXX-XXXXXX."
  }
}

# -----------------------------------------------------------------------------
# Optional Variables
# -----------------------------------------------------------------------------

variable "project_prefix" {
  description = "Prefix for project IDs"
  type        = string
  default     = "cure-hht"
}

variable "default_region" {
  description = "Default GCP region"
  type        = string
  default     = "europe-west9"
}

variable "folder_id" {
  description = "GCP Folder ID to place projects in (optional)"
  type        = string
  default     = ""
}

variable "github_org" {
  description = "GitHub organization for Workload Identity Federation"
  type        = string
  default     = "Cure-HHT"
}

variable "github_repo" {
  description = "GitHub repository for Workload Identity Federation"
  type        = string
  default     = "hht_diary"
}

variable "anspar_admin_group" {
  description = "Google group email for Anspar administrators (optional)"
  type        = string
  default     = ""
}

variable "enable_workload_identity" {
  description = "Enable Workload Identity Federation for GitHub Actions"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Budget Configuration
# -----------------------------------------------------------------------------

variable "budget_amounts" {
  description = "Monthly budget amounts per environment (USD)"
  type        = map(number)
  default = {
    dev  = 500
    qa   = 500
    uat  = 1000
    prod = 5000
  }
}

variable "enable_cost_controls" {
  description = "Enable automated cost controls (Pub/Sub + Cloud Function to stop services when budget exceeded). Only affects non-prod environments - prod will alert but not auto-stop."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Audit Log Configuration
# -----------------------------------------------------------------------------

variable "audit_retention_years" {
  description = "Audit log retention in years (FDA requires 25)"
  type        = number
  default     = 25
}

variable "include_data_access_logs" {
  description = "Include data access logs in audit exports"
  type        = bool
  default     = true
}

variable "create_bigquery_datasets" {
  description = "Create BigQuery datasets for audit analytics"
  type        = bool
  default     = true
}
