# example-dev.tfvars
#
# Example sponsor-portal configuration for dev environment
# Copy and customize for each sponsor/environment:
#   cp example-dev.tfvars {sponsor}-{env}.tfvars

# -----------------------------------------------------------------------------
# Required: Sponsor Identity
# -----------------------------------------------------------------------------

sponsor     = "callisto4"
sponsor_id  = 4  # Must match bootstrap sponsor_id
environment = "dev"

# -----------------------------------------------------------------------------
# Required: GCP Configuration
# -----------------------------------------------------------------------------

project_id = "callisto4-dev"  # From bootstrap output
project_number = "1012274191696"  # From bootstrap output (gcloud projects describe callisto4-qa --format='value(projectNumber)')

# Sensitive values should be provided via Doppler environment variables:
# - TF_VAR_GCP_ORG_ID
# - TF_VAR_BILLING_ACCOUNT_PROD
# - TF_VAR_BILLING_ACCOUNT_DEV
# - TF_VAR_DB_PASSWORD
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

# Database password - use Doppler or set via environment variable

# -----------------------------------------------------------------------------
# Optional: Project Configuration
# -----------------------------------------------------------------------------

region         = "europe-west9"
project_prefix = "cure-hht"

# -----------------------------------------------------------------------------
# Optional: Cloud Run Sizing
# -----------------------------------------------------------------------------

min_instances    = 1
max_instances    = 5
container_memory = "512Mi"
container_cpu    = "1"

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
diary_server_image  = "europe-west9-docker.pkg.dev/cure-hht-admin/ghcr-remote/cure-hht/clinical-diary-diary-server:latest"
portal_server_image = "europe-west9-docker.pkg.dev/cure-hht-admin/ghcr-remote/cure-hht/clinical-diary-portal-server:latest"

# Disable public access due to organization policy restrictions
allow_public_access = false

# -----------------------------------------------------------------------------
# Optional: Identity Platform (HIPAA/GDPR-compliant authentication)
# For portal users (investigators, admins)
# -----------------------------------------------------------------------------

enable_identity_platform = true

# Authentication methods
identity_platform_email_password = true   # Email/password login
identity_platform_email_link     = false  # Passwordless email links
identity_platform_phone_auth     = false  # Phone number authentication

# Security settings
# MFA: DISABLED, ENABLED, MANDATORY (prod always forces MANDATORY)
identity_platform_mfa_enforcement   = "DISABLED"  # Non-prod can be relaxed
identity_platform_password_min_length = 12        # HIPAA recommends 12+

# Email configuration for invitations/password resets
identity_platform_email_sender_name = "Diary Platform"
identity_platform_email_reply_to  = "support@anspar.org"

# Session duration (HIPAA recommends 60 minutes or less)
identity_platform_session_duration = 60

# Additional authorized domains for OAuth (auto-includes project domains)
# identity_platform_authorized_domains = ["portal.example.com"]

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

audit_retention_years = 25
# Note: lock_retention_policy is automatically set based on environment
# (true for prod, false for dev/qa/uat)

# -----------------------------------------------------------------------------
# Optional: Email
# -----------------------------------------------------------------------------
impersonating_service_account_email = "1012274191696-compute@developer.gserviceaccount.com"

enable_cost_controls = false

