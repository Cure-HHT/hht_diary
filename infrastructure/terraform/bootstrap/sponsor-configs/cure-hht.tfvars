# cure-hht.tfvars
#
# Sponsor configuration for Cure HHT (organizational sponsor)

# -----------------------------------------------------------------------------
# Sponsor Identity
# -----------------------------------------------------------------------------

sponsor    = "cure-hht"
sponsor_id = 2 # VPC CIDR: 10.2.0.0/16

# -----------------------------------------------------------------------------
# Project Configuration
# -----------------------------------------------------------------------------

project_prefix = "cure-hht"
default_region = "europe-west9"

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
# GitHub Integration
# -----------------------------------------------------------------------------

github_org               = "Cure-HHT"
github_repo              = "hht_diary"
enable_workload_identity = true

# -----------------------------------------------------------------------------
# Admin Access
# -----------------------------------------------------------------------------

anspar_admin_group = "devops-admins@anspar.org"

# -----------------------------------------------------------------------------
# Budget Configuration (Temporary: disable cost controls for initial setup)
# -----------------------------------------------------------------------------

enable_cost_controls = false
