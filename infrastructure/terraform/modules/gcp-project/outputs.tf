# modules/gcp-project/outputs.tf

output "project_id" {
  description = "The GCP project ID"
  value       = google_project.main.project_id
}

output "project_number" {
  description = "The GCP project number"
  value       = google_project.main.number
}

output "project_name" {
  description = "The GCP project display name"
  value       = google_project.main.name
}

output "enabled_apis" {
  description = "List of enabled APIs"
  value       = [for api in google_project_service.apis : api.service]
}

# Dependency marker for other modules to wait on API enablement
output "apis_ready" {
  description = "Marker that APIs are enabled (use depends_on with this)"
  value       = true
  depends_on  = [google_project_service.apis]
}
