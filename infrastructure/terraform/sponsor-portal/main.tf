# sponsor-portal/main.tf
#
# Deploys sponsor portal infrastructure for a single environment
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00008: Multi-sponsor deployment model
#   REQ-p00042: Infrastructure audit trail for FDA compliance

# -----------------------------------------------------------------------------
# Remote State – read bootstrap outputs (billing-budget topic, etc.)
# -----------------------------------------------------------------------------

data "terraform_remote_state" "bootstrap" {
  backend = "gcs"

  config = {
    bucket = "cure-hht-terraform-state"
    prefix = "bootstrap/${var.sponsor}"
  }
}

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------

locals {
  is_production = var.environment == "prod"

  # Environment offsets for VPC CIDR
  env_offsets = {
    dev  = 0
    qa   = 64
    uat  = 128
    prod = 192
  }

  env_offset = local.env_offsets[var.environment]

  # VPC CIDRs calculated from sponsor_id and environment
  app_subnet_cidr = "10.${var.sponsor_id}.${local.env_offset}.0/22"
  db_subnet_cidr  = "10.${var.sponsor_id}.${local.env_offset + 4}.0/22"
  connector_cidr  = "10.${var.sponsor_id}.${local.env_offset + 12}.0/28"

  # VPC connector sizing defaults
  connector_min = var.vpc_connector_min_instances > 0 ? var.vpc_connector_min_instances : (
    local.is_production ? 2 : 2
  )
  connector_max = var.vpc_connector_max_instances > 0 ? var.vpc_connector_max_instances : (
    local.is_production ? 10 : 3
  )

  # Audit log lock: only prod gets locked
  lock_audit_retention = local.is_production

  common_labels = {
    sponsor     = var.sponsor
    environment = var.environment
    managed_by  = "terraform"
    compliance  = "fda-21-cfr-part-11"
  }
}

# -----------------------------------------------------------------------------
# Secret Manager
# -----------------------------------------------------------------------------

