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
# Required: Billing Configuration (from Doppler)
# -----------------------------------------------------------------------------

variable "BILLING_ACCOUNT_PROD" {
  description = "Billing account ID for production (from Doppler: TF_VAR_BILLING_ACCOUNT_PROD)"
  type        = string

  validation {
    condition     = can(regex("^[A-Z0-9]{6}-[A-Z0-9]{6}-[A-Z0-9]{6}$", var.BILLING_ACCOUNT_PROD))
    error_message = "Billing account ID must be in format XXXXXX-XXXXXX-XXXXXX."
  }
}

variable "BILLING_ACCOUNT_DEV" {
  description = "Billing account ID for dev/qa/uat (from Doppler: TF_VAR_BILLING_ACCOUNT_DEV)"
  type        = string

  validation {
    condition     = can(regex("^[A-Z0-9]{6}-[A-Z0-9]{6}-[A-Z0-9]{6}$", var.BILLING_ACCOUNT_DEV))
    error_message = "Billing account ID must be in format XXXXXX-XXXXXX-XXXXXX."
  }
}

variable "budget_amount" {
  description = "Monthly budget amount in USD for this environment"
  type        = number
  default     = 500

  validation {
    condition     = var.budget_amount > 0
    error_message = "Budget amount must be greater than 0."
  }
}

# -----------------------------------------------------------------------------
# Required: Database Configuration
# -----------------------------------------------------------------------------

variable "database_name" {
  description = "Name of the database to create"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "app_user"
}

# -----------------------------------------------------------------------------
# Cloud SQL Configuration
# -----------------------------------------------------------------------------

variable "disk_size" {
  description = "Initial disk size in GB (0 = use environment default)"
  type        = number
  default     = 0
}

variable "backup_start_time" {
  description = "HH:MM time (UTC) when daily backup starts"
  type        = string
  default     = "02:00"

  validation {
    condition     = can(regex("^([01]\\d|2[0-3]):[0-5]\\d$", var.backup_start_time))
    error_message = "backup_start_time must be in HH:MM format (24-hour UTC)."
  }
}

variable "transaction_log_retention_days" {
  description = "Days to retain transaction logs for PITR (1-7)"
  type        = number
  default     = 7

  validation {
    condition     = var.transaction_log_retention_days >= 1 && var.transaction_log_retention_days <= 7
    error_message = "transaction_log_retention_days must be between 1 and 7."
  }
}

variable "backup_retention_override" {
  description = "Override number of retained backups (0 = use environment default: prod=30, uat=14, dev/qa=7)"
  type        = number
  default     = 0

  validation {
    condition     = var.backup_retention_override >= 0 && var.backup_retention_override <= 365
    error_message = "backup_retention_override must be between 0 and 365."
  }
}

variable "disk_autoresize_limit_override" {
  description = "Override disk auto-resize limit in GB (0 = use environment default: prod=500, uat=100, dev/qa=50)"
  type        = number
  default     = 0

  validation {
    condition     = var.disk_autoresize_limit_override >= 0
    error_message = "disk_autoresize_limit_override must be >= 0."
  }
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
# Optional: VPC Configuration
# -----------------------------------------------------------------------------

variable "enable_proxy_only_subnet" {
  description = "Enable proxy-only subnet for Regional Load Balancer"
  type        = bool
  default     = false
}

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

variable "include_data_access_logs" {
  description = "Include data access logs in audit exports (more verbose, higher cost)"
  type        = bool
  default     = true
}

variable "lock_audit_retention" {
  description = "Lock audit log retention policy (IRREVERSIBLE). Set true for prod when ready."
  type        = bool
  default     = false
}

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

# Note: The proxy-only subnet is created by module.network in this root module.
# Set enable_proxy_only_subnet=true when using the Regional Load Balancer.

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

variable "lb_cloud_run_services" {
  description = "Map of Cloud Run service configurations for host-based routing. Key is the Cloud Run service name, value has 'hosts' (list of hostname patterns). Example: { \"diary-server\" = { hosts = [\"diary.example.com\"] } }"
  type = map(object({
    hosts = list(string)
  }))
  default = {}
}

variable "lb_default_cloud_run_service" {
  description = "Cloud Run service name to use as the URL map default backend. Must be a key in lb_cloud_run_services. If empty, the alphabetically first service is used."
  type        = string
  default     = ""
}
