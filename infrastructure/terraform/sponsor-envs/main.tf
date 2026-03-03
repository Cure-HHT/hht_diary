# sponsor-envs/main.tf
#
# Deploys sponsor portal infrastructure for a single environment
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00008: Multi-sponsor deployment model
#   REQ-p00042: Infrastructure audit trail for FDA compliance

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------

locals {
  is_production = var.environment == "prod"

  # VPC CIDRs — hardcoded per-environment, matching deployed bootstrap defaults.
  # All sponsors use the same CIDRs (no collision: each env is a separate GCP project).
  default_cidrs = {
    app_subnet = {
      dev = "10.0.1.0/24", qa = "10.0.4.0/24", uat = "10.0.8.0/24", prod = "10.0.12.0/24"
    }
    db_subnet = {
      dev = "10.0.2.0/24", qa = "10.0.5.0/24", uat = "10.0.9.0/24", prod = "10.0.13.0/24"
    }
    connector = {
      dev = "10.0.3.0/28", qa = "10.0.6.0/28", uat = "10.0.10.0/28", prod = "10.0.14.0/28"
    }
    proxy_only = {
      dev = "10.0.16.0/23", qa = "10.0.18.0/23", uat = "10.0.20.0/23", prod = "10.0.22.0/23"
    }
  }

  # VPC connector sizing defaults
  connector_min = var.vpc_connector_min_instances > 0 ? var.vpc_connector_min_instances : (
    local.is_production ? 2 : 2
  )
  connector_max = var.vpc_connector_max_instances > 0 ? var.vpc_connector_max_instances : (
    local.is_production ? 10 : 3
  )

  # Billing account: prod uses prod account, others use dev account
  billing_account_id = local.is_production ? var.BILLING_ACCOUNT_PROD : var.BILLING_ACCOUNT_DEV

  common_labels = {
    sponsor     = var.sponsor
    environment = var.environment
    managed_by  = "terraform"
    compliance  = "fda-21-cfr-part-11"
  }
}

# -----------------------------------------------------------------------------
# Billing Budgets (per-environment)
# Migrated from bootstrap via scripts/migrate-budgets-audit-to-sponsor-envs.sh
# -----------------------------------------------------------------------------

module "budgets" {
  source = "../modules/billing-budget"

  billing_account_id   = local.billing_account_id
  project_id           = var.project_id
  project_number       = var.project_number
  sponsor              = var.sponsor
  environment          = var.environment
  budget_amount        = var.budget_amount
  enable_cost_controls = var.enable_cost_controls
}

# -----------------------------------------------------------------------------
# VPC Network (per-environment)
# Migrated from bootstrap via scripts/migrate-network-to-sponsor-envs.sh
# -----------------------------------------------------------------------------

module "network" {
  source = "../modules/vpc-network"

  project_id               = var.project_id
  environment              = var.environment
  sponsor                  = var.sponsor
  region                   = var.region
  app_subnet_cidr          = local.default_cidrs.app_subnet[var.environment]
  db_subnet_cidr           = local.default_cidrs.db_subnet[var.environment]
  connector_cidr           = local.default_cidrs.connector[var.environment]
  enable_proxy_only_subnet = var.enable_proxy_only_subnet
  proxy_only_subnet_cidr   = local.default_cidrs.proxy_only[var.environment]
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

# Grant Compute Engine default service account read access to Doppler token
# Required for Cloud Run services to fetch secrets at runtime
resource "google_secret_manager_secret_iam_member" "doppler_token_compute_accessor" {
  count     = var.compute_service_account != "" ? 1 : 0
  secret_id = google_secret_manager_secret.doppler_token.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.compute_service_account}"
}

# Grant Compute Engine default service account Identity Platform admin access
# Required for deploy-db job to batch-delete and seed Identity Platform users
# via Identity Toolkit REST API and seed_identity_users.js
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00031: Identity Platform Integration (user seeding)
resource "google_project_iam_member" "compute_sa_identity_platform_admin" {
  count   = var.compute_service_account != "" ? 1 : 0
  project = var.project_id
  role    = "roles/identityplatform.admin"
  member  = "serviceAccount:${var.compute_service_account}"
}

