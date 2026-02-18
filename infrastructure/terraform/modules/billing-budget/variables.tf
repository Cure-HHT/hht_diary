# modules/billing-budget/variables.tf

variable "billing_account_id" {
  description = "GCP Billing Account ID"
  type        = string

  validation {
    condition     = can(regex("^[A-Z0-9]{6}-[A-Z0-9]{6}-[A-Z0-9]{6}$", var.billing_account_id))
    error_message = "Billing account ID must be in format XXXXXX-XXXXXX-XXXXXX."
  }
}

variable "project_number" {
  description = "GCP Project number (not ID)"
  type        = string
}

variable "sponsor" {
  description = "Sponsor name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, qa, uat, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "qa", "uat", "prod"], var.environment)
    error_message = "Environment must be one of: dev, qa, uat, prod."
  }
}

variable "budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number

  validation {
    condition     = var.budget_amount > 0
    error_message = "Budget amount must be greater than 0."
  }
}

variable "alert_thresholds" {
  description = "List of threshold percentages to trigger alerts (0.0-1.0)"
  type        = list(number)
  default     = [0.5, 0.75, 0.9, 1.0]

  validation {
    condition     = alltrue([for t in var.alert_thresholds : t >= 0 && t <= 2.0])
    error_message = "Alert thresholds must be between 0.0 and 2.0."
  }
}

variable "notification_channels" {
  description = "List of notification channel IDs for budget alerts"
  type        = list(string)
  default     = []
}

variable "disable_default_notifications" {
  description = "Disable default notifications to billing account admins"
  type        = bool
  default     = false
}

variable "project_id" {
  description = "GCP Project ID (for Pub/Sub topic)"
  type        = string
}

variable "enable_cost_controls" {
  description = "Enable Pub/Sub topic for automated cost control actions"
  type        = bool
  default     = true
}

