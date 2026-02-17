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
    prod = false  # TODO Set true when ready to lock audit logs.
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

  project_id        = local.project_ids[each.key]
  environment       = each.key
  app_subnet_cidr   = var.app_subnet_cidr[each.key]
  connector_cidr    = var.connector_cidr[each.key]
  db_subnet_cidr    = var.db_subnet_cidr[each.key]
  sponsor           = var.sponsor
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
# Billing Alert Functions - Moved to sponsor-portal for per-environment deployment
# -----------------------------------------------------------------------------
# module "billing_alerts" {
#   source   = "../modules/billing-alert-funk"
#   for_each = var.enable_cost_controls ? toset(local.environments) : toset([])
#
#   project_id            = module.projects[each.key].project_id
#   project_number        = module.projects[each.key].project_number
#   region                = var.default_region
#   sponsor               = var.sponsor
#   environment           = each.key
#   budget_alert_topic_id = module.budgets[each.key].budget_alert_topic
#   function_source_dir   = "${path.module}/../modules/billing-alert-funk/src"
#   slack_webhook_url     = var.slack_incident_webhook_url
#
#   depends_on = [module.budgets]
# }

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
# Cloud SQL Database - One per Environment
# -----------------------------------------------------------------------------

module "database" {
  source   = "../modules/cloud-sql"
  for_each = toset(local.environments)

  project_id             = local.project_ids[each.key]
  sponsor                = var.sponsor
  environment            = each.key
  region                 = var.default_region
  vpc_network_id         = module.network[each.key].network_id
  private_vpc_connection = module.network[each.key].private_vpc_connection
  database_name          = "${var.sponsor}_${each.key}_${var.database_name}"
  db_username            = var.db_username
  DB_PASSWORD            = var.DB_PASSWORD

  depends_on = [module.network]
}

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
  service = "identitytoolkit.googleapis.com"

  disable_on_destroy         = false
  disable_dependent_services = false

  depends_on = [module.projects]
}
