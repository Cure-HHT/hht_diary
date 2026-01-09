# modules/billing-budget/main.tf
#
# Creates a billing budget with threshold alerts and optional cost controls
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#
# Cost control flow:
#   Budget exceeded → Pub/Sub topic → Cloud Function → Stop Cloud Run services
#
# This prevents runaway costs from misconfigured health checks, restart loops, etc.

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

locals {
  is_production = var.environment == "prod"
}

# -----------------------------------------------------------------------------
# Pub/Sub Topic for Cost Control Actions
# -----------------------------------------------------------------------------

resource "google_pubsub_topic" "budget_alerts" {
  count   = var.enable_cost_controls ? 1 : 0
  name    = "${var.sponsor}-${var.environment}-budget-alerts"
  project = var.project_id

  labels = {
    sponsor     = var.sponsor
    environment = var.environment
    purpose     = "budget-alerts"
  }
}

# -----------------------------------------------------------------------------
# Billing Budget
# -----------------------------------------------------------------------------

resource "google_billing_budget" "main" {
  billing_account = var.billing_account_id
  display_name    = "${var.sponsor}-${var.environment}-budget"

  budget_filter {
    projects               = ["projects/${var.project_number}"]
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.budget_amount)
    }
  }

  # Alert thresholds: 50%, 75%, 90%, 100%
  dynamic "threshold_rules" {
    for_each = var.alert_thresholds
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  # Forecasted overspend alert (warns before you hit budget)
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  # Send to Pub/Sub for automated actions (non-prod only by default)
  dynamic "all_updates_rule" {
    for_each = var.enable_cost_controls ? [1] : []
    content {
      pubsub_topic                     = google_pubsub_topic.budget_alerts[0].id
      monitoring_notification_channels = var.notification_channels
      disable_default_iam_recipients   = var.disable_default_notifications
      schema_version                   = "1.0"
    }
  }

  # Fallback: just notification channels if cost controls disabled
  dynamic "all_updates_rule" {
    for_each = !var.enable_cost_controls && length(var.notification_channels) > 0 ? [1] : []
    content {
      monitoring_notification_channels = var.notification_channels
      disable_default_iam_recipients   = var.disable_default_notifications
    }
  }
}

# -----------------------------------------------------------------------------
# Cloud Function to Stop Services (Non-Production Only)
# -----------------------------------------------------------------------------
#
# When budget threshold is exceeded, this function stops Cloud Run services
# to prevent further costs. Production environments should NOT auto-stop
# (use alerts and manual intervention instead).
#
# Note: This creates the infrastructure. The actual function code should be
# deployed via CI/CD. See tools/cost-control/ for the function source.

resource "google_service_account" "cost_control" {
  count        = var.enable_cost_controls && !local.is_production ? 1 : 0
  account_id   = "${var.sponsor}-${var.environment}-cost-ctrl"
  display_name = "Cost Control Function - ${var.sponsor} ${var.environment}"
  project      = var.project_id
}

# Allow the function to stop Cloud Run services
resource "google_project_iam_member" "cost_control_run_admin" {
  count   = var.enable_cost_controls && !local.is_production ? 1 : 0
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.cost_control[0].email}"
}

# Allow the function to be invoked by Pub/Sub
resource "google_project_iam_member" "cost_control_invoker" {
  count   = var.enable_cost_controls && !local.is_production ? 1 : 0
  project = var.project_id
  role    = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_service_account.cost_control[0].email}"
}

# Pub/Sub subscription for the cost control function
resource "google_pubsub_subscription" "cost_control" {
  count   = var.enable_cost_controls && !local.is_production ? 1 : 0
  name    = "${var.sponsor}-${var.environment}-cost-control-sub"
  topic   = google_pubsub_topic.budget_alerts[0].name
  project = var.project_id

  # Filter to only trigger on actual overspend, not forecasts
  filter = "attributes.costIntervalStart != \"\""

  ack_deadline_seconds = 60

  labels = {
    sponsor     = var.sponsor
    environment = var.environment
    purpose     = "cost-control"
  }
}
