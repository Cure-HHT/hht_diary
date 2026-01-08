# modules/cloud-run/main.tf
#
# Creates Cloud Run services (diary-server and portal-server)
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
  is_production = var.environment == "prod"

  common_labels = {
    sponsor     = var.sponsor
    environment = var.environment
    managed_by  = "terraform"
    compliance  = "fda-21-cfr-part-11"
  }

  # Environment variables common to all services
  common_env_vars = {
    ENVIRONMENT    = var.environment
    SPONSOR        = var.sponsor
    PROJECT_ID     = var.project_id
    DB_HOST        = var.db_host
    DB_PORT        = "5432"
    DB_NAME        = var.db_name
    DB_USER        = var.db_user
    LOG_LEVEL      = local.is_production ? "info" : "debug"
  }
}

# -----------------------------------------------------------------------------
# Service Account for Cloud Run
# -----------------------------------------------------------------------------

resource "google_service_account" "cloud_run" {
  account_id   = "${var.sponsor}-${var.environment}-run-sa"
  display_name = "Cloud Run Service Account - ${var.sponsor} ${var.environment}"
  project      = var.project_id
}

# IAM roles for the service account
resource "google_project_iam_member" "cloud_run_roles" {
  for_each = toset([
    "roles/cloudsql.client",
    "roles/secretmanager.secretAccessor",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/cloudtrace.agent",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# -----------------------------------------------------------------------------
# Diary Server - Dart Backend API
# -----------------------------------------------------------------------------

resource "google_cloud_run_v2_service" "diary_server" {
  name     = "diary-server"
  location = var.region
  project  = var.project_id

  labels = merge(local.common_labels, {
    service = "diary-server"
  })

  template {
    service_account = google_service_account.cloud_run.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    vpc_access {
      connector = var.vpc_connector_id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = var.diary_server_image

      resources {
        limits = {
          cpu    = var.container_cpu
          memory = var.container_memory
        }
        cpu_idle          = !local.is_production
        startup_cpu_boost = true
      }

      # Environment variables
      dynamic "env" {
        for_each = local.common_env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      # Database password from secret
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = var.db_password_secret_id
            version = "latest"
          }
        }
      }

      ports {
        container_port = 8080
      }

      startup_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 5
        timeout_seconds       = 3
        period_seconds        = 10
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        timeout_seconds   = 3
        period_seconds    = 30
        failure_threshold = 3
      }
    }

    timeout = "300s"

    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image, # Image managed by CI/CD
    ]
  }
}

# -----------------------------------------------------------------------------
# Portal Server - Flutter Web
# -----------------------------------------------------------------------------

resource "google_cloud_run_v2_service" "portal_server" {
  name     = "portal-server"
  location = var.region
  project  = var.project_id

  labels = merge(local.common_labels, {
    service = "portal-server"
  })

  template {
    service_account = google_service_account.cloud_run.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    vpc_access {
      connector = var.vpc_connector_id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = var.portal_server_image

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle          = !local.is_production
        startup_cpu_boost = true
      }

      # Environment variables for portal
      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }

      env {
        name  = "SPONSOR"
        value = var.sponsor
      }

      env {
        name  = "API_URL"
        value = "https://${google_cloud_run_v2_service.diary_server.uri}"
      }

      ports {
        container_port = 8080
      }

      startup_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 2
        timeout_seconds       = 2
        period_seconds        = 5
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        timeout_seconds   = 2
        period_seconds    = 30
        failure_threshold = 3
      }
    }

    timeout = "60s"

    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image, # Image managed by CI/CD
    ]
  }
}

# -----------------------------------------------------------------------------
# IAM - Public Access
# -----------------------------------------------------------------------------

# Allow unauthenticated access to portal (app handles auth)
resource "google_cloud_run_v2_service_iam_member" "portal_public" {
  count = var.allow_public_access ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.portal_server.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Allow unauthenticated access to diary server API
resource "google_cloud_run_v2_service_iam_member" "diary_public" {
  count = var.allow_public_access ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.diary_server.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
