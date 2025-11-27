# IMPLEMENTS REQUIREMENTS:
#   REQ-o00041: Infrastructure as Code for Cloud Resources
#
# Outputs for GCP Sponsor Project Module

# -----------------------------------------------------------------------------
# Project Information
# -----------------------------------------------------------------------------
output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}

# -----------------------------------------------------------------------------
# Network
# -----------------------------------------------------------------------------
output "vpc_id" {
  description = "VPC Network ID"
  value       = google_compute_network.main.id
}

output "vpc_name" {
  description = "VPC Network name"
  value       = google_compute_network.main.name
}

output "subnet_id" {
  description = "Subnet ID"
  value       = google_compute_subnetwork.main.id
}

output "vpc_connector_id" {
  description = "VPC Access Connector ID"
  value       = google_vpc_access_connector.main.id
}

output "vpc_connector_name" {
  description = "VPC Access Connector name"
  value       = google_vpc_access_connector.main.name
}

# -----------------------------------------------------------------------------
# Cloud SQL
# -----------------------------------------------------------------------------
output "cloudsql_instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.main.name
}

output "cloudsql_connection_name" {
  description = "Cloud SQL connection name for Cloud Run"
  value       = google_sql_database_instance.main.connection_name
}

output "cloudsql_private_ip" {
  description = "Cloud SQL private IP address"
  value       = google_sql_database_instance.main.private_ip_address
}

output "database_name" {
  description = "Database name"
  value       = google_sql_database.main.name
}

# -----------------------------------------------------------------------------
# Secrets
# -----------------------------------------------------------------------------
output "db_password_secret_id" {
  description = "Secret Manager ID for database password"
  value       = google_secret_manager_secret.db_app_password.secret_id
}

output "database_url_secret_id" {
  description = "Secret Manager ID for database URL"
  value       = google_secret_manager_secret.database_url.secret_id
}

# -----------------------------------------------------------------------------
# Artifact Registry
# -----------------------------------------------------------------------------
output "artifact_registry_repository" {
  description = "Artifact Registry repository name"
  value       = google_artifact_registry_repository.images.name
}

output "artifact_registry_url" {
  description = "Artifact Registry URL for Docker"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
}

# -----------------------------------------------------------------------------
# Service Accounts
# -----------------------------------------------------------------------------
output "api_server_sa_email" {
  description = "API Server service account email"
  value       = google_service_account.api_server.email
}

output "portal_server_sa_email" {
  description = "Portal Server service account email"
  value       = google_service_account.portal_server.email
}

output "cicd_deployer_sa_email" {
  description = "CI/CD Deployer service account email"
  value       = google_service_account.cicd_deployer.email
}

# -----------------------------------------------------------------------------
# Storage
# -----------------------------------------------------------------------------
output "backup_bucket_name" {
  description = "Cloud Storage bucket for backups"
  value       = google_storage_bucket.backups.name
}

output "backup_bucket_url" {
  description = "Cloud Storage bucket URL"
  value       = google_storage_bucket.backups.url
}

# -----------------------------------------------------------------------------
# Computed Values for Deployment
# -----------------------------------------------------------------------------
output "api_service_name" {
  description = "Cloud Run API service name"
  value       = local.api_service_name
}

output "portal_service_name" {
  description = "Cloud Run Portal service name"
  value       = local.portal_service_name
}

output "deployment_info" {
  description = "Deployment information for CI/CD"
  value = {
    project_id               = var.project_id
    region                   = var.region
    sponsor                  = var.sponsor
    environment              = var.environment
    api_service_name         = local.api_service_name
    portal_service_name      = local.portal_service_name
    artifact_registry_url    = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
    cloudsql_connection_name = google_sql_database_instance.main.connection_name
    vpc_connector_name       = google_vpc_access_connector.main.name
    api_sa_email             = google_service_account.api_server.email
    portal_sa_email          = google_service_account.portal_server.email
  }
}
