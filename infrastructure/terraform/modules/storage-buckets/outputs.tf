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
