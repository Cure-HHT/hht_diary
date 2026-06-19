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

# output "diary_server_url" {
#   description = "Diary server URL"
#   value       = module.cloud_run.diary_server_url
# }

# output "portal_server_url" {
#   description = "Portal server URL"
#   value       = module.cloud_run.portal_server_url
# }

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
# VPC
# -----------------------------------------------------------------------------

# output "vpc_network_name" {
#   description = "VPC network name"
#   value       = module.vpc.network_name
# }

# output "vpc_connector_name" {
#   description = "VPC connector name"
#   value       = module.vpc.connector_name
# }

# output "vpc_cidr" {
#   description = "VPC CIDR range"
#   value       = "10.${var.sponsor_id}.${local.env_offsets[var.environment]}.0/18"
# }

# -----------------------------------------------------------------------------
# Storage
# -----------------------------------------------------------------------------

# output "backup_bucket" {
#   description = "Backup bucket name"
#   value       = module.storage.backup_bucket_name
# }

# output "audit_log_bucket" {
#   description = "Audit log bucket name"
#   value       = module.audit_logs.bucket_name
# }

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
# Compliance
# -----------------------------------------------------------------------------

# output "audit_compliance_status" {
#   description = "FDA compliance status"
#   value       = module.audit_logs.compliance_status
# }

# -----------------------------------------------------------------------------
# Service Accounts
# -----------------------------------------------------------------------------

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

output "lb_backend_service_id" {
  description = "Regional backend service ID (for attaching Cloud Run NEGs)"
  value       = var.enable_regional_lb ? module.regional_load_balancer[0].backend_service_id : null
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

    URLs:
      portal:      ${var.portal_server_url}
      API:         ${var.diary_server_url}

    VPC CIDR:    10.${var.sponsor_id}.${local.env_offsets[var.environment]}.0/18

    Container Images:
      Diary:       ${var.diary_server_image}
      Portal:      ${var.portal_server_image}

    Identity Platform:
      Enabled:     ${var.enable_identity_platform}
      MFA:         ${var.enable_identity_platform ? module.identity_platform[0].mfa_state : "N/A"}

  EOT
}
