# modules/billing-budget/outputs.tf

output "budget_id" {
  description = "The billing budget ID"
  value       = google_billing_budget.main.id
}

output "budget_name" {
  description = "The billing budget display name"
  value       = google_billing_budget.main.display_name
}

output "budget_amount" {
  description = "The budget amount in USD"
  value       = var.budget_amount
}

output "budget_alert_topic" {
  description = "Pub/Sub topic for budget alerts (for automated cost control)"
  value       = var.enable_cost_controls ? google_pubsub_topic.budget_alerts[0].id : null
}

output "cost_control_service_account" {
  description = "Service account for cost control function (non-prod only)"
  value       = var.enable_cost_controls && var.environment != "prod" ? google_service_account.cost_control[0].email : null
}

output "cost_controls_enabled" {
  description = "Whether automated cost controls are enabled"
  value       = var.enable_cost_controls && var.environment != "prod"
}
