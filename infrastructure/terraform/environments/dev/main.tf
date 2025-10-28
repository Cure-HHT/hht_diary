# IMPLEMENTS REQUIREMENTS:
#   REQ-o00041: Infrastructure as Code for Cloud Resources
#   REQ-o00050: Environment Parity and Separation
#
# Development Environment Infrastructure
# Provisions Supabase project for development/testing

terraform {
  required_version = ">= 1.6"

  required_providers {
    supabase = {
      source  = "supabase/supabase"
      version = "~> 1.0"
    }
  }

  # State backend - configure after initial setup
  # Uncomment and configure one of the following:

  # Option 1: Terraform Cloud (recommended)
  # cloud {
  #   organization = "clinical-diary"
  #   workspaces {
  #     name = "clinical-diary-dev"
  #   }
  # }

  # Option 2: S3 Backend
  # backend "s3" {
  #   bucket         = "clinical-diary-terraform-state"
  #   key            = "environments/dev/terraform.tfstate"
  #   region         = "us-west-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# Configure Supabase Provider
provider "supabase" {
  access_token = var.supabase_access_token
}

# Local Variables
locals {
  environment = "dev"
  project_name = "clinical-diary-${local.environment}"

  common_tags = {
    Environment = local.environment
    Project     = "clinical-diary"
    ManagedBy   = "terraform"
    Owner       = "devops-team"
  }
}

# Supabase Project
module "supabase" {
  source = "../../modules/supabase-project"

  organization_id   = var.supabase_organization_id
  project_name      = local.project_name
  database_password = var.database_password

  region = var.region
  tier   = "free"  # Free tier for development

  # Authentication
  site_url      = var.site_url
  enable_signup = true

  # Database
  max_connections = 50  # Lower for dev

  # Storage
  file_size_limit_mb = 10  # Lower limit for dev

  # Backups - disabled for free tier
  enable_backups        = false
  backup_retention_days = 0
  enable_pitr           = false

  # Preview branch for testing
  create_preview_branch = true

  # Doppler integration
  doppler_token = var.doppler_token

  tags = local.common_tags
}

# Output for easy access
output "project_url" {
  description = "Supabase project URL"
  value       = module.supabase.project_url
}

output "api_url" {
  description = "Supabase API URL"
  value       = module.supabase.api_url
}

output "database_host" {
  description = "Database connection host"
  value       = module.supabase.database_host
}

output "anon_key" {
  description = "Supabase anonymous key (public)"
  value       = module.supabase.anon_key
  sensitive   = false
}

output "service_role_key" {
  description = "Supabase service role key (KEEP SECRET)"
  value       = module.supabase.service_role_key
  sensitive   = true
}

# Instructions output
output "next_steps" {
  description = "Next steps after Terraform apply"
  value       = <<-EOT
    ✅ Development environment created!

    Project URL: ${module.supabase.project_url}
    API URL: ${module.supabase.api_url}

    Next steps:
    1. Store service role key in Doppler:
       doppler secrets set SUPABASE_SERVICE_KEY="${module.supabase.service_role_key}"

    2. Store anonymous key in Doppler:
       doppler secrets set SUPABASE_ANON_KEY="${module.supabase.anon_key}"

    3. Update application .env with project URL:
       SUPABASE_URL=${module.supabase.project_url}

    4. Deploy database schema:
       cd database
       supabase db push --project-ref ${module.supabase.project_id}

    5. Test connection:
       supabase status --project-ref ${module.supabase.project_id}
  EOT
}
