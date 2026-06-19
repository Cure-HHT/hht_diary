# modules/cloud-run/outputs.tf

output "diary_server_url" {
  description = "Diary server Cloud Run URL"
  value       = google_cloud_run_v2_service.diary_server.uri
}

output "diary_server_name" {
  description = "Diary server service name"
  value       = google_cloud_run_v2_service.diary_server.name
}

output "portal_server_url" {
  description = "Portal server Cloud Run URL"
  value       = google_cloud_run_v2_service.portal_server.uri
}

output "portal_server_name" {
  description = "Portal server service name"
  value       = google_cloud_run_v2_service.portal_server.name
}

output "service_account_email" {
  description = "Cloud Run service account email"
  value       = google_service_account.cloud_run.email
}

output "service_account_id" {
  description = "Cloud Run service account ID"
  value       = google_service_account.cloud_run.id
}
