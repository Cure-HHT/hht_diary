# modules/db-schema-job/variables.tf

# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

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
}

variable "db_connection_name" {
  description = "Cloud SQL instance connection name (project:region:instance)"
  type        = string
}

variable "database_name" {
  description = "Database name to apply schema to"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "vpc_connector_id" {
  description = "VPC Access Connector ID for Cloud Run"
  type        = string
}

# -----------------------------------------------------------------------------
# Password Configuration (one of these is required)
# -----------------------------------------------------------------------------

variable "db_password_secret_id" {
  description = "Secret Manager secret ID containing DB password (preferred)"
  type        = string
  default     = ""
}

variable "db_password" {
  description = "Database password (use only if not using Secret Manager)"
  type        = string
  sensitive   = true
  default     = ""
}

# -----------------------------------------------------------------------------
# Schema File Configuration
# -----------------------------------------------------------------------------

variable "create_schema_bucket" {
  description = "Create a GCS bucket for schema files"
  type        = bool
  default     = true
}

variable "schema_bucket_name" {
  description = "Existing GCS bucket name for schema files (if not creating new)"
  type        = string
  default     = ""
}

variable "schema_file_content" {
  description = "Content of the schema SQL file"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Job Configuration
# -----------------------------------------------------------------------------

variable "schema_job_image" {
  description = "Container image for schema job"
  type        = string
  default     = "europe-west9-docker.pkg.dev/anspar-admin/shared-images/db-schema-job:latest"
}

variable "auto_execute" {
  description = "Automatically execute job when schema changes"
  type        = bool
  default     = false
}
