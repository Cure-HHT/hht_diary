# admin-project/main.tf
#
# Infrastructure for the cure-hht-admin project
# Manages shared/org-wide resources used by all sponsor projects
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00002: Multi-Factor Authentication for Staff (Gmail API for email OTP)
#   REQ-p00010: FDA 21 CFR Part 11 Compliance
#   REQ-p00042: Infrastructure audit trail for FDA compliance
#   REQ-d00030: CI/CD Integration (Gmail API for notifications)
#   REQ-d00035: Security and Compliance (Gmail API with domain-wide delegation
#   REQ-d00001: Sponsor-Specific Configuration Loading (Gmail SA used by all sponsors)
#   REQ-d00009: Role-Based Permission Enforcement Implementation (IAM roles for SA imperson
#   REQ-d00010: Data Encryption Implementation (Gmail API uses TLS for email sending)
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

locals {
  required_apis = toset([
    "gmail.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "networkservices.googleapis.com",
    "sqladmin.googleapis.com",
    "cloudbuild.googleapis.com",
    "compute.googleapis.com",
  ])
}

resource "google_project_service" "apis" {
  for_each = local.required_apis

  project = var.project_id
  service = each.value

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
# 5. Add EMAIL_SVC_ACCT to Doppler (the SA email, not a key)

resource "google_service_account" "gmail" {
  account_id   = "org-gmail-sender"
  display_name = "Org-Wide Gmail Sender"
  description  = "Sends email OTP codes and activation emails via Gmail API with domain-wide delegation. Used by all sponsor projects."
  project      = var.project_id

  depends_on = [google_project_service.apis["iam.googleapis.com"]]
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

#TODO We will want one(1) global loadbalancer, external IP and certifactes
# for ALL sponsors.
# -----------------------------------------------------------------------------
# Global External Load Balancer (GELB) for Sponsor Portals
# -----------------------------------------------------------------------------
# The GELB is set up in this admin project to provide a single global IP and
# SSL certificate for all sponsor portals, simplifying DNS and certificate management.
# The backend services for each portal will be added in their respective sponsor
# project configurations.
# resource "google_certificate_manager_certificate" "lb_default" {
#   provider = google-beta
#   name     = "myservice-ssl-cert"
# 
#   managed {
#     domains = ["example.com"]
#   }
# }
