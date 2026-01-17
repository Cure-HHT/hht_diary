# admin-project/variables.tf
#
# Input variables for admin project infrastructure
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00002: Multi-Factor Authentication for Staff (Gmail API for email OTP)

# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "GCP Admin Project ID"
  type        = string
  default     = "cure-hht-admin"
}

variable "project_number" {
  description = "GCP Admin Project Number"
  type        = string
  default     = "149504828360"
}

variable "GCP_ORG_ID" {
  description = "GCP Organization ID"
  type        = string
}

# -----------------------------------------------------------------------------
# Optional: Region Configuration
# -----------------------------------------------------------------------------

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west9"
}

# -----------------------------------------------------------------------------
# Gmail Service Account Configuration
# -----------------------------------------------------------------------------

variable "gmail_sender_email" {
  description = "Google Workspace email address to send from (must exist and have domain-wide delegation enabled)"
  type        = string
  default     = "noreply@curehht.org"
}

variable "gmail_create_service_account_key" {
  description = "Whether to create a service account key (for Doppler storage). Set false if using Workload Identity."
  type        = bool
  default     = true
}

variable "gmail_key_rotation_time" {
  description = "Timestamp for key rotation (change to force new key generation)"
  type        = string
  default     = "2025-01-01T00:00:00Z"
}

# -----------------------------------------------------------------------------
# Sponsor Project Access
# -----------------------------------------------------------------------------

variable "sponsor_cloud_run_service_accounts" {
  description = "List of Cloud Run service account emails from sponsor projects that need to impersonate the Gmail SA"
  type        = list(string)
  default     = []
}
