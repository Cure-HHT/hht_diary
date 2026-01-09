# modules/cloud-build/main.tf
#
# Creates Cloud Build triggers for building container images
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
  }
}

# -----------------------------------------------------------------------------
# Cloud Build Trigger - Diary Server
# -----------------------------------------------------------------------------

resource "google_cloudbuild_trigger" "diary_server" {
  name        = "${var.sponsor}-${var.environment}-diary-server"
  project     = var.project_id
  location    = var.region
  description = "Build diary-server for ${var.sponsor} ${var.environment}"

  # Trigger on push to specific branch
  github {
    owner = var.github_org
    name  = var.github_repo

    push {
      branch = var.trigger_branch
    }
  }

  # Only trigger on changes to diary-server
  included_files = [
    "apps/containers/diary-server/**",
    "packages/**",
  ]

  build {
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build",
        "-t", "${var.artifact_registry_url}/diary-server:$COMMIT_SHA",
        "-t", "${var.artifact_registry_url}/diary-server:latest",
        "-f", "apps/containers/diary-server/Dockerfile",
        ".",
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "${var.artifact_registry_url}/diary-server:$COMMIT_SHA",
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "${var.artifact_registry_url}/diary-server:latest",
      ]
    }

    # Deploy to Cloud Run
    step {
      name = "gcr.io/google.com/cloudsdktool/cloud-sdk"
      args = [
        "gcloud",
        "run",
        "deploy",
        "diary-server",
        "--image", "${var.artifact_registry_url}/diary-server:$COMMIT_SHA",
        "--region", var.region,
        "--project", var.project_id,
      ]
    }

    images = [
      "${var.artifact_registry_url}/diary-server:$COMMIT_SHA",
      "${var.artifact_registry_url}/diary-server:latest",
    ]

    options {
      logging = "CLOUD_LOGGING_ONLY"
    }

    timeout = "1200s"
  }

  service_account = var.cloud_build_service_account
}

# -----------------------------------------------------------------------------
# Cloud Build Trigger - Portal Server
# -----------------------------------------------------------------------------

resource "google_cloudbuild_trigger" "portal_server" {
  name        = "${var.sponsor}-${var.environment}-portal-server"
  project     = var.project_id
  location    = var.region
  description = "Build portal-server for ${var.sponsor} ${var.environment}"

  github {
    owner = var.github_org
    name  = var.github_repo

    push {
      branch = var.trigger_branch
    }
  }

  # Only trigger on changes to portal-server
  included_files = [
    "apps/containers/portal-server/**",
    "apps/portal/**",
    "packages/**",
  ]

  build {
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build",
        "-t", "${var.artifact_registry_url}/portal-server:$COMMIT_SHA",
        "-t", "${var.artifact_registry_url}/portal-server:latest",
        "-f", "apps/containers/portal-server/Dockerfile",
        ".",
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "${var.artifact_registry_url}/portal-server:$COMMIT_SHA",
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "${var.artifact_registry_url}/portal-server:latest",
      ]
    }

    # Deploy to Cloud Run
    step {
      name = "gcr.io/google.com/cloudsdktool/cloud-sdk"
      args = [
        "gcloud",
        "run",
        "deploy",
        "portal-server",
        "--image", "${var.artifact_registry_url}/portal-server:$COMMIT_SHA",
        "--region", var.region,
        "--project", var.project_id,
      ]
    }

    images = [
      "${var.artifact_registry_url}/portal-server:$COMMIT_SHA",
      "${var.artifact_registry_url}/portal-server:latest",
    ]

    options {
      logging = "CLOUD_LOGGING_ONLY"
    }

    timeout = "1200s"
  }

  service_account = var.cloud_build_service_account
}
