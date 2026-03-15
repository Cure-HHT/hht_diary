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

variable "enable_compute_sa_access" {
  description = "Whether to grant storage.objectUser to the compute service account"
  type        = bool
  default     = false
}

variable "compute_service_account_email" {
  description = "Compute service account email to grant storage.objectUser on buckets"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Schema File Upload Variables
# -----------------------------------------------------------------------------

variable "schema_prefix" {
  description = "GCS prefix (folder) for schema files"
  type        = string
  default     = "db-schema"
}

variable "schema_file_name" {
  description = "Name of the consolidated schema file in GCS"
  type        = string
  default     = "init-consolidated.sql"
}

variable "schema_file_source" {
  description = "Local path to the consolidated schema file (empty to skip upload)"
  type        = string
  default     = ""
}

variable "sponsor_data_file_name" {
  description = "Name of the sponsor data file in GCS"
  type        = string
  default     = ""
}

variable "sponsor_data_file_source" {
  description = "Local path to the sponsor data file (empty to skip upload)"
  type        = string
  default     = ""
}
