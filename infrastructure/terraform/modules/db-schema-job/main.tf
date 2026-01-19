# modules/db-schema-job/main.tf
#
# Cloud Run Job to apply database schema to Cloud SQL
# Uses Cloud SQL Auth Proxy sidecar for secure private IP connectivity
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00042: Infrastructure audit trail for FDA compliance
#   REQ-d00057: Automated database schema deployment

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
  job_name = "${var.sponsor}-${var.environment}-db-schema"

  common_labels = {
    sponsor     = var.sponsor
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "db-schema-deployment"
  }
}

# -----------------------------------------------------------------------------
# Service Account for Cloud Run Job
# -----------------------------------------------------------------------------

resource "google_service_account" "schema_job" {
  project      = var.project_id
  account_id   = "${var.sponsor}-${var.environment}-schema-job"
  display_name = "DB Schema Job - ${var.sponsor} ${var.environment}"
  description  = "Service account for Cloud Run Job that applies database schema"
}

# Grant Cloud SQL Client role to connect via Auth Proxy
resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.schema_job.email}"
}

# Grant Secret Manager access for DB password
resource "google_secret_manager_secret_iam_member" "db_password_access" {
  count     = var.db_password_secret_id != "" ? 1 : 0
  project   = var.project_id
  secret_id = var.db_password_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.schema_job.email}"
}

# Grant Cloud Storage access for schema file (if using GCS)
resource "google_storage_bucket_iam_member" "schema_bucket_access" {
  count  = var.schema_bucket_name != "" ? 1 : 0
  bucket = var.schema_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.schema_job.email}"
}

# -----------------------------------------------------------------------------
# Cloud Storage Bucket for Schema Files
# -----------------------------------------------------------------------------

resource "google_storage_bucket" "schema_files" {
  count    = var.create_schema_bucket ? 1 : 0
  project  = var.project_id
  name     = "${var.project_id}-db-schema"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  labels = local.common_labels

  lifecycle_rule {
    condition {
      num_newer_versions = 10
    }
    action {
      type = "Delete"
    }
  }
}

# Upload schema file to bucket
resource "google_storage_bucket_object" "schema_file" {
  count  = var.create_schema_bucket && var.schema_file_content != "" ? 1 : 0
  name   = "init-consolidated.sql"
  bucket = google_storage_bucket.schema_files[0].name
  content = var.schema_file_content

  # Track changes via content hash
  metadata = {
    content_hash = md5(var.schema_file_content)
  }
}

# -----------------------------------------------------------------------------
# Cloud Run Job
# -----------------------------------------------------------------------------

resource "google_cloud_run_v2_job" "schema_job" {
  name     = local.job_name
  location = var.region
  project  = var.project_id

  labels = local.common_labels

  template {
    template {
      service_account = google_service_account.schema_job.email
      timeout         = "600s"  # 10 minutes max

      # VPC connector for private IP access
      vpc_access {
        connector = var.vpc_connector_id
        egress    = "PRIVATE_RANGES_ONLY"
      }

      volumes {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [var.db_connection_name]
        }
      }

      containers {
        name  = "schema-applier"
        image = var.schema_job_image

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }

        env {
          name  = "DB_HOST"
          value = "/cloudsql/${var.db_connection_name}"
        }

        env {
          name  = "DB_PORT"
          value = "5432"
        }

        env {
          name  = "DB_NAME"
          value = var.database_name
        }

        env {
          name  = "DB_USER"
          value = var.db_username
        }

        # DB password from Secret Manager
        dynamic "env" {
          for_each = var.db_password_secret_id != "" ? [1] : []
          content {
            name = "DB_PASSWORD"
            value_source {
              secret_key_ref {
                secret  = var.db_password_secret_id
                version = "latest"
              }
            }
          }
        }

        # Direct password (for non-secret-manager setups)
        dynamic "env" {
          for_each = var.db_password_secret_id == "" && var.db_password != "" ? [1] : []
          content {
            name  = "DB_PASSWORD"
            value = var.db_password
          }
        }

        env {
          name  = "SCHEMA_BUCKET"
          value = var.create_schema_bucket ? google_storage_bucket.schema_files[0].name : var.schema_bucket_name
        }

        env {
          name  = "SCHEMA_FILE"
          value = "init-consolidated.sql"
        }

        env {
          name  = "SPONSOR"
          value = var.sponsor
        }

        env {
          name  = "ENVIRONMENT"
          value = var.environment
        }

        volume_mounts {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      launch_stage,
    ]
  }

  depends_on = [
    google_project_iam_member.cloudsql_client,
  ]
}

# -----------------------------------------------------------------------------
# Execute Job on Schema Change (Optional)
# -----------------------------------------------------------------------------

resource "null_resource" "execute_schema_job" {
  count = var.auto_execute ? 1 : 0

  triggers = {
    schema_hash = var.schema_file_content != "" ? md5(var.schema_file_content) : ""
    job_name    = google_cloud_run_v2_job.schema_job.name
  }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud run jobs execute ${google_cloud_run_v2_job.schema_job.name} \
        --project=${var.project_id} \
        --region=${var.region} \
        --wait
    EOT
  }

  depends_on = [
    google_cloud_run_v2_job.schema_job,
    google_storage_bucket_object.schema_file,
  ]
}
