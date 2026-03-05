# bootstrap/outputs.tf
#
# Outputs from bootstrap for use in sponsor-envs deployments

# -----------------------------------------------------------------------------
# Sponsor Information
# -----------------------------------------------------------------------------

output "sponsor" {
  description = "Sponsor name"
  value       = var.SPONSOR
}

output "sponsor_id" {
  description = "Sponsor ID for VPC CIDR allocation"
  value       = var.SPONSOR_ID
}

output "project_prefix" {
  description = "Project prefix used"
  value       = var.project_prefix
}

# -----------------------------------------------------------------------------
# Project IDs and Numbers
# -----------------------------------------------------------------------------

output "project_ids" {
  description = "Map of environment to project ID"
  value = {
    for env in local.environments :
    env => module.projects[env].project_id
  }
}

output "project_numbers" {
  description = "Map of environment to project number"
  value = {
    for env in local.environments :
    env => module.projects[env].project_number
  }
}

output "dev_project_id" {
  description = "Dev project ID"
  value       = module.projects["dev"].project_id
}

output "qa_project_id" {
  description = "QA project ID"
  value       = module.projects["qa"].project_id
}

output "uat_project_id" {
  description = "UAT project ID"
  value       = module.projects["uat"].project_id
}

output "prod_project_id" {
  description = "Prod project ID"
  value       = module.projects["prod"].project_id
}

# -----------------------------------------------------------------------------
# CI/CD Configuration
# -----------------------------------------------------------------------------

output "cicd_service_account_email" {
  description = "CI/CD service account email"
  value       = module.cicd.service_account_email
}

output "cicd_service_account_id" {
  description = "CI/CD service account ID"
  value       = module.cicd.service_account_id
}

output "workload_identity_provider" {
  description = "Workload Identity Provider for GitHub Actions"
  value       = module.cicd.github_actions_provider
}

output "github_actions_config" {
  description = "Configuration for GitHub Actions workflow"
  value       = module.cicd.github_actions_config
}

# -----------------------------------------------------------------------------
# Per-Environment Terraform Service Accounts
# -----------------------------------------------------------------------------

output "tf_env_service_account_emails" {
  description = "Map of environment to per-environment Terraform SA email"
  value = {
    for env in local.environments :
    env => google_service_account.tf_env[env].email
  }
}

output "tf_env_service_account_ids" {
  description = "Map of environment to per-environment Terraform SA unique ID"
  value = {
    for env in local.environments :
    env => google_service_account.tf_env[env].id
  }
}

# -----------------------------------------------------------------------------
# Compute Service Accounts
# -----------------------------------------------------------------------------

output "compute_service_account_emails" {
  description = "Map of environment to compute service account email"
  value = {
    for env in local.environments :
    env => module.svc_accts[env].compute_service_account_email
  }
}

# -----------------------------------------------------------------------------
# Audit Log Configuration — MIGRATED to sponsor-envs
# Audit log outputs now come from each per-environment sponsor-envs state
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Budget Information — MIGRATED to sponsor-envs
# Budget outputs now come from each per-environment sponsor-envs state
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Database Configuration — MIGRATED to sponsor-envs
# Database outputs now come from each per-environment sponsor-envs state
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VPC Network — MIGRATED to sponsor-envs
# Network outputs now come from each per-environment sponsor-envs state
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Next Steps
# -----------------------------------------------------------------------------

output "next_steps" {
  description = "Next steps after bootstrap"
  value       = <<-EOT

    ============================================================
    Bootstrap Complete for: ${var.SPONSOR}
    ============================================================

    Projects Created:
      - Dev:  ${module.projects["dev"].project_id}
      - QA:   ${module.projects["qa"].project_id}
      - UAT:  ${module.projects["uat"].project_id}
      - Prod: ${module.projects["prod"].project_id}

    CI/CD Service Account: ${module.cicd.service_account_email}

    Cloud SQL Databases: Managed per-environment in sponsor-envs/
    Billing Budgets:     Managed per-environment in sponsor-envs/
    Audit Logs:          Managed per-environment in sponsor-envs/
    VPC Networks:        Managed per-environment in sponsor-envs/

    Next Steps:
    1. Create sponsor-envs tfvars for each environment:
       cd ../sponsor-envs
       cp sponsor-configs/example-dev.tfvars sponsor-configs/${var.SPONSOR}-dev.tfvars
       # Edit and repeat for qa, uat, prod

    2. Deploy each environment:
       ../scripts/deploy-environment.sh ${var.SPONSOR} dev --apply
       ../scripts/deploy-environment.sh ${var.SPONSOR} qa --apply
       ../scripts/deploy-environment.sh ${var.SPONSOR} uat --apply
       ../scripts/deploy-environment.sh ${var.SPONSOR} prod --apply

    3. Configure GitHub Actions secrets:
       GCP_WORKLOAD_IDENTITY_PROVIDER: module.cicd.github_actions_provider
       GCP_SERVICE_ACCOUNT: module.cicd.service_account_email

    4. Initialize databases (run schema deployment jobs):
       # For each environment, execute the schema job:
       gcloud run jobs execute ${var.SPONSOR}-dev-db-schema --project=${var.SPONSOR}-dev --region=${var.default_region} --wait
       gcloud run jobs execute ${var.SPONSOR}-qa-db-schema --project=${var.SPONSOR}-qa --region=${var.default_region} --wait
       gcloud run jobs execute ${var.SPONSOR}-uat-db-schema --project=${var.SPONSOR}-uat --region=${var.default_region} --wait
       gcloud run jobs execute ${var.SPONSOR}-prod-db-schema --project=${var.SPONSOR}-prod --region=${var.default_region} --wait

    5. Verify audit log compliance (after deploy-environment.sh):
       ../scripts/verify-audit-compliance.sh ${var.SPONSOR}

  EOT
}
