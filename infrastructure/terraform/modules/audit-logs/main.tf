# modules/audit-logs/main.tf
#
# Creates FDA 21 CFR Part 11 compliant audit log infrastructure
# - GCS bucket with 25-year retention (locked in prod only)
# - Log sink to export Cloud Audit Logs
# - Lifecycle rules for cost optimization (COLDLINE/ARCHIVE)
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-p00042: Infrastructure audit trail for FDA compliance
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
  bucket_name = "${var.sponsor}-${var.environment}-audit-logs"

  # Calculate retention in seconds (25 years)
  retention_seconds = var.retention_years * 365 * 24 * 60 * 60

  common_labels = {
    sponsor         = var.sponsor
    environment     = var.environment
    managed_by      = "terraform"
    compliance      = "fda-21-cfr-part-11"
    purpose         = "fda-audit-trail"
    retention_years = tostring(var.retention_years)
  }
}

# -----------------------------------------------------------------------------
# Audit Log Storage Bucket
# -----------------------------------------------------------------------------

resource "google_storage_bucket" "audit_logs" {
  name                        = local.bucket_name
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  labels = local.common_labels

  # FDA 21 CFR Part 11: 25-year retention with optional lock
  # WARNING: Once locked, retention CANNOT be shortened or removed
  retention_policy {
    retention_period = local.retention_seconds
    is_locked        = var.lock_retention_policy
  }

  # Enable versioning for additional protection
  versioning {
    enabled = true
  }

  # Soft delete for 30 days
  soft_delete_policy {
    retention_duration_seconds = 30 * 24 * 60 * 60
  }

  # Lifecycle rules for cost optimization
  # Move to cheaper storage classes over time

  # After 90 days, move to COLDLINE (~$0.004/GB/month)
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  # After 1 year, move to ARCHIVE (~$0.0012/GB/month)
  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type          = "SetStorageClass"
      storage_class = "ARCHIVE"
    }
  }

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = false # Set to true for production via CI/CD policies
  }
}

# -----------------------------------------------------------------------------
# Log Sink - Export Cloud Audit Logs to GCS
# -----------------------------------------------------------------------------

resource "google_logging_project_sink" "audit_sink" {
  name        = "${var.sponsor}-${var.environment}-audit-log-sink"
  project     = var.project_id
  destination = "storage.googleapis.com/${google_storage_bucket.audit_logs.name}"

  # Filter for Cloud Audit Logs
  # Captures: Admin Activity, Data Access (if enabled), System Events, Policy Denied
  filter = <<-EOT
    logName:"cloudaudit.googleapis.com"
    AND protoPayload.@type="type.googleapis.com/google.cloud.audit.AuditLog"
    ${var.include_data_access_logs ? "" : "AND NOT logName:\"data_access\""}
  EOT

  description = "FDA 21 CFR Part 11 compliant audit log export (${var.retention_years}-year retention${var.lock_retention_policy ? ", LOCKED" : ""})"

  # Create unique writer identity for this sink
  unique_writer_identity = true
}

# -----------------------------------------------------------------------------
# IAM - Grant log sink permission to write to bucket
# -----------------------------------------------------------------------------

resource "google_storage_bucket_iam_member" "sink_writer" {
  bucket = google_storage_bucket.audit_logs.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.audit_sink.writer_identity
}

# -----------------------------------------------------------------------------
# Optional: BigQuery Dataset for Audit Analytics
# -----------------------------------------------------------------------------

resource "google_bigquery_dataset" "audit_analytics" {
  count = var.create_bigquery_dataset ? 1 : 0

  dataset_id  = "audit_logs_${replace(var.sponsor, "-", "_")}_${var.environment}"
  project     = var.project_id
  location    = var.region
  description = "Audit log analytics for ${var.sponsor} ${var.environment}"

  labels = local.common_labels

  # No table expiration - compliance requires indefinite retention
  default_table_expiration_ms = null

  access {
    role          = "OWNER"
    special_group = "projectOwners"
  }

  access {
    role          = "READER"
    special_group = "projectReaders"
  }
}

# BigQuery log sink
resource "google_logging_project_sink" "audit_sink_bq" {
  count = var.create_bigquery_dataset ? 1 : 0

  name        = "${var.sponsor}-${var.environment}-audit-log-sink-bq"
  project     = var.project_id
  destination = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.audit_analytics[0].dataset_id}"

  filter = <<-EOT
    logName:"cloudaudit.googleapis.com"
    AND protoPayload.@type="type.googleapis.com/google.cloud.audit.AuditLog"
  EOT

  description = "Audit log export to BigQuery for analytics"

  unique_writer_identity = true

  # Use partitioned tables for query efficiency
  bigquery_options {
    use_partitioned_tables = true
  }
}

# Grant BigQuery sink permission to write
resource "google_bigquery_dataset_iam_member" "sink_writer_bq" {
  count = var.create_bigquery_dataset ? 1 : 0

  dataset_id = google_bigquery_dataset.audit_analytics[0].dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.audit_sink_bq[0].writer_identity
}
