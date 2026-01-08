# modules/workforce-identity/outputs.tf

output "enabled" {
  description = "Whether Workforce Identity is enabled"
  value       = var.enabled
}

output "pool_id" {
  description = "Workforce Identity Pool ID"
  value       = var.enabled ? google_iam_workforce_pool.main[0].workforce_pool_id : null
}

output "pool_name" {
  description = "Workforce Identity Pool full name"
  value       = var.enabled ? google_iam_workforce_pool.main[0].name : null
}

output "provider_id" {
  description = "Workforce Identity Provider ID"
  value = var.enabled ? (
    var.provider_type == "oidc"
    ? google_iam_workforce_pool_provider.oidc[0].provider_id
    : google_iam_workforce_pool_provider.saml[0].provider_id
  ) : null
}

output "provider_name" {
  description = "Workforce Identity Provider full name"
  value = var.enabled ? (
    var.provider_type == "oidc"
    ? google_iam_workforce_pool_provider.oidc[0].name
    : google_iam_workforce_pool_provider.saml[0].name
  ) : null
}

output "login_url" {
  description = "Login URL for workforce users"
  value = var.enabled ? (
    "https://auth.cloud.google/signin/${google_iam_workforce_pool.main[0].workforce_pool_id}?continueUrl=https://console.cloud.google.com"
  ) : null
}
