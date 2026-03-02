# bootstrap/outputs.tf
#
# Outputs from bootstrap for use in sponsor-envs deployments

# -----------------------------------------------------------------------------
# Sponsor Information
# -----------------------------------------------------------------------------

output "sponsor" {
  description = "Sponsor name"
  value       = var.sponsor
}

output "sponsor_id" {
  description = "Sponsor ID for VPC CIDR allocation"
  value       = var.sponsor_id
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
# VPC Network Information
# -----------------------------------------------------------------------------

output "network_ids" {
  description = "Map of environment to VPC network ID"
  value = {
    for env in local.environments :
    env => module.network[env].network_id
  }
}

output "network_names" {
  description = "Map of environment to VPC network name"
  value = {
    for env in local.environments :
    env => module.network[env].network_name
  }
}

output "network_self_links" {
  description = "Map of environment to VPC network self link"
  value = {
    for env in local.environments :
    env => module.network[env].network_self_link
  }
}

output "proxy_only_subnet_ids" {
  description = "Map of environment to proxy-only subnet ID (null if not enabled)"
  value = {
    for env in local.environments :
    env => module.network[env].proxy_only_subnet_id
  }
}

output "proxy_only_subnet_cidrs" {
  description = "Map of environment to proxy-only subnet CIDR (null if not enabled)"
  value = {
    for env in local.environments :
    env => module.network[env].proxy_only_subnet_cidr
  }
}

# -----------------------------------------------------------------------------
# Private VPC Connections (for Cloud SQL in sponsor-envs)
# -----------------------------------------------------------------------------

output "private_vpc_connections" {
  description = "Map of environment to private VPC connection ID (for Cloud SQL depends_on)"
  value = {
    for env in local.environments :
    env => module.network[env].private_vpc_connection
  }
}

# -----------------------------------------------------------------------------
# VPC CIDR Information
# -----------------------------------------------------------------------------

output "vpc_cidr_base" {
  description = "Base VPC CIDR for this sponsor"
  value       = "10.${var.sponsor_id}.0.0/16"
}

output "vpc_cidrs" {
  description = "VPC CIDRs per environment"
  value = {
    dev  = "10.${var.sponsor_id}.0.0/18"
    qa   = "10.${var.sponsor_id}.64.0/18"
    uat  = "10.${var.sponsor_id}.128.0/18"
    prod = "10.${var.sponsor_id}.192.0/18"
  }
}

# -----------------------------------------------------------------------------
# Next Steps
# -----------------------------------------------------------------------------

output "next_steps" {
  description = "Next steps after bootstrap"
  value       = <<-EOT

    ============================================================
    Bootstrap Complete for: ${var.sponsor}
    ============================================================

    Projects Created:
      - Dev:  ${module.projects["dev"].project_id}
      - QA:   ${module.projects["qa"].project_id}
      - UAT:  ${module.projects["uat"].project_id}
      - Prod: ${module.projects["prod"].project_id}

    CI/CD Service Account: ${module.cicd.service_account_email}

    VPC CIDR Range: 10.${var.sponsor_id}.0.0/16

    Cloud SQL Databases: Managed per-environment in sponsor-envs/
    Billing Budgets:     Managed per-environment in sponsor-envs/
    Audit Logs:          Managed per-environment in sponsor-envs/

    Next Steps:
    1. Create sponsor-envs tfvars for each environment:
       cd ../sponsor-envs
       cp sponsor-configs/example-dev.tfvars sponsor-configs/${var.sponsor}-dev.tfvars
       # Edit and repeat for qa, uat, prod

    2. Deploy each environment:
       ../scripts/deploy-environment.sh ${var.sponsor} dev --apply
       ../scripts/deploy-environment.sh ${var.sponsor} qa --apply
       ../scripts/deploy-environment.sh ${var.sponsor} uat --apply
       ../scripts/deploy-environment.sh ${var.sponsor} prod --apply

    3. Configure GitHub Actions secrets:
       GCP_WORKLOAD_IDENTITY_PROVIDER: module.cicd.github_actions_provider
       GCP_SERVICE_ACCOUNT: module.cicd.service_account_email

    4. Initialize databases (run schema deployment jobs):
       # For each environment, execute the schema job:
       gcloud run jobs execute ${var.sponsor}-dev-db-schema --project=${var.sponsor}-dev --region=${var.default_region} --wait
       gcloud run jobs execute ${var.sponsor}-qa-db-schema --project=${var.sponsor}-qa --region=${var.default_region} --wait
       gcloud run jobs execute ${var.sponsor}-uat-db-schema --project=${var.sponsor}-uat --region=${var.default_region} --wait
       gcloud run jobs execute ${var.sponsor}-prod-db-schema --project=${var.sponsor}-prod --region=${var.default_region} --wait

    5. Verify audit log compliance (after deploy-environment.sh):
       ../scripts/verify-audit-compliance.sh ${var.sponsor}

  EOT
}
