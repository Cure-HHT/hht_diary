# modules/cloud-sql/main.tf
#
# Creates Cloud SQL PostgreSQL 17 instance with pgaudit and FDA compliance settings
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00042: Infrastructure audit trail for FDA compliance

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------

locals {
  instance_name = "${var.sponsor}-${var.environment}-db"
  is_production = var.environment == "prod"

  # Environment-specific defaults
  db_tier = var.db_tier != "" ? var.db_tier : (
    local.is_production ? "db-custom-2-8192" : (
      var.environment == "uat" ? "db-custom-1-3840" : "db-f1-micro"
    )
  )

  availability_type = local.is_production ? "REGIONAL" : "ZONAL"

  disk_size = var.disk_size > 0 ? var.disk_size : (
    local.is_production ? 100 : (var.environment == "uat" ? 20 : 10)
  )

  disk_autoresize_limit = local.is_production ? 500 : (var.environment == "uat" ? 100 : 50)

  backup_retention = local.is_production ? 30 : (var.environment == "uat" ? 14 : 7)

  common_labels = {
    sponsor     = var.sponsor
    environment = var.environment
    managed_by  = "terraform"
    compliance  = "fda-21-cfr-part-11"
  }
}

# -----------------------------------------------------------------------------
# Random suffix for instance name (Cloud SQL names are globally unique)
# -----------------------------------------------------------------------------

resource "random_id" "db_suffix" {
  byte_length = 2
}

# -----------------------------------------------------------------------------
# Cloud SQL Instance
# -----------------------------------------------------------------------------

resource "google_sql_database_instance" "main" {
  name                = "${local.instance_name}-${random_id.db_suffix.hex}"
  database_version    = "POSTGRES_17"
  region              = var.region
  project             = var.project_id
  deletion_protection = local.is_production

  settings {
    tier              = local.db_tier
    availability_type = local.availability_type
    disk_type         = "PD_SSD"
    disk_size         = local.disk_size
    disk_autoresize   = true
    disk_autoresize_limit = local.disk_autoresize_limit

    user_labels = local.common_labels

    # Network configuration - private IP only
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.vpc_network_id
      enable_private_path_for_google_cloud_services = true
      require_ssl                                   = true
    }

    # Backup configuration
    backup_configuration {
      enabled                        = true
      start_time                     = "02:00"
      location                       = var.region
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = local.backup_retention
        retention_unit   = "COUNT"
      }
    }

    # Maintenance window
    maintenance_window {
      day          = 7 # Sunday
      hour         = 4 # 4 AM UTC
      update_track = local.is_production ? "stable" : "canary"
    }

    # FDA compliance database flags
    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }

    database_flags {
      name  = "log_min_duration_statement"
      value = "1000" # Log queries > 1 second
    }

    # Query insights for performance monitoring
    insights_config {
      query_insights_enabled  = true
      query_plans_per_minute  = 5
      query_string_length     = 4096
      record_application_tags = true
      record_client_address   = true
    }

    # Deny maintenance period (optional - for production stability)
    dynamic "deny_maintenance_period" {
      for_each = local.is_production ? [1] : []
      content {
        start_date = "2024-12-20"
        end_date   = "2025-01-05"
        time       = "00:00:00"
      }
    }
  }

  depends_on = [var.private_vpc_connection]

  lifecycle {
    prevent_destroy = false
  }
}

# -----------------------------------------------------------------------------
# Database
# -----------------------------------------------------------------------------

resource "google_sql_database" "main" {
  name     = var.database_name
  instance = google_sql_database_instance.main.name
  project  = var.project_id
  charset  = "UTF8"
  collation = "en_US.UTF8"
}

# -----------------------------------------------------------------------------
# Database User
# -----------------------------------------------------------------------------

resource "google_sql_user" "app_user" {
  name     = var.db_username
  instance = google_sql_database_instance.main.name
  project  = var.project_id
  password = var.db_password
  type     = "BUILT_IN"

  deletion_policy = "ABANDON"
}