resource "google_project_iam_member" "compute_sa_service_usage_consumer" {
  count   = var.compute_service_account != "" ? 1 : 0
  project = var.project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:${var.compute_service_account}"
}

# -----------------------------------------------------------------------------
# Audit Logs (FDA Compliant)
# Migrated from bootstrap via scripts/migrate-budgets-audit-to-sponsor-envs.sh
# -----------------------------------------------------------------------------

module "audit_logs" {
  source = "../modules/audit-logs"

  project_id               = var.project_id
  project_prefix           = var.project_prefix
  sponsor                  = var.sponsor
  environment              = var.environment
  region                   = var.region
  retention_years          = local.is_production ? var.audit_retention_years : 0
  lock_retention_policy    = var.lock_audit_retention
  include_data_access_logs = var.include_data_access_logs
}

# -----------------------------------------------------------------------------
# Cloud SQL Database
# Migrated from bootstrap via scripts/migrate-db-to-sponsor-envs.sh
# -----------------------------------------------------------------------------

module "database" {
  source = "../modules/cloud-sql"

  project_id             = var.project_id
  sponsor                = var.sponsor
  environment            = var.environment
  region                 = var.region
  vpc_network_id         = module.network.network_id
  private_vpc_connection = module.network.private_vpc_connection
  database_name          = var.database_name
  db_username            = var.db_username
  DB_PASSWORD            = var.DB_PASSWORD
  disk_size              = var.disk_size

  # Backup & recovery (REQ-p00047, REQ-o00008)
  backup_start_time              = var.backup_start_time
  transaction_log_retention_days = var.transaction_log_retention_days
  backup_retention_override      = var.backup_retention_override

  # Disk auto-resize
  disk_autoresize_limit_override = var.disk_autoresize_limit_override

  # Maintenance window: Sunday 05:00 UTC = 06:00 CET
  maintenance_window_day  = 7
  maintenance_window_hour = 5
}

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
  budget_alert_topic_id = module.budgets.budget_alert_topic
  # "${var.sponsor}-${var.environment}-budget-alerts"
  function_source_dir = "${path.module}/../modules/billing-alert-funk/src"
  slack_webhook_url   = var.SLACK_INCIDENT_WEBHOOK_URL
}

# -----------------------------------------------------------------------------
# Billing Stop Function (automated cost control – disables billing)
# Unlinks the billing account when spend exceeds the configured threshold.
# -----------------------------------------------------------------------------

module "billing_stop" {
  source = "../modules/billing-stop-funk"
  count  = var.enable_cost_controls ? 1 : 0

  project_id            = var.project_id
  project_number        = var.project_number
  region                = var.region
  sponsor               = var.sponsor
  environment           = var.environment
  budget_alert_topic_id = module.budgets.budget_alert_topic
  function_source_dir   = "${path.module}/../modules/billing-stop-funk/src"
  slack_webhook_url     = var.SLACK_INCIDENT_WEBHOOK_URL
  threshold_cutoff      = var.threshold_cutoff
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
  mfa_enforcement            = var.identity_platform_mfa_enforcement
  password_min_length        = var.identity_platform_password_min_length
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

# -----------------------------------------------------------------------------
# Gmail API for Email Sending (OTP, activation codes, notifications)
# -----------------------------------------------------------------------------
#
# Enable the Gmail API and create a dedicated service account for Cloud Run
# services to send email via Gmail.
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00008: Multi-sponsor deployment model

# Enable Gmail API
resource "google_project_service" "gmail_api" {
  count   = var.enable_gmail_api ? 1 : 0
  project = var.project_id
  service = "gmail.googleapis.com"

  disable_on_destroy = false
}

# Service account for Cloud Run email sending
resource "google_service_account" "cloud_run_mailer" {
  count        = var.enable_gmail_api ? 1 : 0
  account_id   = "cloud-run-mailer"
  display_name = "Cloud Run Mailer Service Account"
  description  = "Service account for sending emails via Gmail API from Cloud Run services"
  project      = var.project_id
}

# Allow the default Compute service account to impersonate the mailer SA
# This enables Cloud Run services (which run as the compute SA) to use the mailer identity
resource "google_service_account_iam_member" "cloud_run_mailer_user" {
  count              = var.enable_gmail_api && var.compute_service_account != "" ? 1 : 0
  service_account_id = google_service_account.cloud_run_mailer[0].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.compute_service_account}"
}

