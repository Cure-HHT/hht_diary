# sponsor-envs/variables.tf
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

variable "project_number" {
  description = "GCP Project number (numeric, for service agent IAM bindings)"
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

variable "DOPPLER_TOKEN" {
  description = "Doppler service token for runtime secret access"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Required: Database Configuration
# -----------------------------------------------------------------------------

variable "database_name" {
  description = "Base name of the database to create (combined as sponsor_env_name)"
  type        = string
  default     = "db"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "app_user"
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

# -----------------------------------------------------------------------------
# Optional: Cloud Functions (Budget Alert)
# -----------------------------------------------------------------------------

variable "slack_webhook_devops_url" {
  description = "Slack webhook URL for budget alert notifications (use Doppler: TF_VAR_slack_webhook_devops_url)"
  type        = string
  default     = "https://anspar.slack.com/archives/C0A494UM1C2"
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Optional: Billing Alert Function (automated cost control)
# -----------------------------------------------------------------------------

variable "enable_cost_controls" {
  description = "Enable automated cost controls (Cloud Function to stop services when budget exceeded). Only affects non-prod - prod will alert but not auto-stop."
  type        = bool
  default     = false
}


variable "threshold_cutoff" {
  description = "Fraction of budget at which billing is disabled (e.g. 0.50 = 50%)"
  type        = number
  default     = 0.50

  validation {
    condition     = var.threshold_cutoff > 0 && var.threshold_cutoff <= 1.0
    error_message = "threshold_cutoff must be between 0 (exclusive) and 1.0 (inclusive)."
  }
}

variable "SLACK_INCIDENT_WEBHOOK_URL" {
  description = "Slack webhook URL for billing alert notifications (from Doppler: TF_VAR_SLACK_INCIDENT_WEBHOOK_URL)"
  type        = string
  default     = ""
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Optional: GitHub Actions Service Account (Cross-Project Deployment)
# -----------------------------------------------------------------------------

variable "github_actions_sa" {
  description = "GitHub Actions service account email from admin project (for cross-project Cloud Run deployments)"
  type        = string
  default     = ""
}

variable "compute_service_account" {
  description = "Compute Engine default service account email (for Secret Manager access)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Optional: Gmail API for Email Sending
# -----------------------------------------------------------------------------

variable "enable_gmail_api" {
  description = "Enable Gmail API and create cloud-run-mailer service account for email sending"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Optional: Regional Load Balancer Configuration
# -----------------------------------------------------------------------------

variable "enable_regional_lb" {
  description = "Enable Regional External HTTPS Load Balancer"
  type        = bool
  default     = false
}

variable "lb_domain" {
  description = "Domain name for the load balancer SSL certificate (e.g., portal.sponsor.example.com)"
  type        = string
  default     = ""
}

# Note: lb_proxy_only_subnet_cidr is now derived from bootstrap outputs.
# The proxy-only subnet is created by the vpc-network module in bootstrap.

variable "lb_backend_timeout_sec" {
  description = "Backend service timeout in seconds"
  type        = number
  default     = 30
}

variable "lb_enable_logging" {
  description = "Enable logging for the load balancer backend service"
  type        = bool
  default     = true
}

variable "lb_log_sample_rate" {
  description = "Sampling rate for load balancer logs (0.0 to 1.0)"
  type        = number
  default     = 1.0
}

variable "lb_enable_http_redirect" {
  description = "Create HTTP to HTTPS redirect forwarding rule"
  type        = bool
  default     = true
}

variable "lb_cloud_run_service_name" {
  description = "Name of the Cloud Run service to route traffic to (e.g., 'portal-server')"
  type        = string
  default     = ""
}
