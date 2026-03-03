# bootstrap/main.tf
#
# Bootstrap infrastructure for creating sponsor GCP projects
# Creates 4 projects per sponsor: dev, qa, uat, prod
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00008: Multi-sponsor deployment model
#   REQ-p00042: Infrastructure audit trail for FDA compliance
#   REQ-d00030: CI/CD Integration
#   REQ-d00057: CI/CD Environment Parity
#   REQ-d00033: FDA Validation Documentation
#   REQ-d00035: Security and Compliance
#   REQ-d00001: Sponsor-Specific Configuration Loading
#   REQ-d00055: Role-Based Environment Separation
#   REQ-d00059: Development Tool Specifications
#   REQ-d00062: Environment Validation & Change Control
#   REQ-d00090: Development Environment Installation Qualification
#   REQ-d00003: Identity Platform Configuration Per Sponsor
#   REQ-d00009: Role-Based Permission Enforcement Implementation
#   REQ-d00010: Data Encryption Implementation

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------

locals {
  environments = ["dev", "qa", "uat", "prod"]

  # Billing account selection: prod uses prod account, others use dev account
  billing_accounts = {
    dev  = var.BILLING_ACCOUNT_DEV
    qa   = var.BILLING_ACCOUNT_DEV
    uat  = var.BILLING_ACCOUNT_DEV
    prod = var.BILLING_ACCOUNT_PROD
  }

  # Project IDs - just sponsor-env (e.g., callisto-dev, cure-hht-prod)
  project_ids = {
    for env in local.environments :
    env => "${var.sponsor}-${env}"
  }

  # Project display names
  project_names = {
    for env in local.environments :
    env => "${title(var.sponsor)} ${upper(env)}"
  }

  # Audit log lock: only prod gets locked
  audit_lock = {
    dev  = false
    qa   = false
    uat  = false
    prod = false # TODO Set true when ready to lock audit logs.
  }

  # Audit retention: only prod gets FDA-required retention, non-prod = 0 (no retention)
  audit_retention = {
    dev  = 0
    qa   = 0
    uat  = 0
    prod = var.audit_retention_years
  }
}

# -----------------------------------------------------------------------------
# GCP Projects - One per Environment
# -----------------------------------------------------------------------------

module "projects" {
  source   = "../modules/gcp-project"
  for_each = toset(local.environments)

  project_id           = local.project_ids[each.key]
  project_display_name = local.project_names[each.key]
  org_id               = var.GCP_ORG_ID
  folder_id            = var.folder_id
  billing_account_id   = local.billing_accounts[each.key]
  sponsor              = var.sponsor
  environment          = each.key

  labels = {
    sponsor_id = tostring(var.sponsor_id)
  }
}

# -----------------------------------------------------------------------------
# GCP Networks - One per Environment
# -----------------------------------------------------------------------------

module "network" {
  source   = "../modules/vpc-network"
  for_each = toset(local.environments)

  project_id               = local.project_ids[each.key]
  environment              = each.key
  app_subnet_cidr          = var.app_subnet_cidr[each.key]
  connector_cidr           = var.connector_cidr[each.key]
  db_subnet_cidr           = var.db_subnet_cidr[each.key]
  sponsor                  = var.sponsor
  enable_proxy_only_subnet = var.enable_proxy_only_subnet
  proxy_only_subnet_cidr   = var.proxy_only_subnet_cidr[each.key]
}

# -----------------------------------------------------------------------------
# Billing Budgets - One per Environment
# -----------------------------------------------------------------------------

module "budgets" {
  source   = "../modules/billing-budget"
  for_each = toset(local.environments)

  billing_account_id   = local.billing_accounts[each.key]
  project_id           = module.projects[each.key].project_id
  project_number       = module.projects[each.key].project_number
  sponsor              = var.sponsor
  environment          = each.key
  budget_amount        = var.budget_amounts[each.key]
  enable_cost_controls = var.enable_cost_controls

  depends_on = [module.projects]
}

# -----------------------------------------------------------------------------
# Audit Logs - FDA 21 CFR Part 11 Compliant
# -----------------------------------------------------------------------------

module "audit_logs" {
  source   = "../modules/audit-logs"
  for_each = toset(local.environments)

  project_id               = module.projects[each.key].project_id
  project_prefix           = var.project_prefix
  sponsor                  = var.sponsor
  environment              = each.key
  region                   = var.default_region
  retention_years          = local.audit_retention[each.key]
  lock_retention_policy    = local.audit_lock[each.key]
  include_data_access_logs = var.include_data_access_logs

  depends_on = [module.projects]
}

# -----------------------------------------------------------------------------
# CI/CD Service Account with Workload Identity Federation
# -----------------------------------------------------------------------------

module "cicd" {
  source = "../modules/cicd-service-account"

  sponsor                  = var.sponsor
  host_project_id          = module.projects["dev"].project_id
  host_project_number      = module.projects["dev"].project_number
  target_project_ids       = [for env in local.environments : module.projects[env].project_id]
  dev_qa_project_ids       = [module.projects["dev"].project_id, module.projects["qa"].project_id]
  uat_prod_project_ids     = [module.projects["uat"].project_id, module.projects["prod"].project_id]
  enable_workload_identity = var.enable_workload_identity
  github_org               = var.github_org
  github_repo              = var.github_repo
  anspar_admin_group       = var.anspar_admin_group

