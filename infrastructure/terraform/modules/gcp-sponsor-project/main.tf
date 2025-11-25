# IMPLEMENTS REQUIREMENTS:
#   REQ-o00041: Infrastructure as Code for Cloud Resources
#   REQ-o00042: Infrastructure Change Control
#   REQ-o00003: GCP Project Provisioning Per Sponsor
#   REQ-o00004: Database Schema Deployment
#
# GCP Sponsor Project Terraform Module
# Creates and configures a complete GCP project for a Clinical Trial Diary sponsor

terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------
locals {
  project_id         = "hht-diary-${var.sponsor}-${var.environment}"
  instance_name      = "${var.sponsor}-db-${var.environment}"
  api_service_name   = "api-${var.sponsor}-${var.environment}"
  portal_service_name = "portal-${var.sponsor}-${var.environment}"

  # Default labels for all resources
  default_labels = {
    sponsor     = var.sponsor
    environment = var.environment
    managed-by  = "terraform"
    app         = "clinical-diary"
  }

  labels = merge(local.default_labels, var.labels)
}

# -----------------------------------------------------------------------------
# Enable Required APIs
# -----------------------------------------------------------------------------
resource "google_project_service" "apis" {
  for_each = toset([
    "sqladmin.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "identitytoolkit.googleapis.com",
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "vpcaccess.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# VPC Network
# -----------------------------------------------------------------------------
resource "google_compute_network" "main" {
  name                    = "${var.sponsor}-${var.environment}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false

  depends_on = [google_project_service.apis]
}

resource "google_compute_subnetwork" "main" {
  name          = "${var.sponsor}-${var.environment}-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.main.id
  ip_cidr_range = var.vpc_cidr

  private_ip_google_access = true
}

# -----------------------------------------------------------------------------
# Private Service Connection (for Cloud SQL)
# -----------------------------------------------------------------------------
resource "google_compute_global_address" "private_ip_range" {
  name          = "${var.sponsor}-${var.environment}-private-ip"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# VPC Access Connector (for Cloud Run to Cloud SQL)
# -----------------------------------------------------------------------------
resource "google_vpc_access_connector" "main" {
  name          = "${var.sponsor}-vpc-connector"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.main.name
  ip_cidr_range = var.vpc_connector_cidr

  min_instances = 2
  max_instances = var.environment == "prod" ? 10 : 3

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# Cloud SQL Instance
# -----------------------------------------------------------------------------
resource "google_sql_database_instance" "main" {
  name             = local.instance_name
  project          = var.project_id
  region           = var.region
  database_version = "POSTGRES_15"

  settings {
    tier              = var.db_tier
    availability_type = var.environment == "prod" ? "REGIONAL" : "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = var.db_disk_size
    disk_autoresize   = true

    backup_configuration {
      enabled                        = true
      start_time                     = "02:00"
      point_in_time_recovery_enabled = true
      backup_retention_settings {
        retained_backups = var.db_backup_retention_days
      }
    }

    maintenance_window {
      day  = 7 # Sunday
      hour = 3
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.main.id
    }

    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }

    insights_config {
      query_insights_enabled  = true
      query_string_length     = 4096
      record_application_tags = true
      record_client_address   = true
    }

    user_labels = local.labels
  }

  deletion_protection = var.environment == "prod"

  depends_on = [
    google_service_networking_connection.private_vpc_connection,
    google_project_service.apis
  ]
}

resource "google_sql_database" "main" {
  name      = "clinical_diary"
  project   = var.project_id
  instance  = google_sql_database_instance.main.name
  charset   = "UTF8"
  collation = "en_US.UTF8"
}

resource "google_sql_user" "app" {
  name     = "app_user"
  project  = var.project_id
  instance = google_sql_database_instance.main.name
  password = var.db_app_password
}

# -----------------------------------------------------------------------------
# Secret Manager
# -----------------------------------------------------------------------------
resource "google_secret_manager_secret" "db_app_password" {
  secret_id = "db-app-password"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = local.labels

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "db_app_password" {
  secret      = google_secret_manager_secret.db_app_password.id
  secret_data = var.db_app_password
}

resource "google_secret_manager_secret" "database_url" {
  secret_id = "database-url"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = local.labels

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "database_url" {
  secret = google_secret_manager_secret.database_url.id
  secret_data = "postgresql://app_user:${var.db_app_password}@/clinical_diary?host=/cloudsql/${var.project_id}:${var.region}:${local.instance_name}"
}

# -----------------------------------------------------------------------------
# Artifact Registry
# -----------------------------------------------------------------------------
resource "google_artifact_registry_repository" "images" {
  repository_id = "${var.sponsor}-images"
  project       = var.project_id
  location      = var.region
  format        = "DOCKER"
  description   = "Container images for ${var.sponsor} Clinical Diary"

  labels = local.labels

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# Service Accounts
# -----------------------------------------------------------------------------
resource "google_service_account" "api_server" {
  account_id   = "api-server"
  display_name = "API Server Service Account"
  project      = var.project_id
}

resource "google_service_account" "portal_server" {
  account_id   = "portal-server"
  display_name = "Portal Server Service Account"
  project      = var.project_id
}

resource "google_service_account" "cicd_deployer" {
  account_id   = "cicd-deployer"
  display_name = "CI/CD Deployer Service Account"
  project      = var.project_id
}

# API Server permissions
resource "google_project_iam_member" "api_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.api_server.email}"
}

resource "google_project_iam_member" "api_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.api_server.email}"
}

resource "google_project_iam_member" "api_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.api_server.email}"
}

# Portal Server permissions
resource "google_project_iam_member" "portal_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.portal_server.email}"
}

# CI/CD Deployer permissions
resource "google_project_iam_member" "cicd_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.cicd_deployer.email}"
}

resource "google_project_iam_member" "cicd_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cicd_deployer.email}"
}

resource "google_project_iam_member" "cicd_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cicd_deployer.email}"
}

resource "google_project_iam_member" "cicd_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cicd_deployer.email}"
}

# -----------------------------------------------------------------------------
# Cloud Storage (for backups and exports)
# -----------------------------------------------------------------------------
resource "google_storage_bucket" "backups" {
  name     = "${var.project_id}-backups"
  project  = var.project_id
  location = var.region

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = var.backup_storage_retention_days
    }
    action {
      type = "Delete"
    }
  }

  versioning {
    enabled = true
  }

  labels = local.labels

  depends_on = [google_project_service.apis]
}

# -----------------------------------------------------------------------------
# Monitoring Alert Policies
# -----------------------------------------------------------------------------
resource "google_monitoring_alert_policy" "high_cpu" {
  count        = var.enable_monitoring_alerts ? 1 : 0
  display_name = "Cloud SQL High CPU - ${local.instance_name}"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "CPU utilization > 80%"
    condition_threshold {
      filter          = "resource.type = \"cloudsql_database\" AND metric.type = \"cloudsql.googleapis.com/database/cpu/utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
    }
  }

  notification_channels = var.notification_channels

  depends_on = [google_project_service.apis]
}

resource "google_monitoring_alert_policy" "high_storage" {
  count        = var.enable_monitoring_alerts ? 1 : 0
  display_name = "Cloud SQL High Storage - ${local.instance_name}"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Disk utilization > 80%"
    condition_threshold {
      filter          = "resource.type = \"cloudsql_database\" AND metric.type = \"cloudsql.googleapis.com/database/disk/utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
    }
  }

  notification_channels = var.notification_channels

  depends_on = [google_project_service.apis]
}
