# Supabase Project Module Variables

# Required Variables

variable "organization_id" {
  description = "Supabase organization ID"
  type        = string
}

variable "project_name" {
  description = "Name of the Supabase project"
  type        = string

  validation {
    condition     = length(var.project_name) >= 3 && length(var.project_name) <= 63
    error_message = "Project name must be between 3 and 63 characters."
  }
}

variable "database_password" {
  description = "Database password (from Doppler, marked sensitive)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.database_password) >= 12
    error_message = "Database password must be at least 12 characters."
  }
}

# Optional Variables

variable "region" {
  description = "AWS region for Supabase project"
  type        = string
  default     = "us-west-1"

  validation {
    condition     = contains(["us-west-1", "us-east-1", "eu-west-1", "eu-central-1", "ap-southeast-1", "ap-northeast-1"], var.region)
    error_message = "Region must be a valid Supabase region."
  }
}

variable "tier" {
  description = "Supabase project tier (free, pro, team, enterprise)"
  type        = string
  default     = "free"

  validation {
    condition     = contains(["free", "pro", "team", "enterprise"], var.tier)
    error_message = "Tier must be one of: free, pro, team, enterprise."
  }
}

variable "site_url" {
  description = "Site URL for authentication redirects"
  type        = string
  default     = "http://localhost:3000"
}

variable "enable_signup" {
  description = "Enable user signups"
  type        = bool
  default     = true
}

variable "max_connections" {
  description = "Maximum database connections"
  type        = number
  default     = 100

  validation {
    condition     = var.max_connections >= 10 && var.max_connections <= 500
    error_message = "Max connections must be between 10 and 500."
  }
}

variable "file_size_limit_mb" {
  description = "File upload size limit in megabytes"
  type        = number
  default     = 50

  validation {
    condition     = var.file_size_limit_mb >= 1 && var.file_size_limit_mb <= 100
    error_message = "File size limit must be between 1 and 100 MB."
  }
}

variable "enable_backups" {
  description = "Enable automated daily backups (Pro tier required)"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 90
    error_message = "Backup retention must be between 1 and 90 days."
  }
}

variable "enable_pitr" {
  description = "Enable Point-in-Time Recovery (Pro tier required)"
  type        = bool
  default     = false
}

variable "doppler_token" {
  description = "Doppler token for secrets management (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "create_preview_branch" {
  description = "Create a preview branch for testing"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