  depends_on = [module.projects]
}

# Import existing WorkloadIdentityPool (created in a prior apply, not in state)
# import {
#   to = module.cicd.google_iam_workload_identity_pool.github[0]
#   id = "projects/callisto4-dev/locations/global/workloadIdentityPools/callisto4-github-pool"
# }

# -----------------------------------------------------------------------------
# Per-Environment Terraform Service Accounts
# Each environment gets its own SA for running deploy-environment.sh and
# terraform apply on the sponsor-envs root module.
# -----------------------------------------------------------------------------

resource "google_service_account" "tf_env" {
  for_each = toset(local.environments)

  account_id   = "terraform-sa"
  display_name = "Terraform SA - ${var.sponsor} ${upper(each.key)}"
  description  = "Service account for Terraform deployments to ${var.sponsor} ${each.key}"
  project      = module.projects[each.key].project_id

  depends_on = [module.projects]
}

# IAM roles the per-environment SA needs on its target project to manage all
# resources declared in sponsor-envs/main.tf (active + commented-out future).
locals {
  tf_env_roles = [
    "roles/secretmanager.admin",             # Manage Doppler token secret
    "roles/cloudfunctions.admin",            # Deploy billing-alert Cloud Functions
    "roles/run.admin",                       # Cloud Run (function backing service + future)
    "roles/pubsub.admin",                    # Pub/Sub subscriptions for billing alerts
    "roles/storage.admin",                   # GCS buckets (function source + future storage)
    "roles/cloudsql.admin",                  # Future Cloud SQL management
    "roles/iam.serviceAccountAdmin",         # Create/manage function service accounts
    "roles/iam.serviceAccountUser",          # Impersonate SAs (Cloud Build, functions)
    "roles/serviceusage.serviceUsageAdmin",  # Enable/disable GCP APIs
    "roles/identitytoolkit.admin",           # Identity Platform API access
    "roles/firebaseauth.admin",              # Firebase Auth management
    "roles/firebase.admin",                  # Identity Platform config (google_identity_platform_config)
    "roles/logging.admin",                   # Log-based metrics for function errors
    "roles/monitoring.admin",                # Future monitoring alerts
    "roles/artifactregistry.admin",          # Artifact Registry for function builds
    "roles/compute.networkAdmin",            # VPC/subnet management
    "roles/compute.loadBalancerAdmin",       # Regional LB, NEGs, backend services
    "roles/cloudbuild.builds.editor",        # Cloud Build for function deployment
    "roles/resourcemanager.projectIamAdmin", # Manage IAM bindings within the project
    "roles/certificatemanager.owner",        # Certificate Manager for Regional LB SSL certs
  ]
}

resource "google_project_iam_member" "tf_env_roles" {
  for_each = {
    for pair in setproduct(local.environments, local.tf_env_roles) :
    "${pair[0]}-${pair[1]}" => {
      env  = pair[0]
      role = pair[1]
    }
  }

  project = module.projects[each.value.env].project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.tf_env[each.value.env].email}"
}

# Allow specified users to impersonate each per-environment Terraform SA
# (required for `gcloud --impersonate-service-account` and provider impersonation).
resource "google_service_account_iam_member" "tf_env_token_creator" {
  for_each = {
    for pair in setproduct(local.environments, var.tf_env_token_creators) :
    "${pair[0]}-${pair[1]}" => {
      env   = pair[0]
      email = pair[1]
    }
  }

  service_account_id = google_service_account.tf_env[each.value.env].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${each.value.email}"
}

# Grant each per-environment SA access to the Terraform state bucket so it can
# run terraform init/plan/apply with the GCS backend.
resource "google_storage_bucket_iam_member" "tf_env_state_access" {
  for_each = toset(local.environments)

  bucket = var.terraform_state_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.tf_env[each.key].email}"
}

# Grant token creators direct access to the Terraform state bucket.
# The GCS backend and terraform_remote_state data sources authenticate via ADC
# (the caller's identity), not the impersonated SA, so the caller needs direct
# bucket access.
resource "google_storage_bucket_iam_member" "tf_env_token_creator_state_access" {
  for_each = toset(var.tf_env_token_creators)

  bucket = var.terraform_state_bucket
  role   = "roles/storage.objectAdmin"
  member = "user:${each.key}"
}

# -----------------------------------------------------------------------------
# Cloud SQL Database — MIGRATED to sponsor-envs/main.tf
# State migrated via scripts/migrate-db-to-sponsor-envs.sh
# -----------------------------------------------------------------------------

resource "google_project_service" "gmail_api" {
  for_each = toset(local.environments)
  project  = local.project_ids[each.key]
  service  = "gmail.googleapis.com"

  disable_on_destroy         = false
  disable_dependent_services = false

  depends_on = [module.projects]
}

resource "google_project_service" "idtk_api" {
  for_each = toset(local.environments)
  project  = local.project_ids[each.key]
  service  = "identitytoolkit.googleapis.com"

  disable_on_destroy         = false
  disable_dependent_services = false

  depends_on = [module.projects]
}
