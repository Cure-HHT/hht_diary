# modules/cloud-sql/variables.tf

variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "callisto4-dev"
}

variable "sponsor" {
  description = "Sponsor name"
  type        = string
  default     = "callisto4"
}

variable "environment" {
  description = "Environment name (dev, qa, uat, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "qa", "uat", "prod"], var.environment)
    error_message = "Environment must be one of: dev, qa, uat, prod."
  }
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west9"
}

variable "vpc_network_id" {
  description = "VPC network ID for private IP"
  type        = string
  default     = "projects/callisto4-dev/global/networks/callisto4-dev-vpc"
}

variable "private_vpc_connection" {
  description = "Private VPC connection resource (for depends_on)"
  type        = string
  default     = "projects/callisto4-dev/locations/europe-west9/connectors/callisto4-dev-vpc-con"
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "callisto4_dev_db"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "app_user"
}

variable "DB_PASSWORD" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_tier" {
  description = "Cloud SQL instance tier (leave empty for environment defaults)"
  type        = string
  default     = ""
}

variable "edition" {
  description = "PostgreSQL edition (leave empty for environment defaults)"
  type        = string
  default     = ""
}

variable "disk_size" {
  description = "Initial disk size in GB (0 = use environment default)"
  type        = number
  default     = 0
}

# -----------------------------------------------------------------------------
# Backup Configuration
# IMPLEMENTS REQUIREMENTS:
#   REQ-p00047: Data Backup and Archival
#   REQ-o00008: Backup and Retention Policy
# -----------------------------------------------------------------------------

variable "backup_start_time" {
  description = "HH:MM time (UTC) when daily backup starts"
  type        = string
  default     = "02:00"

  validation {
    condition     = can(regex("^([01]\\d|2[0-3]):[0-5]\\d$", var.backup_start_time))
    error_message = "backup_start_time must be in HH:MM format (24-hour UTC)."
  }
}

variable "transaction_log_retention_days" {
  description = "Days to retain transaction logs for PITR (1-7)"
  type        = number
  default     = 7

  validation {
    condition     = var.transaction_log_retention_days >= 1 && var.transaction_log_retention_days <= 7
    error_message = "transaction_log_retention_days must be between 1 and 7."
  }
}

variable "backup_retention_override" {
  description = "Override number of retained backups (0 = use environment default: prod=30, uat=14, dev/qa=7)"
  type        = number
  default     = 0

  validation {
    condition     = var.backup_retention_override >= 0 && var.backup_retention_override <= 365
    error_message = "backup_retention_override must be between 0 and 365."
  }
}

# -----------------------------------------------------------------------------
# Maintenance Window
# -----------------------------------------------------------------------------

variable "maintenance_window_day" {
  description = "Day of week for maintenance (1=Mon .. 7=Sun)"
  type        = number
  default     = 7

  validation {
    condition     = var.maintenance_window_day >= 1 && var.maintenance_window_day <= 7
    error_message = "maintenance_window_day must be between 1 (Monday) and 7 (Sunday)."
  }
}

variable "maintenance_window_hour" {
  description = "Hour (UTC) for maintenance window. Default 5 = 6 AM CET"
  type        = number
  default     = 5

  validation {
    condition     = var.maintenance_window_hour >= 0 && var.maintenance_window_hour <= 23
    error_message = "maintenance_window_hour must be between 0 and 23."
  }
}

# -----------------------------------------------------------------------------
# Disk Auto-resize
# -----------------------------------------------------------------------------

variable "disk_autoresize_limit_override" {
  description = "Override disk auto-resize limit in GB (0 = use environment default: prod=500, uat=100, dev/qa=50)"
  type        = number
  default     = 0

  validation {
    condition     = var.disk_autoresize_limit_override >= 0
    error_message = "disk_autoresize_limit_override must be >= 0."
  }
}
