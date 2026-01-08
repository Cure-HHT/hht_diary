# modules/billing-budget/main.tf
#
# Creates a billing budget with threshold alerts
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
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

  # Optional notification channels
  dynamic "all_updates_rule" {
    for_each = length(var.notification_channels) > 0 ? [1] : []
    content {
      monitoring_notification_channels = var.notification_channels
      disable_default_iam_recipients   = var.disable_default_notifications
    }
  }
}
