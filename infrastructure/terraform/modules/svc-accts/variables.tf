# modules/svc-accts/variables.tf
#
# Input variables for compute service account and cross-project IAM bindings
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-d00009: Role-Based Permission Enforcement Implementation

variable "project_id" {
  description = "GCP project ID for the compute service account and IAM bindings"
  type        = string
}

variable "admin_project_id" {
  description = "GCP project ID where the Gmail service account lives (e.g., cure-hht-admin)"
  type        = string
}

variable "gmail_service_account_email" {
  description = "Email of the Gmail service account to impersonate (e.g., org-gmail-sender@cure-hht-admin.iam.gserviceaccount.com)"
  type        = string
}

variable "enable_gmail_impersonation" {
  description = "Whether to grant cross-project Gmail SA impersonation (requires admin-project IAM access)"
  type        = bool
  default     = false
}