# -----------------------------------------------------------------------------
# GitHub Actions Service Account IAM (Cross-Project Cloud Run Deployment)
# -----------------------------------------------------------------------------
#
# The GitHub Actions service account lives in the admin project but needs
# permissions to deploy Cloud Run services to this sponsor/environment project.
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00044: GCP Authentication via Workload Identity Federation
#   REQ-o00043: Automated Deployment Pipeline

# Cloud Run Admin - deploy and manage Cloud Run services
resource "google_project_iam_member" "github_actions_run_admin" {
  count   = var.github_actions_sa != "" ? 1 : 0
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${var.github_actions_sa}"
}

# Service Account User - deploy with a service identity
resource "google_project_iam_member" "github_actions_sa_user" {
  count   = var.github_actions_sa != "" ? 1 : 0
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${var.github_actions_sa}"
}

# Cloud SQL Client - for --set-cloudsql-instances flag
resource "google_project_iam_member" "github_actions_cloudsql_client" {
  count   = var.github_actions_sa != "" ? 1 : 0
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${var.github_actions_sa}"
}

# VPC Access User - for --vpc-connector flag
resource "google_project_iam_member" "github_actions_vpcaccess_user" {
  count   = var.github_actions_sa != "" ? 1 : 0
  project = var.project_id
  role    = "roles/vpcaccess.user"
  member  = "serviceAccount:${var.github_actions_sa}"
}

# -----------------------------------------------------------------------------
# Regional Load Balancer (europe-west9)
# -----------------------------------------------------------------------------
#
# Creates a Regional External HTTPS Load Balancer with:
# - Regional static IP (Standard network tier)
# - Proxy-only subnet for Envoy-based load balancers
# - DNS authorization for domain validation at Gandi.net
# - Google-managed regional SSL certificate
# - Regional backend service, URL map, HTTPS proxy, and forwarding rule
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00008: Multi-sponsor deployment model

# Enable Certificate Manager API (required for Regional Load Balancer)
resource "google_project_service" "certificate_manager_api" {
  count   = var.enable_regional_lb ? 1 : 0
  project = var.project_id
  service = "certificatemanager.googleapis.com"

  disable_on_destroy = false
}

module "regional_load_balancer" {
  source = "../modules/regional-load-balancer"
  count  = var.enable_regional_lb ? 1 : 0

  project_id             = var.project_id
  sponsor                = var.sponsor
  environment            = var.environment
  region                 = var.region
  domain                 = var.lb_domain
  proxy_only_subnet_id   = module.network.proxy_only_subnet_id
  proxy_only_subnet_cidr = module.network.proxy_only_subnet_cidr != null ? module.network.proxy_only_subnet_cidr : ""
  vpc_network_self_link  = module.network.network_self_link

  # Optional configuration
  backend_timeout_sec  = var.lb_backend_timeout_sec
  enable_logging       = var.lb_enable_logging
  log_sample_rate      = var.lb_log_sample_rate
  enable_http_redirect = var.lb_enable_http_redirect

  # Cloud Run backends (host-based routing)
  cloud_run_services        = var.lb_cloud_run_services
  default_cloud_run_service = var.lb_default_cloud_run_service

  depends_on = [google_project_service.certificate_manager_api]
}

# -----------------------------------------------------------------------------
# Cloud Run Service Agent IAM (Cross-Project Artifact Registry Access)
# -----------------------------------------------------------------------------
#
# The Cloud Run Service Agent needs permission to pull container images from
# the admin project's Artifact Registry (ghcr-remote repository).
#
# NOTE: This binding is managed in infrastructure/terraform/admin-project/main.tf
# via the sponsor_cloud_run_service_agents variable.
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00043: Automated Deployment Pipeline
#   REQ-o00001: Separate GCP Projects Per Sponsor
