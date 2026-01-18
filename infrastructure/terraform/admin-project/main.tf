# admin-project/main.tf
#
# Infrastructure for the cure-hht-admin project
# Manages shared/org-wide resources used by all sponsor projects
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00002: Multi-Factor Authentication for Staff (Gmail API for email OTP)
#   REQ-p00010: FDA 21 CFR Part 11 Compliance
#
# NOTE: The cure-hht-admin project itself was created manually as a bootstrap
# requirement for Terraform state storage. This configuration manages resources
# within that project.

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------

locals {
  common_labels = {
    managed_by = "terraform"
    purpose    = "org-wide-shared-services"
    compliance = "fda-21-cfr-part-11"
  }
}

# -----------------------------------------------------------------------------
# Enable Required APIs
# -----------------------------------------------------------------------------

resource "google_project_service" "gmail_api" {
  project = var.project_id
  service = "gmail.googleapis.com"

  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_project_service" "iam_api" {
  project = var.project_id
  service = "iam.googleapis.com"

  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_project_service" "iamcredentials_api" {
  project = var.project_id
  service = "iamcredentials.googleapis.com"

  disable_on_destroy         = false
  disable_dependent_services = false
}

# -----------------------------------------------------------------------------
# Gmail Service Account (Org-Wide Email Sending)
# -----------------------------------------------------------------------------
#
# This service account is used by all sponsor projects to send:
# - Email OTP codes for 2FA
# - Activation codes for new users
# - System notifications
#
# SETUP REQUIRED (Manual - One Time):
# 1. Google Workspace admin must sign BAA for HIPAA compliance
# 2. Enable domain-wide delegation in Admin Console:
#    Security -> API Controls -> Domain-wide Delegation
# 3. Add this service account's Client ID with scope:
#    https://www.googleapis.com/auth/gmail.send
# 4. Create the sender mailbox (e.g., support@anspar.org) in Google Workspace
# 5. Add GMAIL_SERVICE_ACCOUNT_EMAIL to Doppler (the SA email, not a key)

resource "google_service_account" "gmail" {
  account_id   = "org-gmail-sender"
  display_name = "Org-Wide Gmail Sender"
  description  = "Sends email OTP codes and activation emails via Gmail API with domain-wide delegation. Used by all sponsor projects."
  project      = var.project_id

  depends_on = [google_project_service.iam_api]
}

# -----------------------------------------------------------------------------
# IAM: Allow Sponsor Cloud Run Services to Impersonate Gmail SA
# -----------------------------------------------------------------------------
#
# Each sponsor's Cloud Run service account needs permission to impersonate
# this Gmail service account to send emails.

resource "google_service_account_iam_member" "cloud_run_impersonate" {
  for_each = toset(var.sponsor_cloud_run_service_accounts)

  service_account_id = google_service_account.gmail.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${each.value}"
}

# -----------------------------------------------------------------------------
# Note: Artifact Registry
# -----------------------------------------------------------------------------
#
# The Artifact Registry (ghcr-remote) in this project was created manually
# and is used as a pull-through cache for GitHub Container Registry.
# It is referenced in sponsor-portal configurations.
#
# If you need to manage it via Terraform in the future, add:
#
# resource "google_artifact_registry_repository" "ghcr_remote" {
#   location      = var.region
#   repository_id = "ghcr-remote"
#   description   = "Pull-through cache for GitHub Container Registry"
#   format        = "DOCKER"
#   mode          = "REMOTE_REPOSITORY"
#
#   remote_repository_config {
#     docker_repository {
#       public_repository = "DOCKER_HUB"  # or custom for GHCR
#     }
#   }
# }
