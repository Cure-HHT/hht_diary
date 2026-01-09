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
# Required: GCP Organization
# -----------------------------------------------------------------------------

# GCP Organization ID (find with: gcloud organizations list)
gcp_org_id = "123456789012"

# -----------------------------------------------------------------------------
# Required: Billing Accounts
# -----------------------------------------------------------------------------

# Billing account for production environment
billing_account_prod = "XXXXXX-XXXXXX-XXXXXX"

# Billing account for dev/qa/uat environments
billing_account_dev = "XXXXXX-XXXXXX-XXXXXX"

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

# Create BigQuery datasets for audit analytics (default: true)
# create_bigquery_datasets = true
