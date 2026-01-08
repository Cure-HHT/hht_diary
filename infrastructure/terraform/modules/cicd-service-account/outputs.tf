# modules/cicd-service-account/outputs.tf

output "service_account_email" {
  description = "The CI/CD service account email"
  value       = google_service_account.cicd.email
}

output "service_account_id" {
  description = "The CI/CD service account ID"
  value       = google_service_account.cicd.id
}

output "service_account_name" {
  description = "The CI/CD service account name"
  value       = google_service_account.cicd.name
}

output "workload_identity_pool_id" {
  description = "The Workload Identity Pool ID (if enabled)"
  value       = var.enable_workload_identity ? google_iam_workload_identity_pool.github[0].workload_identity_pool_id : null
}

output "workload_identity_pool_name" {
  description = "The Workload Identity Pool full name (if enabled)"
  value       = var.enable_workload_identity ? google_iam_workload_identity_pool.github[0].name : null
}

output "workload_identity_provider" {
  description = "The Workload Identity Provider ID (if enabled)"
  value       = var.enable_workload_identity ? google_iam_workload_identity_pool_provider.github[0].name : null
}

# Full provider path for GitHub Actions workflow
output "github_actions_provider" {
  description = "Full provider path for GitHub Actions (use in workflow)"
  value = var.enable_workload_identity ? (
    "projects/${var.host_project_id}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github[0].workload_identity_pool_id}/providers/github-provider"
  ) : null
}

# Example GitHub Actions workflow configuration
output "github_actions_config" {
  description = "Configuration values for GitHub Actions workflow"
  value = var.enable_workload_identity ? {
    workload_identity_provider = "projects/${var.host_project_id}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github[0].workload_identity_pool_id}/providers/github-provider"
    service_account            = google_service_account.cicd.email
  } : null
}
