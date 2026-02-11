# modules/svc-accts/variables.tf
#
# Input variables for cross-project service account IAM bindings
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-d00009: Role-Based Permission Enforcement Implementation

variable "admin_project_id" {
  description = "GCP project ID where the Gmail service account lives (e.g., cure-hht-admin)"
  type        = string
}

variable "gmail_service_account_email" {
  description = "Email of the Gmail service account to impersonate (e.g., org-gmail-sender@cure-hht-admin.iam.gserviceaccount.com)"
  type        = string
}

variable "impersonating_service_account_email" {
  description = "Email of the sponsor's service account that needs to impersonate the Gmail SA (e.g., 123456-compute@developer.gserviceaccount.com)"
  type        = string
}
