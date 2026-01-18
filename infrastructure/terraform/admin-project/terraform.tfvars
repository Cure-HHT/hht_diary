# admin-project/terraform.tfvars
#
# Configuration for the cure-hht-admin project
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00002: Multi-Factor Authentication for Staff (Gmail API for email OTP)

# -----------------------------------------------------------------------------
# Project Configuration
# -----------------------------------------------------------------------------

project_id = "cure-hht-admin"
region     = "europe-west9"

# These must be provided via Doppler environment variables:
# - TF_VAR_ADMIN_PROJECT_NUMBER
# - TF_VAR_GCP_ORG_ID

# -----------------------------------------------------------------------------
# Gmail Service Account Configuration
# -----------------------------------------------------------------------------

gmail_sender_email = "support@anspar.org"

# -----------------------------------------------------------------------------
# Sponsor Cloud Run Service Accounts
# -----------------------------------------------------------------------------
#
# Add each sponsor/environment's Cloud Run service account here to allow
# impersonation of the Gmail SA.
#
# Get the service account from sponsor-portal terraform output:
#   cd infrastructure/terraform/sponsor-portal
#   terraform output -raw portal_server_service_account_email
#
# Example:
#   "portal-server@cure-hht-dev.iam.gserviceaccount.com",
#   "portal-server@cure-hht-qa.iam.gserviceaccount.com",
#   "portal-server@cure-hht-uat.iam.gserviceaccount.com",
#   "portal-server@cure-hht-prod.iam.gserviceaccount.com",
#   "portal-server@callisto-dev.iam.gserviceaccount.com",
#   etc.

sponsor_cloud_run_service_accounts = [
  # Add Cloud Run service account emails here after deploying sponsor-portal
]
