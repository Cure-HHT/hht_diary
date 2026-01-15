# modules/gcp-project/main.tf
#
# Creates a GCP project with required APIs enabled
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00008: Multi-sponsor deployment model

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

# -----------------------------------------------------------------------------
# GCP Project
# -----------------------------------------------------------------------------

resource "google_project" "main" {
  name            = var.project_display_name
  project_id      = var.project_id
  org_id          = var.folder_id == "" ? var.org_id : null
  folder_id       = var.folder_id != "" ? var.folder_id : null
  billing_account = var.billing_account_id

  # Don't auto-create default network - we create VPC explicitly
  auto_create_network = false

  labels = merge(var.labels, {
    sponsor     = var.sponsor
    environment = var.environment
    managed_by  = "terraform"
    compliance  = "fda-21-cfr-part-11"
  })

  lifecycle {
    prevent_destroy = false # Set to true in production via variable
  }
}

# -----------------------------------------------------------------------------
# Enable Required APIs
# -----------------------------------------------------------------------------

locals {
  required_apis = [
    "cloudresourcemanager.googleapis.com", # Project management
    "compute.googleapis.com",              # Compute Engine (VPC)
    "run.googleapis.com",                  # Cloud Run
    "artifactregistry.googleapis.com",     # Container/package registry
    "sqladmin.googleapis.com",             # Cloud SQL (PostgreSQL)
    "secretmanager.googleapis.com",        # Secret management
    "iam.googleapis.com",                  # Identity & Access Management
    "iamcredentials.googleapis.com",       # Service account credentials
    "cloudidentity.googleapis.com",        # Cloud Identity
    "monitoring.googleapis.com",           # Cloud Monitoring
    "logging.googleapis.com",              # Cloud Logging
    "cloudbuild.googleapis.com",           # Cloud Build (CI/CD)
    "vpcaccess.googleapis.com",            # Serverless VPC Access
    "servicenetworking.googleapis.com",    # Private service connection
    "sts.googleapis.com",                  # Security Token Service (WIF)
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project = google_project.main.project_id
  service = each.value

  # Don't disable APIs when removing from Terraform
  disable_on_destroy         = false
  disable_dependent_services = false

  timeouts {
    create = "30m"
    update = "40m"
  }

  depends_on = [google_project.main]
}
