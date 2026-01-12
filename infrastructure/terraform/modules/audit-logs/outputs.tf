# modules/audit-logs/outputs.tf

output "bucket_name" {
  description = "The audit log bucket name"
  value       = google_storage_bucket.audit_logs.name
}

output "bucket_url" {
  description = "The audit log bucket URL"
  value       = google_storage_bucket.audit_logs.url
}

output "bucket_self_link" {
  description = "The audit log bucket self link"
  value       = google_storage_bucket.audit_logs.self_link
}

output "sink_name" {
  description = "The log sink name"
  value       = google_logging_project_sink.audit_sink.name
}

output "sink_writer_identity" {
  description = "The log sink writer identity"
  value       = google_logging_project_sink.audit_sink.writer_identity
}

output "retention_years" {
  description = "Configured retention period in years"
  value       = var.retention_years
}

output "retention_locked" {
  description = "Whether the retention policy is locked"
  value       = var.lock_retention_policy
}

output "compliance_status" {
  description = "FDA compliance status summary"
  value = {
    retention_years      = var.retention_years
    retention_locked     = var.lock_retention_policy
    versioning_enabled   = true
    lifecycle_rules      = ["90d->COLDLINE", "365d->ARCHIVE"]
    fda_compliant        = var.retention_years >= 25
    production_ready     = var.retention_years >= 25 && var.lock_retention_policy
  }
}
