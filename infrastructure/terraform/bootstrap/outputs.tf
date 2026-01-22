# bootstrap/outputs.tf
#
# Outputs from bootstrap for use in sponsor-portal deployments

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
# Audit Log Configuration
# -----------------------------------------------------------------------------

output "audit_log_buckets" {
  description = "Map of environment to audit log bucket name"
  value = {
    for env in local.environments :
    env => module.audit_logs[env].bucket_name
  }
}

output "audit_compliance_status" {
  description = "FDA compliance status for each environment"
  value = {
    for env in local.environments :
    env => module.audit_logs[env].compliance_status
  }
}

# -----------------------------------------------------------------------------
# Budget Information
# -----------------------------------------------------------------------------

output "budget_ids" {
  description = "Map of environment to budget ID"
  value = {
    for env in local.environments :
    env => module.budgets[env].budget_id
  }
}

output "cost_controls_enabled" {
  description = "Map of environment to cost control status (non-prod only)"
  value = {
    for env in local.environments :
    env => module.budgets[env].cost_controls_enabled
  }
}

output "budget_alert_topics" {
  description = "Pub/Sub topics for budget alerts (for custom automation)"
  value = {
    for env in local.environments :
    env => module.budgets[env].budget_alert_topic
  }
}

# -----------------------------------------------------------------------------
# Database Configuration
# -----------------------------------------------------------------------------

output "database_instance_names" {
  description = "Map of environment to Cloud SQL instance name"
  value = {
    for env in local.environments :
    env => module.database[env].instance_name
  }
}

output "database_connection_names" {
  description = "Map of environment to Cloud SQL connection name (for proxy)"
  value = {
    for env in local.environments :
    env => module.database[env].instance_connection_name
  }
}

output "database_private_ips" {
  description = "Map of environment to Cloud SQL private IP"
  value = {
    for env in local.environments :
    env => module.database[env].private_ip_address
  }
}

output "database_names" {
  description = "Map of environment to database name"
  value = {
    for env in local.environments :
    env => module.database[env].database_name
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

    Cloud SQL Databases (PostgreSQL 17):
      - Dev:  ${module.database["dev"].instance_name}
      - QA:   ${module.database["qa"].instance_name}
      - UAT:  ${module.database["uat"].instance_name}
      - Prod: ${module.database["prod"].instance_name}

    Audit Log Retention: ${var.audit_retention_years} years
    Prod Audit Locked: ${local.audit_lock["prod"]}

    Cost Controls: ${var.enable_cost_controls ? "Enabled (non-prod will auto-stop on budget exceed)" : "Disabled (alerts only)"}

    Next Steps:
    1. Create sponsor-portal tfvars for each environment:
       cd ../sponsor-portal
       cp sponsor-configs/example-dev.tfvars sponsor-configs/${var.sponsor}-dev.tfvars
       # Edit and repeat for qa, uat, prod

    2. Deploy each environment:
       ../scripts/deploy-environment.sh ${var.sponsor} dev --apply
       ../scripts/deploy-environment.sh ${var.sponsor} qa --apply
       ../scripts/deploy-environment.sh ${var.sponsor} uat --apply
       ../scripts/deploy-environment.sh ${var.sponsor} prod --apply

    3. Configure GitHub Actions secrets:
       GCP_WORKLOAD_IDENTITY_PROVIDER: ${module.cicd.github_actions_provider}
       GCP_SERVICE_ACCOUNT: ${module.cicd.service_account_email}

    4. Initialize databases (run schema deployment jobs):
       # For each environment, execute the schema job:
       gcloud run jobs execute ${var.sponsor}-dev-db-schema --project=${var.sponsor}-dev --region=${var.default_region} --wait
       gcloud run jobs execute ${var.sponsor}-qa-db-schema --project=${var.sponsor}-qa --region=${var.default_region} --wait
       gcloud run jobs execute ${var.sponsor}-uat-db-schema --project=${var.sponsor}-uat --region=${var.default_region} --wait
       gcloud run jobs execute ${var.sponsor}-prod-db-schema --project=${var.sponsor}-prod --region=${var.default_region} --wait

    5. Verify audit log compliance:
       ../scripts/verify-audit-compliance.sh ${var.sponsor}

  EOT
}
