# modules/svc-accts/outputs.tf
#
# Outputs from service account IAM bindings
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment

output "gmail_impersonation_member" {
  description = "The service account granted Gmail SA impersonation"
  value       = var.impersonating_service_account_email
}

output "gmail_service_account_email" {
  description = "The Gmail service account being impersonated"
  value       = var.gmail_service_account_email
}
