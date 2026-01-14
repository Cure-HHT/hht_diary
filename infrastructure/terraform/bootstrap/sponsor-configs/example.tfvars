# example.tfvars
#
# Example sponsor configuration for bootstrap
# Copy this file and customize for each sponsor:
#   cp example.tfvars {sponsor-name}.tfvars

# -----------------------------------------------------------------------------
# Required: Sponsor Identity
# -----------------------------------------------------------------------------

# Sponsor name (lowercase, alphanumeric with hyphens, max 20 chars)
sponsor = "example"

# Unique sponsor ID for VPC CIDR allocation (1-254)
# IMPORTANT: Must be unique across all sponsors!
# See CONVERSION-PLAN.md for assigned IDs
sponsor_id = 99

# -----------------------------------------------------------------------------
# Required: GCP Organization & Billing (via Doppler)
# -----------------------------------------------------------------------------

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
# Optional: Project Configuration
# -----------------------------------------------------------------------------

# Prefix for project IDs (default: cure-hht)
project_prefix = "cure-hht"

# Default GCP region (default: europe-west9 - Paris)
default_region = "europe-west9"

# GCP Folder ID to place projects in (optional)
# folder_id = "folders/123456789"

# -----------------------------------------------------------------------------
# Optional: GitHub Integration
# -----------------------------------------------------------------------------

# GitHub organization for Workload Identity Federation
github_org = "Cure-HHT"

# GitHub repository for Workload Identity Federation
github_repo = "hht_diary"

# Enable Workload Identity Federation (default: true)
enable_workload_identity = true

# -----------------------------------------------------------------------------
# Optional: Admin Access
# -----------------------------------------------------------------------------

# Google group email for Anspar administrators
# This group gets owner access to dev/qa, viewer access to uat/prod
# anspar_admin_group = "anspar-admins@cure-hht.org"

# -----------------------------------------------------------------------------
# Optional: Budget Configuration
# -----------------------------------------------------------------------------

# Monthly budget amounts per environment (USD)
# budget_amounts = {
#   dev  = 500
#   qa   = 500
#   uat  = 1000
#   prod = 5000
# }

# -----------------------------------------------------------------------------
# Optional: Audit Configuration
# -----------------------------------------------------------------------------

# Audit log retention in years (FDA requires 25)
# audit_retention_years = 25

# Include data access logs in audit exports (default: true)
# include_data_access_logs = true
