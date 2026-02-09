# modules/billing-alert-funk/variables.tf
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00001: Automated cost-control billing alerts
#   REQ-o00056: IaC for portal deployment

# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_number" {
  description = "GCP Project number (for Pub/Sub service agent IAM)"
  type        = string
}

variable "region" {
  description = "GCP region for the Cloud Function"
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

variable "budget_alert_topic_id" {
  description = "Full resource ID of the Pub/Sub topic from the billing-budget module"
  type        = string
}

variable "function_source_dir" {
  description = "Path to the directory containing the function source code"
  type        = string
}

# -----------------------------------------------------------------------------
# Service Account
# -----------------------------------------------------------------------------

variable "create_service_account" {
  description = "Create a dedicated service account for the function. Set false to use an existing one via service_account_email."
  type        = bool
  default     = true
}

variable "service_account_email" {
  description = "Externally-managed service account email (only used when create_service_account = false)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Cloud Function
# -----------------------------------------------------------------------------

variable "slack_webhook_url" {
  description = "Slack webhook URL for budget alert notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "function_memory" {
  description = "Memory allocated to the function (e.g. 256M, 512M)"
  type        = string
  default     = "256M"
}

variable "function_timeout" {
  description = "Function execution timeout in seconds"
  type        = number
  default     = 60
}

# -----------------------------------------------------------------------------
# Pub/Sub Subscription
# -----------------------------------------------------------------------------

variable "ack_deadline_seconds" {
  description = "Acknowledgement deadline for the push subscription (seconds)"
  type        = number
  default     = 60
}

variable "message_retention" {
  description = "How long unacknowledged messages are retained (duration string)"
  type        = string
  default     = "604800s" # 7 days
}

variable "min_retry_backoff" {
  description = "Minimum backoff for subscription retry policy (duration string)"
  type        = string
  default     = "10s"
}

variable "max_retry_backoff" {
  description = "Maximum backoff for subscription retry policy (duration string)"
  type        = string
  default     = "600s"
}

# -----------------------------------------------------------------------------
# Dead-Letter
# -----------------------------------------------------------------------------

variable "enable_dead_letter" {
  description = "Create a dead-letter topic for messages that fail delivery"
  type        = bool
  default     = true
}

variable "max_delivery_attempts" {
  description = "Max delivery attempts before sending to dead-letter topic"
  type        = number
  default     = 5

  validation {
    condition     = var.max_delivery_attempts >= 5 && var.max_delivery_attempts <= 100
    error_message = "max_delivery_attempts must be between 5 and 100."
  }
}

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

variable "enable_logging_metric" {
  description = "Create a Cloud Logging metric that counts function errors"
  type        = bool
  default     = true
}

variable "enable_pubsub_audit_logs" {
  description = "Enable Pub/Sub data-access audit logs for message delivery visibility"
  type        = bool
  default     = false
}
