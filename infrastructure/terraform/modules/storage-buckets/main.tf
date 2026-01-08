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

  name                        = "${var.project_id}-app-data"
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
