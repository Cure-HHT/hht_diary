# modules/cloud-build/outputs.tf

output "diary_server_trigger_id" {
  description = "Diary server Cloud Build trigger ID"
  value       = google_cloudbuild_trigger.diary_server.trigger_id
}

output "diary_server_trigger_name" {
  description = "Diary server Cloud Build trigger name"
  value       = google_cloudbuild_trigger.diary_server.name
}

output "portal_server_trigger_id" {
  description = "Portal server Cloud Build trigger ID"
  value       = google_cloudbuild_trigger.portal_server.trigger_id
}

output "portal_server_trigger_name" {
  description = "Portal server Cloud Build trigger name"
  value       = google_cloudbuild_trigger.portal_server.name
}
