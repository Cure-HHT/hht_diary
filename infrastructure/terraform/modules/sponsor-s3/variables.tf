# Sponsor S3 Module Variables

variable "sponsor_name" {
  description = "Sponsor name (lowercase, e.g., 'callisto')"
  type        = string

  validation {
    condition     = can(regex("^[a-z]+$", var.sponsor_name))
    error_message = "Sponsor name must be lowercase letters only"
  }
}

variable "sponsor_code" {
  description = "3-letter sponsor code (uppercase, e.g., 'CAL')"
  type        = string

  validation {
    condition     = can(regex("^[A-Z]{3}$", var.sponsor_code))
    error_message = "Sponsor code must be exactly 3 uppercase letters"
  }
}

variable "aws_region" {
  description = "AWS region for bucket deployment"
  type        = string
}

variable "artifacts_bucket_name" {
  description = "Name for artifacts bucket (e.g., 'hht-diary-artifacts-callisto-eu-west-1')"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.artifacts_bucket_name))
    error_message = "Bucket name must be valid S3 bucket name (lowercase, hyphens, 3-63 chars)"
  }
}

variable "backups_bucket_name" {
  description = "Name for backups bucket (e.g., 'hht-diary-backups-callisto-eu-west-1')"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.backups_bucket_name))
    error_message = "Bucket name must be valid S3 bucket name (lowercase, hyphens, 3-63 chars)"
  }
}

variable "logs_bucket_name" {
  description = "Name for logs bucket (e.g., 'hht-diary-logs-callisto-eu-west-1')"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.logs_bucket_name))
    error_message = "Bucket name must be valid S3 bucket name (lowercase, hyphens, 3-63 chars)"
  }
}

variable "enable_object_lock" {
  description = "Enable S3 Object Lock (WORM) for compliance (requires new bucket)"
  type        = bool
  default     = false
}

variable "create_cicd_user" {
  description = "Create IAM user for CI/CD (use OIDC in production)"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "create_test_buckets" {
  description = "Create staging and development test buckets for archival testing"
  type        = bool
  default     = false
}

variable "staging_bucket_name" {
  description = "Name for staging test bucket (optional, for 30-day archival testing)"
  type        = string
  default     = ""
}

variable "dev_bucket_name" {
  description = "Name for development test bucket (optional, for 7-day archival testing)"
  type        = string
  default     = ""
}
