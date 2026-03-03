# modules/billing-stop-funk/main.tf
#
# Encapsulates a billing-stop Cloud Function (2nd gen) that disables billing
# for the project when budget spend exceeds a configurable threshold (default
# 45%).  The function receives alerts via a Pub/Sub push subscription and
# calls the Cloud Billing API to unlink the billing account from the project.
#
# The function has its own dedicated service account with only the permissions
# required for the billing-unlinking operation (principle of least privilege).
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00001: Automated cost-control billing alerts
#   REQ-o00056: IaC for portal deployment
#

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}

locals {
  function_name = "${var.sponsor}-${var.environment}-billing-stop"

  common_labels = {
    sponsor     = var.sponsor
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "cost-control"
  }
}

# -----------------------------------------------------------------------------
# Enable Required APIs
# -----------------------------------------------------------------------------

resource "google_project_service" "required_apis" {
  for_each = toset([
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "pubsub.googleapis.com",
    "logging.googleapis.com",
    "cloudbilling.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# Dedicated Service Account
#
# This function always creates its own SA to guarantee isolation from the
# billing-alert function and any other workloads.
# -----------------------------------------------------------------------------

resource "google_service_account" "function" {
  account_id   = "${var.sponsor}-${var.environment}-bill-stop-fn"
  display_name = "Budget Stop Function – ${var.sponsor} ${var.environment}"
  project      = var.project_id

  depends_on = [google_project_service.required_apis]
}

# Ensure the Cloud Build service agent exists before granting it IAM bindings.
# Enabling the API provisions the agent asynchronously; this resource waits
# for that provisioning to complete.
resource "google_project_service_identity" "cloudbuild" {
  provider = google-beta
  project  = var.project_id
  service  = "cloudbuild.googleapis.com"

  depends_on = [google_project_service.required_apis]
}

# Cloud Build service agent permissions for building the function container
resource "google_project_iam_member" "cloudbuild_roles" {
  for_each = toset([
    "roles/logging.logWriter",       # Write build logs
    "roles/artifactregistry.writer", # Push built container image
    "roles/storage.objectViewer",    # Read function source from GCS
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_project_service_identity.cloudbuild.email}"
}

# Allow Cloud Build to act as the function's service account during deployment
resource "google_service_account_iam_member" "cloudbuild_act_as" {
  service_account_id = google_service_account.function.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_project_service_identity.cloudbuild.email}"
}

# -----------------------------------------------------------------------------
# IAM Bindings – Least-Privilege
#
# The function SA receives ONLY the roles it needs:
#   - billing.projectManager  : unlink the billing account from the project
#   - logging.logWriter       : write function execution logs
#   - artifactregistry.writer : push the built container image (deployment)
#   - storage.objectViewer    : read source archive from GCS   (deployment)
#
# Notably absent vs billing-alert-funk:
#   - roles/run.admin              (not needed – Cloud Build agent handles it)
#   - roles/compute.instanceAdmin  (not needed – no VM management)
# -----------------------------------------------------------------------------

resource "google_project_iam_member" "function_roles" {
  for_each = toset([
    "roles/billing.projectManager",  # Unlink billing account from project
    "roles/logging.logWriter",       # Write function + build logs
    "roles/artifactregistry.writer", # Push built container (deployment)
    "roles/storage.objectViewer",    # Read source from GCS (deployment)
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.function.email}"
}

# Allow the SA to invoke the Cloud Function (Cloud Run backing service)
resource "google_cloud_run_v2_service_iam_member" "function_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloudfunctions2_function.billing_stop.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.function.email}"
}

# The Pub/Sub service agent must be able to mint OIDC tokens for push auth
resource "google_project_iam_member" "pubsub_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# If dead-letter is enabled the Pub/Sub service agent needs publish rights
resource "google_pubsub_topic_iam_member" "dead_letter_publisher" {
  count   = var.enable_dead_letter ? 1 : 0
  project = var.project_id
  topic   = google_pubsub_topic.dead_letter[0].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_subscription_iam_member" "dead_letter_subscriber" {
  count        = var.enable_dead_letter ? 1 : 0
  project      = var.project_id
  subscription = google_pubsub_subscription.dead_letter[0].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# -----------------------------------------------------------------------------
# IAM Propagation Delay
# GCP IAM is eventually consistent; grants must propagate before Cloud Build
# can read from the internal gcf-v2-sources bucket during function deployment.
# -----------------------------------------------------------------------------

resource "time_sleep" "iam_propagation" {
  create_duration = "60s"

  depends_on = [
    google_project_iam_member.function_roles,
    google_project_iam_member.cloudbuild_roles,
    google_service_account_iam_member.cloudbuild_act_as,
  ]
}

# -----------------------------------------------------------------------------
# Function Source (zip → GCS)
# -----------------------------------------------------------------------------

resource "google_storage_bucket" "function_source" {
  name                        = "${var.project_id}-billing-stop-fn-source"
  location                    = var.region
  project                     = var.project_id
  uniform_bucket_level_access = true
  force_destroy               = true

  labels = local.common_labels
}

data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = var.function_source_dir
  output_path = "${path.module}/tmp/billing_stop.zip"
}

resource "google_storage_bucket_object" "function_source" {
  name   = "billing-stop-${data.archive_file.function_zip.output_md5}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.function_zip.output_path
}

# -----------------------------------------------------------------------------
# Cloud Function (2nd Gen – HTTP triggered, invoked via push subscription)
# -----------------------------------------------------------------------------

resource "google_cloudfunctions2_function" "billing_stop" {
  name     = local.function_name
  location = var.region
  project  = var.project_id

  labels = local.common_labels

  build_config {
    runtime         = "python312"
    entry_point     = "handle_billing_stop"
    service_account = "projects/${var.project_id}/serviceAccounts/${google_service_account.function.email}"

    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.function_source.name
      }
    }
  }

  service_config {
    available_memory   = var.function_memory
    timeout_seconds    = var.function_timeout
    min_instance_count = 0
    max_instance_count = 1

    service_account_email = google_service_account.function.email

    environment_variables = {
      GOOGLE_CLOUD_PROJECT = var.project_id
      THRESHOLD_CUTOFF     = tostring(var.threshold_cutoff)
      SLACK_WEBHOOK_URL    = var.slack_webhook_url
    }
  }

  # No event_trigger – the push subscription below drives invocations.

  depends_on = [
    google_project_service.required_apis,
    google_project_iam_member.function_roles,
    google_project_iam_member.pubsub_token_creator,
    google_project_iam_member.cloudbuild_roles,
    google_service_account_iam_member.cloudbuild_act_as,
    time_sleep.iam_propagation,
  ]
}

# -----------------------------------------------------------------------------
# Dead-Letter Topic (optional)
# -----------------------------------------------------------------------------

resource "google_pubsub_topic" "dead_letter" {
  count   = var.enable_dead_letter ? 1 : 0
  name    = "${var.sponsor}-${var.environment}-billing-stop-dlq"
  project = var.project_id

  labels = merge(local.common_labels, { purpose = "dead-letter" })

  depends_on = [google_project_service.required_apis]
}

# Pull subscription on the DLQ so failed messages can be inspected
resource "google_pubsub_subscription" "dead_letter" {
  count   = var.enable_dead_letter ? 1 : 0
  name    = "${var.sponsor}-${var.environment}-billing-stop-dlq-sub"
  topic   = google_pubsub_topic.dead_letter[0].name
  project = var.project_id

  ack_deadline_seconds       = 60
  message_retention_duration = var.message_retention

  labels = merge(local.common_labels, { purpose = "dead-letter" })

  depends_on = [google_project_service.required_apis]
}

# -----------------------------------------------------------------------------
# Pub/Sub Push Subscription (budget topic → Cloud Function)
# -----------------------------------------------------------------------------

resource "google_pubsub_subscription" "billing_stop" {
  name    = "${var.sponsor}-${var.environment}-billing-stop-push"
  topic   = var.budget_alert_topic_id
  project = var.project_id

  ack_deadline_seconds       = var.ack_deadline_seconds
  message_retention_duration = var.message_retention
  retain_acked_messages      = false

  push_config {
    push_endpoint = google_cloudfunctions2_function.billing_stop.service_config[0].uri

    oidc_token {
      service_account_email = google_service_account.function.email
    }
  }

  dynamic "dead_letter_policy" {
    for_each = var.enable_dead_letter ? [1] : []
    content {
      dead_letter_topic     = google_pubsub_topic.dead_letter[0].id
      max_delivery_attempts = var.max_delivery_attempts
    }
  }

  retry_policy {
    minimum_backoff = var.min_retry_backoff
    maximum_backoff = var.max_retry_backoff
  }

  labels = local.common_labels

  depends_on = [
    google_project_service.required_apis,
    google_cloud_run_v2_service_iam_member.function_invoker,
  ]
}

# -----------------------------------------------------------------------------
# Logging – Log-based metric for function errors
# -----------------------------------------------------------------------------

resource "google_logging_metric" "function_errors" {
  count   = var.enable_logging_metric ? 1 : 0
  name    = "${local.function_name}-errors"
  project = var.project_id

  filter = <<-EOT
    resource.type="cloud_run_revision"
    resource.labels.service_name="${google_cloudfunctions2_function.billing_stop.name}"
    severity>=ERROR
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"

    display_name = "Billing stop function errors"

    labels {
      key         = "severity"
      value_type  = "STRING"
      description = "Log entry severity level"
    }
  }

  label_extractors = {
    "severity" = "EXTRACT(severity)"
  }
}

# Subscription-level logging (message delivery status)
resource "google_project_iam_audit_config" "pubsub_audit" {
  count   = var.enable_pubsub_audit_logs ? 1 : 0
  project = var.project_id
  service = "pubsub.googleapis.com"

  audit_log_config {
    log_type = "DATA_WRITE"
  }

  audit_log_config {
    log_type = "DATA_READ"
  }
}
