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
# Enable Required APIs
# -----------------------------------------------------------------------------

resource "google_project_service" "required_apis" {
  for_each = toset([
    "billingbudgets.googleapis.com",
    "pubsub.googleapis.com",
    "iam.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
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
  depends_on = [
    google_project_service.required_apis
  ]
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
  depends_on = [
    google_project_service.required_apis
  ]
}