resource "google_secret_manager_secret" "doppler_token" {
  secret_id = "DOPPLER_TOKEN"
  project   = var.project_id

  labels = local.common_labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "doppler_token" {
  secret      = google_secret_manager_secret.doppler_token.id
  secret_data = var.DOPPLER_TOKEN
}

# -----------------------------------------------------------------------------
# VPC Network
# -----------------------------------------------------------------------------
# TODO import the existing network, synch with infrastructure/terraform/bootstrap/main.tf
# module "vpc" {
#   source = "../modules/vpc-network"

#   project_id      = var.project_id
#   sponsor         = var.sponsor
#   environment     = var.environment
#   region          = var.region
#   app_subnet_cidr = local.app_subnet_cidr
#   db_subnet_cidr  = local.db_subnet_cidr
#   connector_cidr  = local.connector_cidr

#   connector_min_instances = local.connector_min
#   connector_max_instances = local.connector_max
# }

# -----------------------------------------------------------------------------
# Audit Logs (FDA Compliant)
# -----------------------------------------------------------------------------
# TODO import the existing network, synch with infrastructure/terraform/bootstrap/main.tf
# module "audit_logs" {
#   source = "../modules/audit-logs"

#   project_id            = var.project_id
#   project_prefix        = var.project_prefix
#   sponsor               = var.sponsor
#   environment           = var.environment
#   region                = var.region
#   retention_years       = local.is_production ? var.audit_retention_years : 0
#   lock_retention_policy = local.lock_audit_retention
# }

# -----------------------------------------------------------------------------
# Cloud SQL
# -----------------------------------------------------------------------------
# TODO import the existing network, synch with infrastructure/terraform/bootstrap/main.tf
# module "cloud_sql" {
#   source = "../modules/cloud-sql"

#   project_id             = var.project_id
#   sponsor                = var.sponsor
#   environment            = var.environment
#   region                 = var.region
#   vpc_network_id         = module.vpc.network_id
#   private_vpc_connection = module.vpc.private_vpc_connection
#   DB_PASSWORD            = var.DB_PASSWORD

#   depends_on = [module.vpc]
# }

# -----------------------------------------------------------------------------
# Cloud Run Services
# -----------------------------------------------------------------------------
# TODO import the existing network, synch with infrastructure/terraform/bootstrap/main.tf
# module "cloud_run" {
#   source = "../modules/cloud-run"

#   project_id       = var.project_id
#   sponsor          = var.sponsor
#   environment      = var.environment
#   region           = var.region
#   vpc_connector_id = module.vpc.connector_id

#   # Container images (via Artifact Registry GHCR proxy)
#   diary_server_image  = var.diary_server_image
#   portal_server_image = var.portal_server_image

#   db_host               = module.cloud_sql.private_ip_address
#   db_name               = module.cloud_sql.database_name
#   db_user               = module.cloud_sql.database_user
#   db_password_secret_id = google_secret_manager_secret.db_password.secret_id

#   min_instances    = var.min_instances
#   max_instances    = var.max_instances
#   container_memory = var.container_memory
#   container_cpu    = var.container_cpu

#   allow_public_access = var.allow_public_access

#   depends_on = [
#     module.vpc,
#     module.cloud_sql,
#     google_secret_manager_secret_version.db_password,
#   ]
# }

# -----------------------------------------------------------------------------
# Storage Buckets
# -----------------------------------------------------------------------------

# module "storage" {
#   source = "../modules/storage-buckets"

#   project_id    = var.project_id
#   sponsor       = var.sponsor
#   environment   = var.environment
#   region        = var.region
# }

# -----------------------------------------------------------------------------
# Monitoring Alerts
# -----------------------------------------------------------------------------

# module "monitoring" {
#   source = "../modules/monitoring-alerts"

#   project_id            = var.project_id
#   sponsor               = var.sponsor
#   environment           = var.environment
#   portal_url            = module.cloud_run.portal_server_url
#   notification_channels = var.notification_channels

#   depends_on = [module.cloud_run]
# }

# module "cloud_functions" {
#   source = "../modules/cloud-functions"

#   project_id            = var.project_id
#   project_number        = var.project_number
#   region                = var.region
#   sponsor               = var.sponsor
#   environment           = var.environment
#   budget_alert_topic_id = module.billing_budget.budget_alert_topic
#   function_source_dir   = "${path.root}/../../functions"
#   slack_webhook_url     = var.slack_webhook_devops_url
# }

# -----------------------------------------------------------------------------
# Billing Alert Function (automated cost control)
# Moved from bootstrap to sponsor-portal for per-environment deployment
# -----------------------------------------------------------------------------

module "billing_alerts" {
  source = "../modules/billing-alert-funk"
  count  = var.enable_cost_controls ? 1 : 0

  project_id            = var.project_id
  project_number        = var.project_number
  region                = var.region
  sponsor               = var.sponsor
  environment           = var.environment
  budget_alert_topic_id = data.terraform_remote_state.bootstrap.outputs.budget_alert_topics[var.environment]
  # "${var.sponsor}-${var.environment}-budget-alerts"
  function_source_dir   = "${path.module}/../modules/billing-alert-funk/src"
  slack_webhook_url     = var.SLACK_INCIDENT_WEBHOOK_URL
}

# -----------------------------------------------------------------------------
# Identity Platform (HIPAA/GDPR-compliant authentication)
# -----------------------------------------------------------------------------

# Import existing Identity Platform config that was enabled outside Terraform
# import {
#   to = module.identity_platform[0].google_identity_platform_config.main
#   id = "projects/${var.project_id}"
# }

module "identity_platform" {
  source = "../modules/identity-platform"
  count  = var.enable_identity_platform ? 1 : 0

  project_id  = var.project_id
  sponsor     = var.sponsor
  environment = var.environment

  # Authentication methods
  enable_email_password = var.identity_platform_email_password
  enable_email_link     = var.identity_platform_email_link
  enable_phone_auth     = var.identity_platform_phone_auth

  # Security settings
  mfa_enforcement           = var.identity_platform_mfa_enforcement
  password_min_length       = var.identity_platform_password_min_length
  password_require_uppercase = true
  password_require_lowercase = true
  password_require_numeric   = true
  password_require_symbol    = true

  # Email configuration
  email_sender_name = var.identity_platform_email_sender_name
  email_reply_to    = var.identity_platform_email_reply_to

  # Domain configuration
  authorized_domains = var.identity_platform_authorized_domains
  portal_url         = var.portal_server_url

  # Session settings
  session_duration_minutes = var.identity_platform_session_duration

  # depends_on = [module.cloud_run]
}

# -----------------------------------------------------------------------------
# Workforce Identity (Optional - for external IdP federation)
# -----------------------------------------------------------------------------
# TODO 
# module "workforce_identity" {
#   source = "../modules/workforce-identity"

#   enabled                = var.workforce_identity_enabled
#   project_id             = var.project_id
#   GCP_ORG_ID             = var.GCP_ORG_ID
#   sponsor                = var.sponsor
#   environment            = var.environment
#   region                 = var.region
#   provider_type          = var.workforce_identity_provider_type
#   oidc_issuer_uri        = var.workforce_identity_issuer_uri
#   oidc_client_id         = var.workforce_identity_client_id
#   oidc_client_secret     = var.workforce_identity_client_secret
#   allowed_email_domain   = var.workforce_identity_allowed_domain
#   cloud_run_service_name = module.cloud_run.portal_server_name
# }

# -----------------------------------------------------------------------------
# Service Account IAM (Cross-Project Gmail SA Impersonation)
# -----------------------------------------------------------------------------
#
# The Gmail service account for email OTP and activation codes is managed
# centrally in the cure-hht-admin project (infrastructure/terraform/admin-project/).
#
# To enable email sending for this sponsor/environment:
# 1. Add the Cloud Run service account to the admin project's
#    sponsor_cloud_run_service_accounts variable
# 2. Store the Gmail SA key in Doppler for this environment
#
# Cloud Run service account: ${module.cloud_run.portal_server_service_account_email}
