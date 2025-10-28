# Production Environment Variables

variable "supabase_access_token" {
  description = "Supabase access token (from Doppler)"
  type        = string
  sensitive   = true
}

variable "supabase_organization_id" {
  description = "Supabase organization ID"
  type        = string
  # Get from: https://app.supabase.com/account/organization
}

variable "database_password" {
  description = "Database password (from Doppler, minimum 16 characters for production)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.database_password) >= 16
    error_message = "Production database password must be at least 16 characters."
  }
}

variable "doppler_token" {
  description = "Doppler service token (required for production)"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "site_url" {
  description = "Production site URL for authentication"
  type        = string
  default     = "https://clinical-diary.com"
}

variable "enable_signup" {
  description = "Enable user signups (set false if invitation-only)"
  type        = bool
  default     = true
}
