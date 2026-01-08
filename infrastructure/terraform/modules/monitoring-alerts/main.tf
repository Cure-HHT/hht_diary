# modules/monitoring-alerts/main.tf
#
# Creates monitoring alerts for Cloud Run and Cloud SQL
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
  alert_prefix = "${var.sponsor}-${var.environment}"

  common_labels = {
    sponsor     = var.sponsor
    environment = var.environment
    managed_by  = "terraform"
  }
}

# -----------------------------------------------------------------------------
# Uptime Check - Portal Health
# -----------------------------------------------------------------------------

resource "google_monitoring_uptime_check_config" "portal" {
  display_name = "${local.alert_prefix}-portal-uptime"
  project      = var.project_id
  timeout      = "10s"
  period       = "60s"

  http_check {
    path           = "/health"
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"

    accepted_response_status_codes {
      status_class = "STATUS_CLASS_2XX"
    }
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = replace(var.portal_url, "https://", "")
    }
  }

  content_matchers {
    content = "OK"
    matcher = "CONTAINS_STRING"
  }
}

# -----------------------------------------------------------------------------
# Alert Policy - Cloud Run Error Rate
# -----------------------------------------------------------------------------

resource "google_monitoring_alert_policy" "cloud_run_errors" {
  display_name = "${local.alert_prefix}-cloud-run-error-rate"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Cloud Run Error Rate > 5%"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloud_run_revision"
        AND resource.labels.project_id = "${var.project_id}"
        AND metric.type = "run.googleapis.com/request_count"
        AND metric.labels.response_code_class != "2xx"
      EOT

      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.05

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.service_name"]
      }

      trigger {
        count = 1
      }
    }
  }

  alert_strategy {
    auto_close = "1800s" # 30 minutes
  }

  documentation {
    content   = <<-EOT
      ## Cloud Run Error Rate Alert

      The error rate for Cloud Run services in ${var.sponsor} ${var.environment} has exceeded 5%.

      ### Troubleshooting Steps

      1. Check Cloud Run logs: `gcloud logging read "resource.type=cloud_run_revision" --project=${var.project_id}`
      2. Check recent deployments
      3. Verify database connectivity
      4. Check upstream dependencies
    EOT
    mime_type = "text/markdown"
  }

  user_labels = local.common_labels

  notification_channels = var.notification_channels
}

# -----------------------------------------------------------------------------
# Alert Policy - Cloud SQL CPU
# -----------------------------------------------------------------------------

resource "google_monitoring_alert_policy" "db_cpu" {
  display_name = "${local.alert_prefix}-db-cpu-high"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Cloud SQL CPU > 80%"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloudsql_database"
        AND resource.labels.project_id = "${var.project_id}"
        AND metric.type = "cloudsql.googleapis.com/database/cpu/utilization"
      EOT

      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }

      trigger {
        count = 1
      }
    }
  }

  alert_strategy {
    auto_close = "3600s" # 1 hour
  }

  documentation {
    content   = <<-EOT
      ## Cloud SQL High CPU Alert

      The Cloud SQL CPU utilization in ${var.sponsor} ${var.environment} has exceeded 80%.

      ### Troubleshooting Steps

      1. Check active queries: Connect to DB and run `SELECT * FROM pg_stat_activity WHERE state = 'active';`
      2. Review slow queries in Query Insights
      3. Consider scaling up the instance tier
      4. Check for long-running transactions
    EOT
    mime_type = "text/markdown"
  }

  user_labels = local.common_labels

  notification_channels = var.notification_channels
}

# -----------------------------------------------------------------------------
# Alert Policy - Cloud SQL Storage
# -----------------------------------------------------------------------------

resource "google_monitoring_alert_policy" "db_storage" {
  display_name = "${local.alert_prefix}-db-storage-high"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Cloud SQL Disk Usage > 80%"

    condition_threshold {
      filter = <<-EOT
        resource.type = "cloudsql_database"
        AND resource.labels.project_id = "${var.project_id}"
        AND metric.type = "cloudsql.googleapis.com/database/disk/utilization"
      EOT

      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }

      trigger {
        count = 1
      }
    }
  }

  alert_strategy {
    auto_close = "3600s" # 1 hour
  }

  documentation {
    content   = <<-EOT
      ## Cloud SQL High Disk Usage Alert

      The Cloud SQL disk utilization in ${var.sponsor} ${var.environment} has exceeded 80%.

      ### Troubleshooting Steps

      1. Check database size: `SELECT pg_size_pretty(pg_database_size('clinical_diary'));`
      2. Check table sizes: `SELECT relname, pg_size_pretty(pg_total_relation_size(relid)) FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC;`
      3. Consider enabling disk auto-resize
      4. Archive old data if appropriate
    EOT
    mime_type = "text/markdown"
  }

  user_labels = local.common_labels

  notification_channels = var.notification_channels
}

# -----------------------------------------------------------------------------
# Alert Policy - Uptime Check Failed
# -----------------------------------------------------------------------------

resource "google_monitoring_alert_policy" "uptime_failed" {
  display_name = "${local.alert_prefix}-portal-down"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Portal Uptime Check Failed"

    condition_threshold {
      filter = <<-EOT
        resource.type = "uptime_url"
        AND metric.type = "monitoring.googleapis.com/uptime_check/check_passed"
        AND metric.labels.check_id = "${google_monitoring_uptime_check_config.portal.uptime_check_id}"
      EOT

      duration        = "300s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_FRACTION_TRUE"
        cross_series_reducer = "REDUCE_MEAN"
      }

      trigger {
        count = 1
      }
    }
  }

  alert_strategy {
    auto_close = "1800s" # 30 minutes
  }

  documentation {
    content   = <<-EOT
      ## Portal Down Alert

      The portal uptime check for ${var.sponsor} ${var.environment} is failing.

      ### Troubleshooting Steps

      1. Check Cloud Run service status
      2. Check recent deployments
      3. Verify DNS configuration
      4. Check SSL certificate validity
    EOT
    mime_type = "text/markdown"
  }

  user_labels = local.common_labels

  notification_channels = var.notification_channels
}
