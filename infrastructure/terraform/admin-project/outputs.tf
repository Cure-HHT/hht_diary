# admin-project/outputs.tf
#
# Outputs from admin project infrastructure
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00002: Multi-Factor Authentication for Staff (Gmail API for email OTP)

# -----------------------------------------------------------------------------
# Gmail Service Account Outputs
# -----------------------------------------------------------------------------

output "gmail_service_account_email" {
  description = "Email address of the org-wide Gmail service account"
  value       = google_service_account.gmail.email
}

output "gmail_service_account_id" {
  description = "Unique ID of the Gmail service account"
  value       = google_service_account.gmail.unique_id
}

output "gmail_service_account_name" {
  description = "Fully qualified name of the Gmail service account"
  value       = google_service_account.gmail.name
}

output "gmail_client_id" {
  description = "OAuth 2.0 Client ID for domain-wide delegation setup in Google Workspace Admin Console"
  value       = google_service_account.gmail.unique_id
}

# -----------------------------------------------------------------------------
# Project Information
# -----------------------------------------------------------------------------

output "project_id" {
  description = "Admin project ID"
  value       = var.project_id
}

output "project_number" {
  description = "Admin project number"
  value       = var.ADMIN_PROJECT_NUMBER
}

output "region" {
  description = "Primary region"
  value       = var.region
}

# -----------------------------------------------------------------------------
# Setup Instructions
# -----------------------------------------------------------------------------

output "gmail_setup_instructions" {
  description = "Manual setup steps required after terraform apply"
  value       = <<-EOT

    ============================================================
    Gmail Service Account Setup Instructions
    ============================================================

    Service Account: ${google_service_account.gmail.email}
    Client ID:       ${google_service_account.gmail.unique_id}

    REQUIRED MANUAL STEPS:

    1. Google Workspace Admin Console - Sign BAA (one-time):
       Account → Legal and compliance → Sign Business Associate Agreement

    2. Enable Domain-Wide Delegation:
       Security → API Controls → Domain-wide Delegation → Add new
       - Client ID: ${google_service_account.gmail.unique_id}
       - OAuth Scopes: https://www.googleapis.com/auth/gmail.send

    3. Create Sender Mailbox (if not exists):
       Create user: ${var.gmail_sender_email}

    4. Add to Doppler (all environments):
       EMAIL_SVC_ACCT = ${google_service_account.gmail.email}
       EMAIL_SENDER = ${var.gmail_sender_email}
       EMAIL_ENABLED = true

    5. Grant local dev users permission to impersonate (per developer):
       gcloud iam service-accounts add-iam-policy-binding \
         ${google_service_account.gmail.email} \
         --member="user:DEVELOPER@anspar.org" \
         --role="roles/iam.serviceAccountTokenCreator" \
         --project=${var.project_id}

    ============================================================

  EOT
}
