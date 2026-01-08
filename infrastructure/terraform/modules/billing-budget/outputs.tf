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
