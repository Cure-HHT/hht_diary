# modules/storage-buckets/variables.tf

variable "project_id" {
  description = "GCP Project ID"
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

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west9"
}

variable "project_prefix" {
  description = "Project prefix (for audit bucket naming)"
  type        = string
  default     = "cure-hht"
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 365
}

variable "create_app_data_bucket" {
  description = "Create application data bucket"
  type        = bool
  default     = true
}

variable "enable_cors" {
  description = "Enable CORS on app data bucket"
  type        = bool
  default     = false
}

variable "cors_origins" {
  description = "CORS allowed origins"
  type        = list(string)
  default     = ["*"]
}
