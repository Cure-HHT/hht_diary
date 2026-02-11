# modules/svc-accts/main.tf
#
# Grants a sponsor project's service account the ability to impersonate
# the admin project's Gmail service account for email sending.
#
# This enables cross-project service account impersonation for:
# - Email OTP codes for 2FA
# - Activation codes for new users
# - System notifications
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00002: Multi-Factor Authentication for Staff (Gmail API for email OTP)
#   REQ-d00009: Role-Based Permission Enforcement Implementation (IAM roles for SA impersonation)
#   REQ-d00035: Security and Compliance (Gmail API with domain-wide delegation)

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Cross-Project IAM: Allow sponsor SA to impersonate Gmail SA
# -----------------------------------------------------------------------------
#
# Grants roles/iam.serviceAccountTokenCreator on the admin project's
# Gmail service account, enabling the sponsor's SA to generate access
# tokens for domain-wide delegation email sending.

resource "google_service_account_iam_member" "gmail_impersonation" {
  service_account_id = "projects/${var.admin_project_id}/serviceAccounts/${var.gmail_service_account_email}"
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.impersonating_service_account_email}"
}
