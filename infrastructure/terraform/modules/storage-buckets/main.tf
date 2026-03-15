# modules/storage-buckets/main.tf
#
# Creates storage buckets for backups and application data
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------

locals {
  is_production = var.environment == "prod"

  common_labels = {
    sponsor     = var.sponsor
    environment = var.environment
    managed_by  = "terraform"
    compliance  = "fda-21-cfr-part-11"
  }
}

# -----------------------------------------------------------------------------
# Backup Bucket
# -----------------------------------------------------------------------------

resource "google_storage_bucket" "backups" {
  name                        = "${var.project_id}-backups"
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  labels = merge(local.common_labels, {
    purpose = "database-backups"
  })

  versioning {
    enabled = true
  }

  soft_delete_policy {
    retention_duration_seconds = 30 * 24 * 60 * 60 # 30 days
  }

  # Lifecycle rules for backup retention
  lifecycle_rule {
    condition {
      age = var.backup_retention_days
    }
    action {
      type = "Delete"
    }
  }

  # Move old backups to cheaper storage
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }
}

# -----------------------------------------------------------------------------
# Application Data Bucket (optional)
# -----------------------------------------------------------------------------

resource "google_storage_bucket" "app_data" {
  count = var.create_app_data_bucket ? 1 : 0

  name                        = "${var.project_prefix}-${var.project_id}-app-data"
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  labels = merge(local.common_labels, {
    purpose = "application-data"
  })

  versioning {
    enabled = true
  }

  soft_delete_policy {
    retention_duration_seconds = 7 * 24 * 60 * 60 # 7 days
  }

  # CORS configuration for direct uploads (if needed)
  dynamic "cors" {
    for_each = var.enable_cors ? [1] : []
    content {
      origin          = var.cors_origins
      method          = ["GET", "HEAD", "PUT", "POST"]
      response_header = ["Content-Type", "Content-Length", "ETag"]
      max_age_seconds = 3600
    }
  }
}

# -----------------------------------------------------------------------------
# Compute Service Account IAM (Storage Object User)
# -----------------------------------------------------------------------------

resource "google_storage_bucket_iam_member" "compute_backups_object_user" {
  count  = var.enable_compute_sa_access ? 1 : 0
  bucket = google_storage_bucket.backups.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${var.compute_service_account_email}"
}

resource "google_storage_bucket_iam_member" "compute_app_data_object_user" {
  count  = var.enable_compute_sa_access && var.create_app_data_bucket ? 1 : 0
  bucket = google_storage_bucket.app_data[0].name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${var.compute_service_account_email}"
}

# -----------------------------------------------------------------------------
# Schema Files Upload (for db-schema-job)
# -----------------------------------------------------------------------------
#
# Uploads consolidated schema and sponsor data files to the app_data bucket
# under the db-schema/ prefix for use by the database deployment job.
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00057: Automated database schema deployment
#   REQ-o00004: Database Schema Deployment

# Upload consolidated schema file
resource "google_storage_bucket_object" "schema_file" {
  count  = var.create_app_data_bucket && var.schema_file_source != "" ? 1 : 0
  name   = "${var.schema_prefix}/${var.schema_file_name}"
  bucket = google_storage_bucket.app_data[0].name
  source = var.schema_file_source

  # Detect changes via content hash
  content_type = "application/sql"
}

# Upload sponsor data file
resource "google_storage_bucket_object" "sponsor_data_file" {
  count  = var.create_app_data_bucket && var.sponsor_data_file_source != "" ? 1 : 0
  name   = "${var.schema_prefix}/${var.sponsor_data_file_name}"
  bucket = google_storage_bucket.app_data[0].name
  source = var.sponsor_data_file_source

  # Detect changes via content hash
  content_type = "application/sql"
}
