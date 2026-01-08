# sponsor-portal/main.tf
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
# Secret Manager - Database Password
# -----------------------------------------------------------------------------

resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.sponsor}-${var.environment}-db-password"
  project   = var.project_id

  labels = local.common_labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}

# -----------------------------------------------------------------------------
# VPC Network
# -----------------------------------------------------------------------------

module "vpc" {
  source = "../modules/vpc-network"

  project_id      = var.project_id
  sponsor         = var.sponsor
  environment     = var.environment
  region          = var.region
  app_subnet_cidr = local.app_subnet_cidr
  db_subnet_cidr  = local.db_subnet_cidr
  connector_cidr  = local.connector_cidr

  connector_min_instances = local.connector_min
  connector_max_instances = local.connector_max
}

# -----------------------------------------------------------------------------
# Cloud SQL
# -----------------------------------------------------------------------------

module "cloud_sql" {
  source = "../modules/cloud-sql"

  project_id             = var.project_id
  sponsor                = var.sponsor
  environment            = var.environment
  region                 = var.region
  vpc_network_id         = module.vpc.network_id
  private_vpc_connection = module.vpc.private_vpc_connection
  db_password            = var.db_password

  depends_on = [module.vpc]
}

# -----------------------------------------------------------------------------
# Artifact Registry
# -----------------------------------------------------------------------------

module "artifact_registry" {
  source = "../modules/artifact-registry"

  project_id           = var.project_id
  sponsor              = var.sponsor
  environment          = var.environment
  region               = var.region
  cicd_service_account = var.cicd_service_account
}

# -----------------------------------------------------------------------------
# Cloud Run Services
# -----------------------------------------------------------------------------

module "cloud_run" {
  source = "../modules/cloud-run"

  project_id       = var.project_id
  sponsor          = var.sponsor
  environment      = var.environment
  region           = var.region
  vpc_connector_id = module.vpc.connector_id

  # Use placeholder images initially - CI/CD will deploy actual images
  diary_server_image  = "${module.artifact_registry.diary_server_image_base}:latest"
  portal_server_image = "${module.artifact_registry.portal_server_image_base}:latest"

  db_host               = module.cloud_sql.private_ip_address
  db_name               = module.cloud_sql.database_name
  db_user               = module.cloud_sql.database_user
  db_password_secret_id = google_secret_manager_secret.db_password.secret_id

  min_instances    = var.min_instances
  max_instances    = var.max_instances
  container_memory = var.container_memory
  container_cpu    = var.container_cpu

  depends_on = [
    module.vpc,
    module.cloud_sql,
    module.artifact_registry,
    google_secret_manager_secret_version.db_password,
  ]
}

# -----------------------------------------------------------------------------
# Storage Buckets
# -----------------------------------------------------------------------------

module "storage" {
  source = "../modules/storage-buckets"

  project_id    = var.project_id
  sponsor       = var.sponsor
  environment   = var.environment
  region        = var.region
}

# -----------------------------------------------------------------------------
# Audit Logs (FDA Compliant)
# -----------------------------------------------------------------------------

module "audit_logs" {
  source = "../modules/audit-logs"

  project_id            = var.project_id
  project_prefix        = var.project_prefix
  sponsor               = var.sponsor
  environment           = var.environment
  region                = var.region
  retention_years       = var.audit_retention_years
  lock_retention_policy = local.lock_audit_retention
}

# -----------------------------------------------------------------------------
# Monitoring Alerts
# -----------------------------------------------------------------------------

module "monitoring" {
  source = "../modules/monitoring-alerts"

  project_id            = var.project_id
  sponsor               = var.sponsor
  environment           = var.environment
  portal_url            = module.cloud_run.portal_server_url
  notification_channels = var.notification_channels

  depends_on = [module.cloud_run]
}

# -----------------------------------------------------------------------------
# Cloud Build Triggers (Optional)
# -----------------------------------------------------------------------------

module "cloud_build" {
  source = "../modules/cloud-build"
  count  = var.enable_cloud_build_triggers ? 1 : 0

  project_id            = var.project_id
  sponsor               = var.sponsor
  environment           = var.environment
  region                = var.region
  github_org            = var.github_org
  github_repo           = var.github_repo
  artifact_registry_url = module.artifact_registry.repository_url
  trigger_branch        = var.environment == "prod" ? "^main$" : "^${var.environment}$"
}

# -----------------------------------------------------------------------------
# Workforce Identity (Optional)
# -----------------------------------------------------------------------------

module "workforce_identity" {
  source = "../modules/workforce-identity"

  enabled                = var.workforce_identity_enabled
  project_id             = var.project_id
  gcp_org_id             = var.gcp_org_id
  sponsor                = var.sponsor
  environment            = var.environment
  region                 = var.region
  provider_type          = var.workforce_identity_provider_type
  oidc_issuer_uri        = var.workforce_identity_issuer_uri
  oidc_client_id         = var.workforce_identity_client_id
  oidc_client_secret     = var.workforce_identity_client_secret
  allowed_email_domain   = var.workforce_identity_allowed_domain
  cloud_run_service_name = module.cloud_run.portal_server_name
}
