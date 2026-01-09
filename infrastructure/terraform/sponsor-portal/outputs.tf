# sponsor-portal/outputs.tf
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

output "diary_server_url" {
  description = "Diary server URL"
  value       = module.cloud_run.diary_server_url
}

output "portal_server_url" {
  description = "Portal server URL"
  value       = module.cloud_run.portal_server_url
}

# -----------------------------------------------------------------------------
# Database
# -----------------------------------------------------------------------------

output "database_connection_name" {
  description = "Cloud SQL connection name (for proxy)"
  value       = module.cloud_sql.instance_connection_name
}

output "database_private_ip" {
  description = "Cloud SQL private IP"
  value       = module.cloud_sql.private_ip_address
}

output "database_name" {
  description = "Database name"
  value       = module.cloud_sql.database_name
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

output "vpc_network_name" {
  description = "VPC network name"
  value       = module.vpc.network_name
}

output "vpc_connector_name" {
  description = "VPC connector name"
  value       = module.vpc.connector_name
}

output "vpc_cidr" {
  description = "VPC CIDR range"
  value       = "10.${var.sponsor_id}.${local.env_offsets[var.environment]}.0/18"
}

# -----------------------------------------------------------------------------
# Storage
# -----------------------------------------------------------------------------

output "backup_bucket" {
  description = "Backup bucket name"
  value       = module.storage.backup_bucket_name
}

output "audit_log_bucket" {
  description = "Audit log bucket name"
  value       = module.audit_logs.bucket_name
}

# -----------------------------------------------------------------------------
# Artifact Registry
# -----------------------------------------------------------------------------

output "artifact_registry_url" {
  description = "Artifact Registry URL"
  value       = module.artifact_registry.repository_url
}

output "diary_server_image" {
  description = "Diary server image base path"
  value       = module.artifact_registry.diary_server_image_base
}

output "portal_server_image" {
  description = "Portal server image base path"
  value       = module.artifact_registry.portal_server_image_base
}

# -----------------------------------------------------------------------------
# Compliance
# -----------------------------------------------------------------------------

output "audit_compliance_status" {
  description = "FDA compliance status"
  value       = module.audit_logs.compliance_status
}

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

output "workforce_identity_pool_id" {
  description = "Workforce Identity Pool ID (if enabled)"
  value       = module.workforce_identity.pool_id
}

output "workforce_identity_login_url" {
  description = "Workforce Identity login URL (if enabled)"
  value       = module.workforce_identity.login_url
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
      Portal:      ${module.cloud_run.portal_server_url}
      API:         ${module.cloud_run.diary_server_url}

    Database:
      Instance:    ${module.cloud_sql.instance_name}
      Private IP:  ${module.cloud_sql.private_ip_address}

    VPC CIDR:    10.${var.sponsor_id}.${local.env_offsets[var.environment]}.0/18

    Audit Logs:
      Bucket:      ${module.audit_logs.bucket_name}
      Retention:   ${var.audit_retention_years} years
      Locked:      ${local.lock_audit_retention}

    Container Images:
      Diary:       ${module.artifact_registry.diary_server_image_base}
      Portal:      ${module.artifact_registry.portal_server_image_base}

    Identity Platform:
      Enabled:     ${var.enable_identity_platform}
      MFA:         ${var.enable_identity_platform ? module.identity_platform[0].mfa_state : "N/A"}

    ${var.workforce_identity_enabled ? "Workforce Identity: ${module.workforce_identity.login_url}" : "Workforce Identity: Disabled"}

  EOT
}
