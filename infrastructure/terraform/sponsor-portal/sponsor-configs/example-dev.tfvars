# example-dev.tfvars
#
# Example sponsor-portal configuration for dev environment
# Copy and customize for each sponsor/environment:
#   cp example-dev.tfvars {sponsor}-{env}.tfvars

# -----------------------------------------------------------------------------
# Required: Sponsor Identity
# -----------------------------------------------------------------------------

sponsor     = "example"
sponsor_id  = 99  # Must match bootstrap sponsor_id
environment = "dev"

# -----------------------------------------------------------------------------
# Required: GCP Configuration
# -----------------------------------------------------------------------------

project_id = "cure-hht-example-dev"  # From bootstrap output
gcp_org_id = "123456789012"

# -----------------------------------------------------------------------------
# Required: Database
# -----------------------------------------------------------------------------

# Database password - use Doppler or set via environment variable
# db_password = "changeme"  # DO NOT commit real passwords!

# -----------------------------------------------------------------------------
# Optional: Project Configuration
# -----------------------------------------------------------------------------

region         = "us-central1"
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

# Enable Cloud Build triggers
enable_cloud_build_triggers = true

# -----------------------------------------------------------------------------
# Optional: Workforce Identity
# Enables sponsor employees to SSO into the portal
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
