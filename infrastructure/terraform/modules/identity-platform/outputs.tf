# modules/identity-platform/outputs.tf
#
# Outputs for Identity Platform module

output "identity_platform_enabled" {
  description = "Whether Identity Platform is enabled"
  value       = true
}

output "authorized_domains" {
  description = "List of authorized domains for OAuth"
  value       = local.all_authorized_domains
}

output "mfa_state" {
  description = "MFA enforcement state (OFF, OPTIONAL, MANDATORY)"
  value       = local.is_production ? "MANDATORY" : var.mfa_enforcement
}

output "auth_methods" {
  description = "Enabled authentication methods"
  value = {
    email_password = var.enable_email_password
    email_link     = var.enable_email_link
    phone          = var.enable_phone_auth
  }
}

output "project_number" {
  description = "GCP project number (needed for some Identity Platform operations)"
  value       = data.google_project.current.number
}

output "api_key_instructions" {
  description = "Instructions for creating API key for client SDK"
  value       = <<-EOT
    To use Identity Platform in your app, create an API key:
    1. Go to APIs & Services > Credentials in GCP Console
    2. Create API Key with Identity Toolkit API restriction
    3. Add authorized domains to the key

    Or use gcloud:
    gcloud services api-keys create --display-name="Identity Platform" \
      --api-target=service=identitytoolkit.googleapis.com \
      --project=${var.project_id}
  EOT
}
