# example-dev.tfvars
#
# Example sponsor-envs configuration for dev environment
# Copy and customize for each sponsor/environment:
#   cp example-dev.tfvars {sponsor}-{env}.tfvars

# -----------------------------------------------------------------------------
# Required: Sponsor Identity
# -----------------------------------------------------------------------------

sponsor     = "callisto4"
sponsor_id  = 4 # Must match bootstrap sponsor_id
environment = "prod"

# -----------------------------------------------------------------------------
# Required: GCP Configuration
# -----------------------------------------------------------------------------

project_id     = "callisto4-prod" # From bootstrap output
project_number = "163292813995"

# Sensitive values should be provided via Doppler environment variables:
# - TF_VAR_GCP_ORG_ID
# - TF_VAR_BILLING_ACCOUNT_PROD
# - TF_VAR_BILLING_ACCOUNT_DEV
# - TF_VAR_DB_PASSWORD
# - TF_VAR_DOPPLER_TOKEN
# - TF_VAR_SLACK_INCIDENT_WEBHOOK_URL
#
# Find your GCP Organization ID: gcloud organizations list
# Find your Billing Account IDs: gcloud billing accounts list
#
# If not using Doppler, uncomment and set these values:
# GCP_ORG_ID = "123456789012"
# BILLING_ACCOUNT_PROD = "XXXXXX-XXXXXX-XXXXXX"
# BILLING_ACCOUNT_DEV = "XXXXXX-XXXXXX-XXXXXX"
# DB_PASSWORD = "your-db-password"

# -----------------------------------------------------------------------------
# Required: Database
# -----------------------------------------------------------------------------

database_name = "callisto4_prod_db"
db_username   = "app_user"

# Database password - use Doppler or set via environment variable

# -----------------------------------------------------------------------------
# Cloud SQL Configuration
# -----------------------------------------------------------------------------

disk_size                       = 0      # 0 = use environment default
backup_start_time               = "02:00"
transaction_log_retention_days  = 7
backup_retention_override       = 30      # 0 = use environment default (prod=30)
disk_autoresize_limit_override  = 500      # 0 = use environment default (prod=500)

# -----------------------------------------------------------------------------
# Optional: Project Configuration
# -----------------------------------------------------------------------------

region         = "europe-west9"
project_prefix = "cure-hht"

# -----------------------------------------------------------------------------
# Optional: Cloud Run Sizing
# -----------------------------------------------------------------------------

min_instances    = 0
max_instances    = 2
container_memory = "2Gi"
container_cpu    = "2"

# -----------------------------------------------------------------------------
# Optional: CI/CD Configuration
# -----------------------------------------------------------------------------

# CI/CD service account email (from bootstrap output)
# cicd_service_account = "example-cicd@cure-hht-example-dev.iam.gserviceaccount.com"

github_org  = "Cure-HHT"
github_repo = "hht_diary"

# Enable Cloud Build triggers (DEPRECATED - use GitHub Actions)
enable_cloud_build_triggers = false

# Container Images (via Artifact Registry GHCR proxy in admin project)
diary_server_image  = "europe-west9-docker.pkg.dev/cure-hht-admin/ghcr-remote/cure-hht/diary-server:latest"
portal_server_image = "europe-west9-docker.pkg.dev/cure-hht-admin/ghcr-remote/cure-hht/portal-server:latest"

# Enable Cloud Run services (diary-server, portal-server)
enable_cloud_run = false

# Allow unauthenticated access (app handles its own authentication)
allow_public_access = true

# -----------------------------------------------------------------------------
# Optional: Identity Platform (HIPAA/GDPR-compliant authentication)
# For portal users (investigators, admins)
# -----------------------------------------------------------------------------

enable_identity_platform = true

# Authentication methods
identity_platform_email_password = true  # Email/password login
identity_platform_email_link     = false # Passwordless email links
identity_platform_phone_auth     = false # Phone number authentication

# Security settings
# MFA: DISABLED, ENABLED, MANDATORY (prod always forces MANDATORY)
identity_platform_mfa_enforcement     = "DISABLED" # Non-prod can be relaxed
identity_platform_password_min_length = 12         # HIPAA recommends 12+

# Email configuration for invitations/password resets, from Doppler
identity_platform_email_sender_name = "Diary Platform"
identity_platform_email_reply_to    = "support@anspar.org"

# Session duration (HIPAA recommends 60 minutes or less)
identity_platform_session_duration = 60

# Additional authorized domains for OAuth (auto-includes project domains)
identity_platform_authorized_domains = ["portal-prod.callisto.anspar.org"]

# -----------------------------------------------------------------------------
# Optional: Workforce Identity Federation
# For external IdP federation (Azure AD, Okta SSO for sponsor staff)
# Note: Different from Identity Platform - this is for GCP resource access
# -----------------------------------------------------------------------------

workforce_identity_enabled = false

# For OIDC (Azure AD, Okta, etc.):
# workforce_identity_provider_type = "oidc"
# workforce_identity_issuer_uri    = "https://login.microsoftonline.com/{tenant}/v2.0"
# workforce_identity_client_id     = "your-client-id"
# workforce_identity_client_secret = "your-client-secret"  # Use Doppler!
# workforce_identity_allowed_domain = "example.com"

# -----------------------------------------------------------------------------
# Optional: Monitoring
# -----------------------------------------------------------------------------

# notification_channels = ["projects/cure-hht-example-dev/notificationChannels/123456"]

# -----------------------------------------------------------------------------
# Optional: Audit Configuration
# -----------------------------------------------------------------------------

audit_retention_years = 0	# TODO Set to 25 years when prod released
# TODO lock_audit_retention defaults to false; set true when ready to lock prod

# Billing budget (migrated from bootstrap)
budget_amount = 5000 # Monthly budget in USD

# -----------------------------------------------------------------------------
# Optional: Email
# -----------------------------------------------------------------------------
enable_gmail_api = true

enable_cost_controls = true
threshold_cutoff = 0.50 # 50% of budget - adjust as needed

# -----------------------------------------------------------------------------
# GitHub Actions Service Account (Cross-Project Deployment)
# -----------------------------------------------------------------------------

github_actions_sa = "github-actions-sa@cure-hht-admin.iam.gserviceaccount.com"

# -----------------------------------------------------------------------------
# Schema File Upload (for db-schema-job)
# -----------------------------------------------------------------------------
# Files are uploaded to GCS for the database deployment job.
# Run ./database/tool/consolidate-schema.sh before terraform apply.

schema_file_source       = "../../../database/init-consolidated.sql"
sponsor_data_file_name   = "seed_callisto4_prod.sql"
sponsor_data_file_source = "../../../../hht_diary_callisto/database/seed_data_prod.sql"

# -----------------------------------------------------------------------------
# VPC Network (migrated from bootstrap)
# -----------------------------------------------------------------------------

enable_proxy_only_subnet = true

enable_regional_lb      = true
lb_domain               = "*.callisto.anspar.org"
lb_enable_http_redirect = true
lb_cloud_run_services = {
  "diary-server" = {
    hosts = ["diary.callisto.anspar.org"]
  }
  "portal-server" = {
    hosts = ["portal.callisto.anspar.org"]
  }
}
