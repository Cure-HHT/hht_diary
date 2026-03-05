# modules/svc-accts/main.tf
#
# Creates a dedicated compute service account and foundational IAM bindings.
# Additional role grants are distributed to their relevant modules:
#   - cloudsql.client           → modules/cloud-sql
#   - identityplatform.admin    → modules/identity-platform
#   - storage.objectUser        → modules/storage-buckets
#   - secretmanager.accessor    → sponsor-envs (inline, depends on doppler secret)
#   - iam.serviceAccountUser    → sponsor-envs (inline, depends on mailer SA)
#   - artifactregistry.reader   → bootstrap (project-level, alongside SA creation)
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00002: Multi-Factor Authentication for Staff (Gmail API for email OTP)
#   REQ-d00009: Role-Based Permission Enforcement Implementation (IAM roles for SA impersonation)
#   REQ-d00031: Identity Platform Integration (user seeding)
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
  count              = var.enable_gmail_impersonation ? 1 : 0
  service_account_id = "projects/${var.admin_project_id}/serviceAccounts/${var.gmail_service_account_email}"
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.compute.email}"
}

# -----------------------------------------------------------------------------
# Compute Service Account
# -----------------------------------------------------------------------------
#
# Creates a dedicated compute service account for Cloud Run services,
# replacing the GCP default Compute Engine SA.

resource "google_service_account" "compute" {
  account_id   = "${var.project_id}-compute-sa"
  display_name = "${var.project_id} Compute Service Account"
  description  = "Compute service account for Cloud Run services in ${var.project_id}"
  project      = var.project_id
}

# Grant Service Usage Consumer
# Required for Cloud Run services to consume GCP APIs
resource "google_project_iam_member" "compute_service_usage_consumer" {
  project = var.project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:${google_service_account.compute.email}"
}
