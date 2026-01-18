# admin-project/versions.tf
#
# Terraform and provider version constraints
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00002: Multi-Factor Authentication for Staff (Gmail API for email OTP)

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }

  backend "gcs" {
    bucket = "cure-hht-terraform-state"
    prefix = "admin-project"
  }
}
