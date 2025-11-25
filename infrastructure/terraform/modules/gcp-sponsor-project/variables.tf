# IMPLEMENTS REQUIREMENTS:
#   REQ-o00041: Infrastructure as Code for Cloud Resources
#
# Variables for GCP Sponsor Project Module

# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------
variable "sponsor" {
  description = "Sponsor identifier (lowercase, no spaces)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.sponsor))
    error_message = "Sponsor must be lowercase alphanumeric with hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_id" {
  description = "GCP Project ID (format: hht-diary-{sponsor}-{env})"
  type        = string
}

variable "region" {
  description = "GCP region for resources (EU regions only for GDPR compliance)"
  type        = string
  default     = "europe-west1"

  validation {
    condition     = can(regex("^europe-", var.region))
    error_message = "Region must be an EU region (europe-*) for GDPR compliance."
  }
}

variable "db_app_password" {
  description = "Password for the application database user"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR range for the VPC subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "vpc_connector_cidr" {
  description = "CIDR range for the VPC Access Connector"
  type        = string
  default     = "10.8.0.0/28"
}

# -----------------------------------------------------------------------------
# Cloud SQL Configuration
# -----------------------------------------------------------------------------
variable "db_tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-custom-2-8192"

  validation {
    condition = can(regex("^db-", var.db_tier))
    error_message = "Database tier must start with 'db-'."
  }
}

variable "db_disk_size" {
  description = "Initial disk size in GB"
  type        = number
  default     = 100
}

variable "db_backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 30
}

# -----------------------------------------------------------------------------
# Storage Configuration
# -----------------------------------------------------------------------------
variable "backup_storage_retention_days" {
  description = "Days to retain backup exports in Cloud Storage"
  type        = number
  default     = 365
}

# -----------------------------------------------------------------------------
# Monitoring Configuration
# -----------------------------------------------------------------------------
variable "enable_monitoring_alerts" {
  description = "Enable monitoring alert policies"
  type        = bool
  default     = true
}

variable "notification_channels" {
  description = "List of notification channel IDs for alerts"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Labels
# -----------------------------------------------------------------------------
variable "labels" {
  description = "Additional labels to apply to resources"
  type        = map(string)
  default     = {}
}
