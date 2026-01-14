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
  # Set retention_years = 0 to disable retention (for non-prod environments)
  dynamic "retention_policy" {
    for_each = var.retention_years > 0 ? [1] : []
    content {
      retention_period = local.retention_seconds
      is_locked        = var.lock_retention_policy
    }
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

