# sponsor-envs/outputs.tf
#
# Outputs from sponsor portal deployment

# -----------------------------------------------------------------------------
# General Information
# -----------------------------------------------------------------------------

output "sponsor" {
  description = "Sponsor name"
  value       = var.sponsor
}

output "environment" {
  description = "Environment"
  value       = var.environment
}

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}

# -----------------------------------------------------------------------------
# Cloud Run URLs
# -----------------------------------------------------------------------------

output "cloud_run_enabled" {
  description = "Whether Cloud Run services are enabled"
  value       = var.enable_cloud_run
}

output "diary_server_url" {
  description = "Diary server URL"
  value       = var.enable_cloud_run ? module.cloud_run[0].diary_server_url : null
}

output "portal_server_url" {
  description = "Portal server URL"
  value       = var.enable_cloud_run ? module.cloud_run[0].portal_server_url : null
}

output "cloud_run_service_account_email" {
  description = "Cloud Run service account email"
  value       = var.enable_cloud_run ? module.cloud_run[0].service_account_email : null
}

# -----------------------------------------------------------------------------
# Database
# -----------------------------------------------------------------------------

# output "database_connection_name" {
#   description = "Cloud SQL connection name (for proxy)"
#   value       = module.cloud_sql.instance_connection_name
# }

# output "database_private_ip" {
#   description = "Cloud SQL private IP"
#   value       = module.cloud_sql.private_ip_address
# }

# output "database_name" {
#   description = "Database name"
#   value       = module.cloud_sql.database_name
# }

# -----------------------------------------------------------------------------
# VPC Network
# Migrated from bootstrap via scripts/migrate-network-to-sponsor-envs.sh
# -----------------------------------------------------------------------------

output "vpc_network_name" {
  description = "VPC network name"
  value       = module.network.network_name
}

output "vpc_connector_id" {
  description = "VPC connector ID"
  value       = module.network.connector_id
}

# -----------------------------------------------------------------------------
# Audit Logs
# -----------------------------------------------------------------------------

output "audit_log_bucket" {
  description = "Audit log bucket name"
  value       = module.audit_logs.bucket_name
}

output "audit_compliance_status" {
  description = "FDA compliance status"
  value       = module.audit_logs.compliance_status
}

# -----------------------------------------------------------------------------
# Budget Information
# -----------------------------------------------------------------------------

output "budget_id" {
  description = "Budget ID"
  value       = module.budgets.budget_id
}

output "budget_alert_topic" {
  description = "Pub/Sub topic for budget alerts"
  value       = module.budgets.budget_alert_topic
}

# -----------------------------------------------------------------------------
# Storage
# -----------------------------------------------------------------------------

output "backup_bucket" {
  description = "Backup bucket name"
  value       = module.storage.backup_bucket_name
}

# -----------------------------------------------------------------------------
# Container Images (via Artifact Registry GHCR proxy)
# -----------------------------------------------------------------------------

# output "diary_server_image" {
#   description = "Diary server container image URL"
#   value       = var.diary_server_image
# }

# output "portal_server_image" {
#   description = "Portal server container image URL"
#   value       = var.portal_server_image
# }

# -----------------------------------------------------------------------------
# Service Accounts
# -----------------------------------------------------------------------------

output "compute_service_account_email" {
  description = "Compute service account email for Cloud Run services"
  value       = local.compute_service_account_email
}

# output "portal_server_service_account_email" {
#   description = "Portal server Cloud Run service account email (add to admin-project for Gmail SA impersonation)"
#   value       = module.cloud_run.portal_server_service_account_email
# }

# -----------------------------------------------------------------------------
# Identity Platform (if enabled)
# -----------------------------------------------------------------------------

output "identity_platform_enabled" {
  description = "Whether Identity Platform is enabled"
  value       = var.enable_identity_platform
}

output "identity_platform_mfa_state" {
  description = "MFA enforcement state"
  value       = var.enable_identity_platform ? module.identity_platform[0].mfa_state : "N/A"
}

output "identity_platform_auth_methods" {
  description = "Enabled authentication methods"
  value       = var.enable_identity_platform ? module.identity_platform[0].auth_methods : {}
}

# -----------------------------------------------------------------------------
# Workforce Identity (if enabled)
# -----------------------------------------------------------------------------

# output "workforce_identity_pool_id" {
#   description = "Workforce Identity Pool ID (if enabled)"
#   value       = module.workforce_identity.pool_id
# }

# output "workforce_identity_login_url" {
#   description = "Workforce Identity login URL (if enabled)"
#   value       = module.workforce_identity.login_url
# }

# -----------------------------------------------------------------------------
# Regional Load Balancer (if enabled)
# -----------------------------------------------------------------------------

output "enable_regional_lb" {
  description = "Whether Regional Load Balancer is enabled"
  value       = var.enable_regional_lb
}

output "lb_ip_address" {
  description = "External IP address of the Regional Load Balancer"
  value       = var.enable_regional_lb ? module.regional_load_balancer[0].lb_ip_address : null
}

output "lb_dns_record_name" {
  description = "CNAME record name to add at Gandi.net for SSL certificate validation"
  value       = var.enable_regional_lb ? module.regional_load_balancer[0].dns_record_name : null
}

output "lb_dns_record_data" {
  description = "CNAME record data to add at Gandi.net for SSL certificate validation"
  value       = var.enable_regional_lb ? module.regional_load_balancer[0].dns_record_data : null
}

output "lb_backend_service_ids" {
  description = "Map of Cloud Run service names to backend service IDs"
  value       = var.enable_regional_lb ? module.regional_load_balancer[0].backend_service_ids : null
}

output "lb_setup_instructions" {
  description = "Instructions for completing Regional Load Balancer setup"
  value       = var.enable_regional_lb ? module.regional_load_balancer[0].setup_instructions : null
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

output "summary" {
  description = "Deployment summary"
  value       = <<-EOT

    ============================================================
    Sponsor Portal Deployment Complete
    ============================================================

    Sponsor:     ${var.sponsor}
    Environment: ${var.environment}
    Project:     ${var.project_id}
    Region:      ${var.region}

    Cloud Run:
      Enabled:     ${var.enable_cloud_run}
      Portal URL:  ${var.enable_cloud_run ? module.cloud_run[0].portal_server_url : "N/A"}
      API URL:     ${var.enable_cloud_run ? module.cloud_run[0].diary_server_url : "N/A"}

    VPC Network: ${module.network.network_name}

    Container Images:
      Diary:       ${var.diary_server_image}
      Portal:      ${var.portal_server_image}

    Identity Platform:
      Enabled:     ${var.enable_identity_platform}
      MFA:         ${var.enable_identity_platform ? module.identity_platform[0].mfa_state : "N/A"}

  EOT
}
