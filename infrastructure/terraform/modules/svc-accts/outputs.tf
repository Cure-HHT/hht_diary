# modules/svc-accts/outputs.tf
#
# Outputs from service account module
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment

output "gmail_service_account_email" {
  description = "The Gmail service account being impersonated"
  value       = var.gmail_service_account_email
}

# -----------------------------------------------------------------------------
# Compute Service Account
# -----------------------------------------------------------------------------

output "compute_service_account_email" {
  description = "Email of the compute service account for Cloud Run services"
  value       = google_service_account.compute.email
}
