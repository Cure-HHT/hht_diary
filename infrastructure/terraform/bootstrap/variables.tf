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

variable "SPONSOR" {
  description = "Sponsor name (lowercase alphanumeric with hyphens)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.SPONSOR)) && length(var.SPONSOR) <= 20
    error_message = "Sponsor must be lowercase, start with letter, alphanumeric/hyphens only, max 20 chars."
  }
}

variable "SPONSOR_ID" {
  description = "Unique sponsor ID for VPC CIDR allocation (1-254)"
  type        = number

  validation {
    condition     = var.SPONSOR_ID >= 1 && var.SPONSOR_ID <= 254
    error_message = "Sponsor ID must be between 1 and 254."
  }
}

variable "GCP_ORG_ID" {
  description = "GCP Organization ID"
  type        = string
}

variable "BILLING_ACCOUNT_PROD" {
  description = "Billing account ID for production environment"
  type        = string

  validation {
    condition     = can(regex("^[A-Z0-9]{6}-[A-Z0-9]{6}-[A-Z0-9]{6}$", var.BILLING_ACCOUNT_PROD))
    error_message = "Billing account ID must be in format XXXXXX-XXXXXX-XXXXXX."
  }
}

variable "BILLING_ACCOUNT_DEV" {
  description = "Billing account ID for dev/qa/uat environments"
  type        = string

  validation {
    condition     = can(regex("^[A-Z0-9]{6}-[A-Z0-9]{6}-[A-Z0-9]{6}$", var.BILLING_ACCOUNT_DEV))
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
# Budget & Audit Log Configuration — MIGRATED to sponsor-envs/variables.tf
# Variables: budget_amounts, enable_cost_controls, SLACK_INCIDENT_WEBHOOK_URL,
#            audit_retention_years, include_data_access_logs
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Network Configuration — MIGRATED to sponsor-envs/variables.tf
# Variables: app_subnet_cidr, db_subnet_cidr, connector_cidr,
#            enable_proxy_only_subnet, proxy_only_subnet_cidr
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Database Configuration — MIGRATED to sponsor-envs
# DB_PASSWORD, database_name, db_username moved to sponsor-envs/variables.tf
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Terraform State Configuration
# -----------------------------------------------------------------------------

variable "terraform_state_bucket" {
  description = "GCS bucket for Terraform state (used for per-environment SA access)"
  type        = string
  default     = "cure-hht-terraform-state"
}

variable "tf_env_token_creators" {
  description = "Email addresses granted roles/iam.serviceAccountTokenCreator on per-environment Terraform SAs"
  type        = list(string)
  default     = []
}
