# bootstrap/main.tf
#
# Bootstrap infrastructure for creating sponsor GCP projects
# Creates 4 projects per sponsor: dev, qa, uat, prod
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00008: Multi-sponsor deployment model
#   REQ-p00042: Infrastructure audit trail for FDA compliance

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
    prod = true
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
  target_project_ids       = [for env in local.environments : module.projects[env].project_id]
  dev_qa_project_ids       = [module.projects["dev"].project_id, module.projects["qa"].project_id]
  uat_prod_project_ids     = [module.projects["uat"].project_id, module.projects["prod"].project_id]
  enable_workload_identity = var.enable_workload_identity
  github_org               = var.github_org
  github_repo              = var.github_repo
  anspar_admin_group       = var.anspar_admin_group

  depends_on = [module.projects]
}
