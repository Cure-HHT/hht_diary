# Staging Environment Variables

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
  description = "Database password (from Doppler)"
  type        = string
  sensitive   = true
}

variable "doppler_token" {
  description = "Doppler service token (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "site_url" {
  description = "Site URL for authentication"
  type        = string
  default     = "https://staging.clinical-diary.com"
}
