# cure-hht.tfvars
#
# Sponsor configuration for Cure HHT (organizational sponsor)

# -----------------------------------------------------------------------------
# Sponsor Identity
# -----------------------------------------------------------------------------

sponsor    = "cure-hht"
sponsor_id = 2 # VPC CIDR: 10.2.0.0/16

# -----------------------------------------------------------------------------
# GCP Organization
# -----------------------------------------------------------------------------

gcp_org_id = "123456789012" # Actual ORG ID is in doppler

# -----------------------------------------------------------------------------
# Billing Accounts
# -----------------------------------------------------------------------------

billing_account_prod = "xxxxxx-xxxxxx-xxxxxx" # Cure HHT
billing_account_dev  = "xxxxxx-xxxxxx-xxxxxx" # Cure HHT - Dev

# -----------------------------------------------------------------------------
# Project Configuration
# -----------------------------------------------------------------------------

project_prefix = "cure-hht"
default_region = "europe-west9"

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
