# sponsor-portal/versions.tf
#
# Terraform and provider version constraints

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0, < 6.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0.0, < 6.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }

  # GCS backend for state management
  # Configured dynamically via -backend-config in deploy script
  backend "gcs" {}
}
