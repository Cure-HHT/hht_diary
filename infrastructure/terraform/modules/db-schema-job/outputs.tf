# modules/db-schema-job/outputs.tf

output "job_name" {
  description = "Cloud Run Job name"
  value       = google_cloud_run_v2_job.schema_job.name
}

output "job_id" {
  description = "Cloud Run Job ID"
  value       = google_cloud_run_v2_job.schema_job.id
}

output "job_uri" {
  description = "Cloud Run Job URI"
  value       = google_cloud_run_v2_job.schema_job.uid
}

output "service_account_email" {
  description = "Service account email used by the job"
  value       = google_service_account.schema_job.email
}

output "schema_bucket_name" {
  description = "GCS bucket name for schema files"
  value       = var.create_schema_bucket ? google_storage_bucket.schema_files[0].name : var.schema_bucket_name
}

output "execute_command" {
  description = "Command to manually execute the schema job"
  value       = "gcloud run jobs execute ${google_cloud_run_v2_job.schema_job.name} --project=${var.project_id} --region=${var.region} --wait"
}

output "logs_command" {
  description = "Command to view job execution logs"
  value       = "gcloud logging read 'resource.type=cloud_run_job AND resource.labels.job_name=${google_cloud_run_v2_job.schema_job.name}' --project=${var.project_id} --limit=100"
}
