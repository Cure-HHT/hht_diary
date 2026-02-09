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

variable "ADMIN_PROJECT_NUMBER" {
  description = "GCP Admin Project Number (provided via TF_VAR_ADMIN_PROJECT_NUMBER from Doppler)"
  type        = string
}

variable "GCP_ORG_ID" {
  description = "GCP Organization ID (provided via TF_VAR_GCP_ORG_ID from Doppler)"
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
  default     = "support@anspar.org"
}

# -----------------------------------------------------------------------------
# Sponsor Project Access
# -----------------------------------------------------------------------------

variable "sponsor_cloud_run_service_accounts" {
  description = "List of Cloud Run service account emails from sponsor projects that need to impersonate the Gmail SA"
  type        = list(string)
  default     = []
}

variable "sponsor_cloud_run_service_agents" {
  description = "List of Cloud Run Service Agent emails from sponsor projects that need to pull images from Artifact Registry (format: service-<PROJECT_NUMBER>@serverless-robot-prod.iam.gserviceaccount.com)"
  type        = list(string)
  default     = []
}

variable "sponsor_compute_default_service_accounts" {
  description = "List of Compute Engine default service account emails from sponsor projects that need to read from the schema bucket (format: <PROJECT_NUMBER>-compute@developer.gserviceaccount.com)"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Schema Bucket Configuration
# -----------------------------------------------------------------------------

variable "schema_bucket_name" {
  description = "Name of the GCS bucket containing database schema files (bucket must already exist)"
  type        = string
  default     = "cure-hht-admin_cloudbuild"
}

# -----------------------------------------------------------------------------
# Terraform Service Account Access
# -----------------------------------------------------------------------------

variable "sponsor_terraform_service_accounts" {
  description = "List of Terraform service account emails from sponsor projects that need serviceUsageConsumer access to reference admin project resources"
  type        = list(string)
  default     = []
}
