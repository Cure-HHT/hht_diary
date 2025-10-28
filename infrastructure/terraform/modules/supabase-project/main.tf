# IMPLEMENTS REQUIREMENTS:
#   REQ-o00041: Infrastructure as Code for Cloud Resources
#   REQ-o00042: Infrastructure Change Control
#   REQ-o00050: Environment Parity and Separation
#
# Supabase Project Terraform Module
# Creates and configures a Supabase project with database, authentication, and storage

terraform {
  required_version = ">= 1.6"

  required_providers {
    supabase = {
      source  = "supabase/supabase"
      version = "~> 1.0"
    }
  }
}

# Supabase Project
resource "supabase_project" "main" {
  organization_id   = var.organization_id
  name              = var.project_name
  database_password = var.database_password
  region            = var.region

  # Project tier (free, pro, team, enterprise)
  plan = var.tier
}

# Database Settings
resource "supabase_settings" "database" {
  project_ref = supabase_project.main.id

  database = {
    enable_logs          = true
    log_min_duration_ms  = 1000  # Log queries > 1 second
    max_connections      = var.max_connections
    statement_timeout_ms = 30000  # 30 seconds
  }
}

# Auth Settings
resource "supabase_settings" "auth" {
  project_ref = supabase_project.main.id

  auth = {
    site_url                  = var.site_url
    enable_signup             = var.enable_signup
    jwt_expiry                = 3600  # 1 hour
    enable_email_confirmations = true
    enable_mfa                = true  # Multi-factor authentication

    # External providers (if needed)
    external_google_enabled = false
    external_github_enabled = false
  }
}

# Storage Settings
resource "supabase_settings" "storage" {
  project_ref = supabase_project.main.id

  storage = {
    file_size_limit          = var.file_size_limit_mb * 1024 * 1024  # Convert MB to bytes
    public_bucket_read_access = false  # Require authentication
  }
}

# API Settings
resource "supabase_settings" "api" {
  project_ref = supabase_project.main.id

  api = {
    db_schema            = "public"
    max_rows             = 1000
    enable_db_webhooks   = false
    enable_realtime      = true
  }
}

# Backups (Pro tier only)
resource "supabase_backup" "daily" {
  count = var.enable_backups ? 1 : 0

  project_ref = supabase_project.main.id

  schedule        = "0 2 * * *"  # 2 AM daily
  retention_days  = var.backup_retention_days
  enable_pitr     = var.enable_pitr  # Point-in-time recovery
}

# Secrets (for Doppler integration)
resource "supabase_secret" "doppler_token" {
  count = var.doppler_token != "" ? 1 : 0

  project_ref = supabase_project.main.id
  name        = "DOPPLER_TOKEN"
  value       = var.doppler_token
}

# Database Branches (for staging/preview environments)
resource "supabase_branch" "preview" {
  count = var.create_preview_branch ? 1 : 0

  project_ref = supabase_project.main.id
  name        = "preview"
  parent_branch = "main"
}
