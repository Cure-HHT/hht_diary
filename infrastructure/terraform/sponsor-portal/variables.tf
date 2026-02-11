# sponsor-portal/variables.tf
#
# Input variables for sponsor portal deployment
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00008: Multi-sponsor deployment model

# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "sponsor" {
  description = "Sponsor name"
  type        = string
}

variable "sponsor_id" {
  description = "Unique sponsor ID for VPC CIDR allocation (1-254)"
  type        = number

  validation {
    condition     = var.sponsor_id >= 1 && var.sponsor_id <= 254
    error_message = "Sponsor ID must be between 1 and 254."
  }
}

variable "environment" {
  description = "Environment name (dev, qa, uat, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "qa", "uat", "prod"], var.environment)
    error_message = "Environment must be one of: dev, qa, uat, prod."
  }
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "GCP_ORG_ID" {
  description = "GCP Organization ID (for Workforce Identity)"
  type        = string
}

variable "DB_PASSWORD" {
  description = "Database password"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Optional: Region Configuration
# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------
# Optional: Cloud Run Configuration
# -----------------------------------------------------------------------------

variable "min_instances" {
  description = "Minimum Cloud Run instances"
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "Maximum Cloud Run instances"
  type        = number
  default     = 10
}

variable "container_memory" {
  description = "Container memory (e.g., '512Mi' or '1Gi')"
  type        = string
  default     = "512Mi"
}

variable "container_cpu" {
  description = "Container CPU (e.g., '1' or '2')"
  type        = string
  default     = "1"
}

variable "allow_public_access" {
  description = "Allow unauthenticated public access to Cloud Run services"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Optional: VPC Configuration Override
# These are calculated from sponsor_id by default
# -----------------------------------------------------------------------------

variable "vpc_connector_min_instances" {
  description = "VPC connector minimum instances (0 = use environment default)"
  type        = number
  default     = 0
}

variable "vpc_connector_max_instances" {
  description = "VPC connector maximum instances (0 = use environment default)"
  type        = number
  default     = 0
}

# -----------------------------------------------------------------------------
# Optional: CI/CD Configuration
# -----------------------------------------------------------------------------

variable "cicd_service_account" {
  description = "CI/CD service account email (for Artifact Registry access)"
  type        = string
  default     = ""
}

variable "github_org" {
  description = "GitHub organization for Cloud Build triggers"
  type        = string
  default     = "Cure-HHT"
}

variable "github_repo" {
  description = "GitHub repository for Cloud Build triggers"
  type        = string
  default     = "hht_diary"
}

variable "enable_cloud_build_triggers" {
  description = "[DEPRECATED] Create Cloud Build triggers for CI/CD. Use GitHub Actions instead."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Optional: Cross-Project Gmail SA Impersonation
# -----------------------------------------------------------------------------

variable "admin_project_id" {
  description = "GCP project ID of the admin project (for cross-project Gmail SA impersonation)"
  type        = string
  default     = "cure-hht-admin"
}

variable "gmail_service_account_email" {
  description = "Email of the org-wide Gmail service account in the admin project"
  type        = string
  default     = "org-gmail-sender@cure-hht-admin.iam.gserviceaccount.com"
}

variable "impersonating_service_account_email" {
  description = "Email of this sponsor's service account that needs Gmail SA impersonation (empty = skip)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Optional: Container Images (via Artifact Registry GHCR proxy)
# -----------------------------------------------------------------------------

variable "diary_server_image" {
  description = "Container image URL for diary server (via Artifact Registry GHCR proxy)"
  type        = string
  default     = "europe-west9-docker.pkg.dev/cure-hht-admin/ghcr-remote/cure-hht/clinical-diary-diary-server:latest"
}

variable "portal_server_image" {
  description = "Container image URL for portal server (via Artifact Registry GHCR proxy)"
  type        = string
  default     = "europe-west9-docker.pkg.dev/cure-hht-admin/ghcr-remote/cure-hht/clinical-diary-portal-server:latest"
}

# -----------------------------------------------------------------------------
# Optional: Identity Platform Configuration (HIPAA/GDPR-compliant auth)
# -----------------------------------------------------------------------------

variable "enable_identity_platform" {
  description = "Enable Identity Platform for user authentication"
  type        = bool
  default     = true
}

variable "identity_platform_email_password" {
  description = "Enable email/password authentication"
  type        = bool
  default     = true
}

variable "identity_platform_email_link" {
  description = "Enable passwordless email link authentication"
  type        = bool
  default     = false
}

variable "identity_platform_phone_auth" {
  description = "Enable phone number authentication"
  type        = bool
  default     = false
}

variable "identity_platform_mfa_enforcement" {
  description = "MFA enforcement level: DISABLED, ENABLED, MANDATORY (prod always MANDATORY)"
  type        = string
  default     = "MANDATORY"

  validation {
    condition     = contains(["DISABLED", "ENABLED", "MANDATORY"], var.identity_platform_mfa_enforcement)
    error_message = "MFA enforcement must be DISABLED, ENABLED, or MANDATORY."
  }
}

variable "identity_platform_password_min_length" {
  description = "Minimum password length (HIPAA recommends 12+)"
  type        = number
  default     = 12
}

variable "identity_platform_email_sender_name" {
  description = "Name shown in outbound authentication emails"
  type        = string
  default     = "Clinical Diary Portal"
}

variable "identity_platform_email_reply_to" {
  description = "Reply-to email address for authentication emails"
  type        = string
  default     = ""
}

variable "identity_platform_authorized_domains" {
  description = "Additional authorized domains for OAuth redirects"
  type        = list(string)
  default     = []
}

variable "identity_platform_session_duration" {
  description = "Session duration in minutes (HIPAA recommends 60 or less)"
  type        = number
  default     = 60
}

variable "diary_server_url" {
  description = "A web-service URL for Identity Platform OAuth configuration"
  type        = string
  default     = ""
}

variable "portal_server_url" {
  description = "A web-app URL for Identity Platform OAuth configuration"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Optional: Workforce Identity Configuration (for external IdP federation)
# -----------------------------------------------------------------------------

variable "workforce_identity_enabled" {
  description = "Enable Workforce Identity Federation"
  type        = bool
  default     = false
}

variable "workforce_identity_provider_type" {
  description = "Identity provider type (oidc or saml)"
  type        = string
  default     = "oidc"
}

variable "workforce_identity_issuer_uri" {
  description = "OIDC issuer URI"
  type        = string
  default     = ""
}

variable "workforce_identity_client_id" {
  description = "OIDC client ID"
  type        = string
  default     = ""
}

variable "workforce_identity_client_secret" {
  description = "OIDC client secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "workforce_identity_allowed_domain" {
  description = "Only allow users with email from this domain"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Optional: Audit Configuration
# -----------------------------------------------------------------------------

variable "audit_retention_years" {
  description = "Audit log retention in years (FDA requires 25)"
  type        = number
  default     = 25
}

# Note: lock_retention_policy is automatically set based on environment
# (true for prod, false for others)

# -----------------------------------------------------------------------------
# Optional: Monitoring
# -----------------------------------------------------------------------------

variable "notification_channels" {
  description = "Notification channel IDs for alerts"
  type        = list(string)
  default     = []
}
