# IMPLEMENTS REQUIREMENTS:
#   REQ-o00041: Infrastructure as Code for Cloud Resources
#   REQ-o00050: Environment Parity and Separation
#
# Production Environment Infrastructure
# Provisions Supabase project for production use with full compliance features

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
  #     name = "clinical-diary-production"
  #   }
  # }
}

provider "supabase" {
  access_token = var.supabase_access_token
}

locals {
  environment  = "production"
  project_name = "clinical-diary-${local.environment}"

  common_tags = {
    Environment  = local.environment
    Project      = "clinical-diary"
    ManagedBy    = "terraform"
    Owner        = "devops-team"
    CriticalData = "true"
    Compliance   = "FDA-21-CFR-Part-11"
  }
}

module "supabase" {
  source = "../../modules/supabase-project"

  organization_id   = var.supabase_organization_id
  project_name      = local.project_name
  database_password = var.database_password

  region = var.region
  tier   = "pro"  # Pro tier for production

  site_url      = var.site_url
  enable_signup = var.enable_signup

  max_connections    = 200  # Higher for production
  file_size_limit_mb = 50

  # Full backups with 30-day retention and PITR
  enable_backups        = true
  backup_retention_days = 30
  enable_pitr           = true

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

output "anon_key" {
  value     = module.supabase.anon_key
  sensitive = false
}

output "next_steps" {
  description = "Next steps after Terraform apply"
  value       = <<-EOT
    ✅ Production environment created!

    Project URL: ${module.supabase.project_url}
    API URL: ${module.supabase.api_url}

    ⚠️  CRITICAL NEXT STEPS:

    1. Store service role key in Doppler:
       doppler secrets set SUPABASE_SERVICE_KEY="${module.supabase.service_role_key}" --project clinical-diary --config prd

    2. Store anonymous key in Doppler:
       doppler secrets set SUPABASE_ANON_KEY="${module.supabase.anon_key}" --project clinical-diary --config prd

    3. Deploy database schema:
       cd database
       supabase db push --project-ref ${module.supabase.project_id}

    4. Run smoke tests:
       cd tools/testing
       ./smoke-tests.sh production

    5. Configure monitoring:
       - Add project to Sentry (see docs/monitoring/sentry-setup.md)
       - Add endpoint to Better Uptime
       - Verify Supabase metrics dashboard

    6. Document deployment in validation log:
       - Record in docs/validation/deployment-log.md
       - Update traceability matrix
  EOT
}
