# modules/storage-buckets/outputs.tf

output "backup_bucket_name" {
  description = "Backup bucket name"
  value       = google_storage_bucket.backups.name
}

output "backup_bucket_url" {
  description = "Backup bucket URL"
  value       = google_storage_bucket.backups.url
}

output "app_data_bucket_name" {
  description = "Application data bucket name (if created)"
  value       = var.create_app_data_bucket ? google_storage_bucket.app_data[0].name : null
}

output "app_data_bucket_url" {
  description = "Application data bucket URL (if created)"
  value       = var.create_app_data_bucket ? google_storage_bucket.app_data[0].url : null
}

# -----------------------------------------------------------------------------
# Schema File Outputs
# -----------------------------------------------------------------------------

output "schema_file_gcs_uri" {
  description = "GCS URI for the consolidated schema file"
  value       = var.create_app_data_bucket && var.schema_file_source != "" ? "gs://${google_storage_bucket.app_data[0].name}/${var.schema_prefix}/${var.schema_file_name}" : null
}

output "sponsor_data_file_gcs_uri" {
  description = "GCS URI for the sponsor data file"
  value       = var.create_app_data_bucket && var.sponsor_data_file_source != "" ? "gs://${google_storage_bucket.app_data[0].name}/${var.schema_prefix}/${var.sponsor_data_file_name}" : null
}

output "schema_bucket_name" {
  description = "Bucket name containing schema files (alias for app_data_bucket_name)"
  value       = var.create_app_data_bucket ? google_storage_bucket.app_data[0].name : null
}
