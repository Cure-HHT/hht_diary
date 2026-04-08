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
# Get the service account from sponsor-envs terraform output:
#   cd infrastructure/terraform/sponsor-envs
#   terraform output -raw portal_server_service_account_email
#
# Example:
#   "portal-server@cure-hht-dev.iam.gserviceaccount.com",
#   "portal-server@cure-hht-qa.iam.gserviceaccount.com",
#   "portal-server@cure-hht-uat.iam.gserviceaccount.com",
#   "portal-server@cure-hht-prod.iam.gserviceaccount.com",
#   "portal-server@callisto-dev.iam.gserviceaccount.com",
#   etc.


# -----------------------------------------------------------------------------
# Sponsor Terraform Service Accounts
# -----------------------------------------------------------------------------
#
# Add Terraform service accounts that deploy sponsor environments here.
# These need serviceUsageConsumer access to reference admin project resources
# (e.g., github-actions-sa service account).

# Cloud Run runtime service accounts (Gmail SA impersonation for email OTP)
sponsor_cloud_run_service_accounts = [
  "768644809588-compute@developer.gserviceaccount.com"                   # callisto4-uat default compute SA (Gmail signJwt)
]

# Cloud Run Service Agents (need artifactregistry.reader to pull images from GAR)
# Format: service-{PROJECT_NUMBER}@serverless-robot-prod.iam.gserviceaccount.com
sponsor_cloud_run_service_agents = [
  "service-768644809588@serverless-robot-prod.iam.gserviceaccount.com",  # callisto4-uat Cloud Run Service Agent
]

# Add the Compute Engine default service account for each sponsor/environment here to allow read access to the schema bucket for migrations/resets.
sponsor_compute_default_service_accounts = [
  "421945483876-compute@developer.gserviceaccount.com",  # callisto4-qa
  "768644809588-compute@developer.gserviceaccount.com"   # callisto4-uat
]

# Add Terraform service accounts that deploy sponsor environments here.
# These need serviceUsageConsumer access to reference admin project resources
# (e.g., github-actions-sa service account).
sponsor_terraform_service_accounts = [
  "terraform-sa@callisto4-uat.iam.gserviceaccount.com"   # callisto4-uat Terraform SA
]
