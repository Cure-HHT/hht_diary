# modules/audit-logs/variables.tf

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_prefix" {
  description = "Prefix for resource names (e.g., 'cure-hht')"
  type        = string
  default     = "cure-hht"
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

variable "region" {
  description = "GCP region for the bucket"
  type        = string
  default     = "us-central1"
}

variable "retention_years" {
  description = "Audit log retention period in years (FDA requires 25)"
  type        = number
  default     = 25

  validation {
    condition     = var.retention_years >= 1 && var.retention_years <= 100
    error_message = "Retention years must be between 1 and 100."
  }
}

variable "lock_retention_policy" {
  description = "Lock the retention policy (CANNOT be undone - use only for prod)"
  type        = bool
  default     = false
}

variable "include_data_access_logs" {
  description = "Include data access logs (more verbose, higher cost)"
  type        = bool
  default     = true
}

variable "create_bigquery_dataset" {
  description = "Create BigQuery dataset for audit log analytics"
  type        = bool
  default     = true
}
