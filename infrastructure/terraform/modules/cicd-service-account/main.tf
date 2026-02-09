# modules/cicd-service-account/main.tf
#
# Creates CI/CD service account with Workload Identity Federation for GitHub Actions
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00008: Multi-sponsor deployment model

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
# Local Variables
# -----------------------------------------------------------------------------

locals {
  sa_name        = "${var.sponsor}-cicd"
  sa_description = "CI/CD service account for ${var.sponsor} deployments"

  # IAM roles needed for CI/CD deployments
  cicd_roles = [
    "roles/run.admin",              # Deploy to Cloud Run
    "roles/artifactregistry.admin", # Push container images
    "roles/cloudsql.admin",         # Manage Cloud SQL instances
    "roles/iam.serviceAccountUser", # Impersonate service accounts
    "roles/storage.admin",          # Manage storage buckets
    "roles/secretmanager.admin",    # Access secrets
    "roles/monitoring.admin",       # Emit metrics and create alerts
    "roles/cloudbuild.builds.editor", # Trigger Cloud Build
  ]
}

# -----------------------------------------------------------------------------
# Enable Required APIs
# -----------------------------------------------------------------------------

resource "google_project_service" "required_apis" {
  for_each = toset([
    "iam.googleapis.com",                    # Service accounts and IAM
    "iamcredentials.googleapis.com",         # Workload Identity token creation
    "sts.googleapis.com",                    # Security Token Service (WIF token exchange)
    "cloudresourcemanager.googleapis.com",   # Project IAM bindings
  ])

  project            = var.host_project_id
  service            = each.value
  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# CI/CD Service Account
# -----------------------------------------------------------------------------

resource "google_service_account" "cicd" {
  account_id   = local.sa_name
  display_name = "CI/CD Service Account - ${var.sponsor}"
  description  = local.sa_description
  project      = var.host_project_id
}

# -----------------------------------------------------------------------------
# IAM Role Bindings - Per Project
# -----------------------------------------------------------------------------

# Grant CI/CD roles to each project
resource "google_project_iam_member" "cicd_roles" {
  for_each = {
    for pair in setproduct(var.target_project_ids, local.cicd_roles) :
    "${pair[0]}-${pair[1]}" => {
      project = pair[0]
      role    = pair[1]
    }
  }

  project = each.value.project
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# -----------------------------------------------------------------------------
# Workload Identity Federation - For GitHub Actions
# -----------------------------------------------------------------------------

resource "google_iam_workload_identity_pool" "github" {
  count = var.enable_workload_identity ? 1 : 0

  workload_identity_pool_id = "${var.sponsor}-github-pool"
  project                   = var.host_project_id
  display_name              = "GitHub Actions Pool - ${var.sponsor}"
  description               = "Workload Identity Pool for GitHub Actions CI/CD"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  count = var.enable_workload_identity ? 1 : 0

  workload_identity_pool_id          = google_iam_workload_identity_pool.github[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "${var.sponsor}-github-provider"
  project                            = var.host_project_id
  display_name                       = "GitHub Provider"
  description                        = "OIDC provider for GitHub Actions"

  # GitHub OIDC configuration
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # Attribute mapping from GitHub OIDC token
  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }

  # Only allow tokens from specified GitHub org/repo
  attribute_condition = "assertion.repository_owner == '${var.github_org}'"
}

# Allow GitHub Actions to impersonate the CI/CD service account
resource "google_service_account_iam_member" "workload_identity_user" {
  count = var.enable_workload_identity ? 1 : 0

  service_account_id = google_service_account.cicd.name
  role               = "roles/iam.workloadIdentityUser"

  # Grant to the specific repository
  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github[0].name}/attribute.repository/${var.github_org}/${var.github_repo}"
}

# -----------------------------------------------------------------------------
# Optional: Anspar Admin Group Access
# -----------------------------------------------------------------------------

# Grant owner access to dev/qa projects for Anspar admin group
resource "google_project_iam_member" "anspar_admin_owner" {
  for_each = var.anspar_admin_group != "" ? toset(var.dev_qa_project_ids) : []

  project = each.value
  role    = "roles/owner"
  member  = "group:${var.anspar_admin_group}"
}

# Grant viewer access to uat/prod projects for Anspar admin group
resource "google_project_iam_member" "anspar_admin_viewer" {
  for_each = var.anspar_admin_group != "" ? toset(var.uat_prod_project_ids) : []

  project = each.value
  role    = "roles/viewer"
  member  = "group:${var.anspar_admin_group}"
}
