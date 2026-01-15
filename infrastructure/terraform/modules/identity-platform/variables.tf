# modules/identity-platform/variables.tf
#
# Variables for Identity Platform (HIPAA-compliant auth)

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

# -----------------------------------------------------------------------------
# Authentication Methods
# -----------------------------------------------------------------------------

variable "enable_email_password" {
  description = "Enable email/password authentication"
  type        = bool
  default     = true
}

variable "enable_email_link" {
  description = "Enable passwordless email link authentication"
  type        = bool
  default     = false
}

variable "enable_phone_auth" {
  description = "Enable phone number authentication"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Security Settings
# -----------------------------------------------------------------------------

variable "require_mfa" {
  description = "Require multi-factor authentication (recommended for HIPAA)"
  type        = bool
  default     = true
}

variable "mfa_enforcement" {
  description = "MFA enforcement level: DISABLED, ENABLED, MANDATORY"
  type        = string
  default     = "MANDATORY"

  validation {
    condition     = contains(["DISABLED", "ENABLED", "MANDATORY"], var.mfa_enforcement)
    error_message = "MFA enforcement must be DISABLED, ENABLED, or MANDATORY."
  }
}

variable "password_min_length" {
  description = "Minimum password length"
  type        = number
  default     = 12
}

variable "password_require_uppercase" {
  description = "Require uppercase letter in password"
  type        = bool
  default     = true
}

variable "password_require_lowercase" {
  description = "Require lowercase letter in password"
  type        = bool
  default     = true
}

variable "password_require_numeric" {
  description = "Require number in password"
  type        = bool
  default     = true
}

variable "password_require_symbol" {
  description = "Require special character in password"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Email Settings
# -----------------------------------------------------------------------------

variable "email_sender_name" {
  description = "Name shown in outbound emails"
  type        = string
  default     = "Clinical Diary Portal"
}

variable "email_reply_to" {
  description = "Reply-to email address"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Domain Configuration
# -----------------------------------------------------------------------------

variable "authorized_domains" {
  description = "List of authorized domains for OAuth redirects"
  type        = list(string)
  default     = []
}

variable "portal_url" {
  description = "Portal URL for email links and redirects"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Session Settings
# -----------------------------------------------------------------------------

variable "session_duration_minutes" {
  description = "Session duration in minutes (default: 60 for HIPAA compliance)"
  type        = number
  default     = 60
}

variable "refresh_token_rotation" {
  description = "Enable refresh token rotation for security"
  type        = bool
  default     = true
}
