# modules/artifact-registry/outputs.tf

output "repository_id" {
  description = "Artifact Registry repository ID"
  value       = google_artifact_registry_repository.main.repository_id
}

output "repository_name" {
  description = "Artifact Registry repository name"
  value       = google_artifact_registry_repository.main.name
}

output "repository_url" {
  description = "Docker repository URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}"
}

output "diary_server_image_base" {
  description = "Base image path for diary-server"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}/diary-server"
}

output "portal_server_image_base" {
  description = "Base image path for portal-server"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}/portal-server"
}
