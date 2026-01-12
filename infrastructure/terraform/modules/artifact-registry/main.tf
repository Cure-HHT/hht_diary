# modules/artifact-registry/main.tf
#
# Creates Artifact Registry for Docker images
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment

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
# Local Variables
# -----------------------------------------------------------------------------

locals {
  common_labels = {
    sponsor     = var.sponsor
    environment = var.environment
    managed_by  = "terraform"
    compliance  = "fda-21-cfr-part-11"
  }
}

# -----------------------------------------------------------------------------
# Artifact Registry Repository
# -----------------------------------------------------------------------------

resource "google_artifact_registry_repository" "main" {
  repository_id = "${var.sponsor}-${var.environment}-docker"
  project       = var.project_id
  location      = var.region
  format        = "DOCKER"
  description   = "Docker images for ${var.sponsor} ${var.environment}"
  labels        = local.common_labels

  # Cleanup policy for old images
  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"

    condition {
      tag_state = "UNTAGGED"
      older_than = "604800s" # 7 days
    }
  }

  cleanup_policies {
    id     = "keep-tagged"
    action = "KEEP"

    condition {
      tag_state    = "TAGGED"
      tag_prefixes = ["v", "release", "prod", "latest"]
    }
  }

  cleanup_policies {
    id     = "delete-old-tagged"
    action = "DELETE"

    condition {
      tag_state  = "TAGGED"
      older_than = "7776000s" # 90 days
    }

  }
  # Keep minimum number of recent versions regardless of age
  cleanup_policies {
    id     = "keep-recent-versions"
    action = "KEEP"

    most_recent_versions {
      keep_count = 10
    }
}

  # Vulnerability scanning
  docker_config {
    immutable_tags = var.environment == "prod"
  }
}

# -----------------------------------------------------------------------------
# IAM - CI/CD Access
# -----------------------------------------------------------------------------

resource "google_artifact_registry_repository_iam_member" "cicd_writer" {
  count = var.cicd_service_account != "" ? 1 : 0

  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.main.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.cicd_service_account}"
}

resource "google_artifact_registry_repository_iam_member" "cloud_run_reader" {
  count = var.cloud_run_service_account != "" ? 1 : 0

  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.main.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.cloud_run_service_account}"
}
