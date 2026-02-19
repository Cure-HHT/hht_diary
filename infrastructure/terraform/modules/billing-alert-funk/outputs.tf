# modules/billing-alert-funk/outputs.tf

output "function_name" {
  description = "The deployed Cloud Function name"
  value       = google_cloudfunctions2_function.budget_alert.name
}

output "function_uri" {
  description = "The URI of the Cloud Function"
  value       = google_cloudfunctions2_function.budget_alert.service_config[0].uri
}

output "function_service_account" {
  description = "Service account email used by the function"
  value       = local.service_account_email
}

output "subscription_name" {
  description = "The push subscription delivering messages to the function"
  value       = google_pubsub_subscription.budget_alert.name
}

output "dead_letter_topic" {
  description = "Dead-letter topic ID (null when disabled)"
  value       = var.enable_dead_letter ? google_pubsub_topic.dead_letter[0].id : null
}

output "source_bucket" {
  description = "GCS bucket storing the function source code"
  value       = google_storage_bucket.function_source.name
}
