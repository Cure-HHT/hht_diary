# IMPLEMENTS REQUIREMENTS:
#   REQ-o00041: Infrastructure as Code for Cloud Resources
#   REQ-o00050: Environment Parity and Separation
#
# Staging Environment Infrastructure
# Provisions Supabase project for pre-production testing

terraform {
  required_version = ">= 1.6"

  required_providers {
    supabase = {
      source  = "supabase/supabase"
      version = "~> 1.0"
    }
  }

  # Uncomment when ready to activate:
  # cloud {
  #   organization = "clinical-diary"
  #   workspaces {
  #     name = "clinical-diary-staging"
  #   }
  # }
}

provider "supabase" {
  access_token = var.supabase_access_token
}

locals {
  environment  = "staging"
  project_name = "clinical-diary-${local.environment}"

  common_tags = {
    Environment = local.environment
    Project     = "clinical-diary"
    ManagedBy   = "terraform"
    Owner       = "devops-team"
  }
}

module "supabase" {
  source = "../../modules/supabase-project"

  organization_id   = var.supabase_organization_id
  project_name      = local.project_name
  database_password = var.database_password

  region = var.region
  tier   = "pro"  # Pro tier for staging

  site_url      = var.site_url
  enable_signup = true

  max_connections    = 100
  file_size_limit_mb = 50

  # Backups enabled with 7-day retention
  enable_backups        = true
  backup_retention_days = 7
  enable_pitr           = false  # PITR not needed for staging

  doppler_token = var.doppler_token

  tags = local.common_tags
}

output "project_url" {
  value = module.supabase.project_url
}

output "api_url" {
  value = module.supabase.api_url
}

output "service_role_key" {
  value     = module.supabase.service_role_key
  sensitive = true
}
