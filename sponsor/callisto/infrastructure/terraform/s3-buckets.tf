# Callisto S3 Buckets
#
# Terraform configuration for Callisto sponsor S3 buckets.
# Uses the sponsor-s3 module from core infrastructure.
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-CAL-o00001: Callisto infrastructure
#   REQ-o00016: FDA compliance archival

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Recommended: Use S3 backend for state storage
  # backend "s3" {
  #   bucket         = "hht-diary-terraform-state-callisto"
  #   key            = "sponsor/callisto/s3-buckets/terraform.tfstate"
  #   region         = "eu-west-1"
  #   encrypt        = true
  #   dynamodb_table = "hht-diary-terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "HHT Diary"
      Sponsor     = "Callisto"
      SponsorCode = "CAL"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}

# Local values
locals {
  sponsor_name = "callisto"
  sponsor_code = "CAL"
  region_short = replace(var.aws_region, "-", "")  # e.g., euwest1

  # Bucket naming: hht-diary-{type}-{sponsor}-{region}
  artifacts_bucket = "hht-diary-artifacts-${local.sponsor_name}-${var.aws_region}"
  backups_bucket   = "hht-diary-backups-${local.sponsor_name}-${var.aws_region}"
  logs_bucket      = "hht-diary-logs-${local.sponsor_name}-${var.aws_region}"

  common_tags = {
    Sponsor     = local.sponsor_name
    SponsorCode = local.sponsor_code
    Region      = var.aws_region
  }
}

# Sponsor S3 Buckets Module
module "s3_buckets" {
  source = "../../../../infrastructure/terraform/modules/sponsor-s3"

  sponsor_name = local.sponsor_name
  sponsor_code = local.sponsor_code
  aws_region   = var.aws_region

  artifacts_bucket_name = local.artifacts_bucket
  backups_bucket_name   = local.backups_bucket
  logs_bucket_name      = local.logs_bucket

  enable_object_lock = var.enable_object_lock
  create_cicd_user   = var.create_cicd_user

  common_tags = local.common_tags
}

# Outputs for Doppler integration
output "artifacts_bucket_name" {
  description = "Artifacts bucket name for Doppler SPONSOR_ARTIFACTS_BUCKET"
  value       = module.s3_buckets.artifacts_bucket_id
}

output "artifacts_bucket_arn" {
  description = "Artifacts bucket ARN"
  value       = module.s3_buckets.artifacts_bucket_arn
}

output "backups_bucket_name" {
  description = "Backups bucket name"
  value       = module.s3_buckets.backups_bucket_id
}

output "logs_bucket_name" {
  description = "Logs bucket name"
  value       = module.s3_buckets.logs_bucket_id
}

output "cicd_policy_arn" {
  description = "CI/CD policy ARN (attach to GitHub Actions OIDC role)"
  value       = module.s3_buckets.cicd_policy_arn
}

output "cicd_user_name" {
  description = "CI/CD user name (if created)"
  value       = module.s3_buckets.cicd_user_name
}
