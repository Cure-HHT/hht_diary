# modules/regional-load-balancer/main.tf
#
# Creates a GCP Regional External HTTPS Load Balancer with:
# - Regional static IP (Standard network tier)
# - Proxy-only subnet for Envoy-based load balancers
# - DNS authorization for domain validation
# - Google-managed regional SSL certificate
# - Regional backend service, URL map, HTTPS proxy, and forwarding rule
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00008: Multi-sponsor deployment model
#   REQ-p00042: Infrastructure audit trail for FDA compliance

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
  }
}

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------

locals {
  lb_name_prefix = "${var.sponsor}-${var.environment}"

  common_labels = {
    sponsor     = var.sponsor
    environment = var.environment
    managed_by  = "terraform"
    compliance  = "fda-21-cfr-part-11"
  }
}

# -----------------------------------------------------------------------------
# Regional Static IP Address (Standard Network Tier)
# -----------------------------------------------------------------------------

resource "google_compute_address" "lb_ip" {
  name         = "${local.lb_name_prefix}-lb-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "STANDARD"
  description  = "Regional static IP for ${var.sponsor} ${var.environment} load balancer"
}

# -----------------------------------------------------------------------------
# DNS Authorization for Domain Validation
# -----------------------------------------------------------------------------

resource "google_certificate_manager_dns_authorization" "main" {
  name        = "${local.lb_name_prefix}-dns-auth"
  project     = var.project_id
  location    = var.region
  domain      = var.domain
  description = "DNS authorization for ${var.domain}"

  labels = local.common_labels
}

# -----------------------------------------------------------------------------
# Google-Managed Regional SSL Certificate
# -----------------------------------------------------------------------------

resource "google_certificate_manager_certificate" "main" {
  name        = "${local.lb_name_prefix}-cert"
  project     = var.project_id
  location    = var.region
  description = "Google-managed SSL certificate for ${var.domain}"

  managed {
    domains = [var.domain]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.main.id
    ]
  }

  labels = local.common_labels
}

# -----------------------------------------------------------------------------
# Regional Health Check
# -----------------------------------------------------------------------------
# Required for regional backend services. Creates a basic HTTP health check
# that can be customized via variables.

resource "google_compute_region_health_check" "main" {
  name    = "${local.lb_name_prefix}-health-check"
  project = var.project_id
  region  = var.region

  http_health_check {
    port               = var.health_check_port
    request_path       = var.health_check_path
    proxy_header       = "NONE"
    response           = ""
    port_specification = "USE_FIXED_PORT"
  }

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  log_config {
    enable = var.enable_logging
  }
}

# -----------------------------------------------------------------------------
# Serverless NEG for Cloud Run
# -----------------------------------------------------------------------------
# Creates a Network Endpoint Group that points to a Cloud Run service.
# This allows the regional load balancer to route traffic to Cloud Run.

resource "google_compute_region_network_endpoint_group" "cloud_run" {
  count = var.cloud_run_service_name != "" ? 1 : 0

  name                  = "${local.lb_name_prefix}-cloud-run-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.cloud_run_service_name
  }
}

# -----------------------------------------------------------------------------
# Regional Backend Service
# -----------------------------------------------------------------------------

resource "google_compute_region_backend_service" "main" {
  name                  = "${local.lb_name_prefix}-backend"
  project               = var.project_id
  region                = var.region
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = var.backend_timeout_sec
  description           = "Regional backend service for ${var.sponsor} ${var.environment}"

  # Health checks are not used with serverless NEGs (Cloud Run has its own health checks)
  # Only include health check if NOT using Cloud Run backend
  health_checks = var.cloud_run_service_name == "" ? [google_compute_region_health_check.main.id] : null

  # Attach Cloud Run NEG as backend if configured
  dynamic "backend" {
    for_each = var.cloud_run_service_name != "" ? [1] : []
    content {
      group           = google_compute_region_network_endpoint_group.cloud_run[0].id
      balancing_mode  = "UTILIZATION"
      capacity_scaler = 1.0
    }
  }

  log_config {
    enable      = var.enable_logging
    sample_rate = var.log_sample_rate
  }
}

# -----------------------------------------------------------------------------
# Regional URL Map
# -----------------------------------------------------------------------------

resource "google_compute_region_url_map" "main" {
  name            = "${local.lb_name_prefix}-url-map"
  project         = var.project_id
  region          = var.region
  default_service = google_compute_region_backend_service.main.id
  description     = "Regional URL map for ${var.sponsor} ${var.environment}"
}

# -----------------------------------------------------------------------------
# Regional Target HTTPS Proxy
# -----------------------------------------------------------------------------
# Note: For regional HTTPS proxies with Certificate Manager certificates,
# we must use the google-beta provider with certificate_manager_certificates.
# The ssl_certificates argument only works with Compute Engine SSL certificates.

resource "google_compute_region_target_https_proxy" "main" {
  provider = google-beta

  name    = "${local.lb_name_prefix}-https-proxy"
  project = var.project_id
  region  = var.region
  url_map = google_compute_region_url_map.main.id

  # Use certificate_manager_certificates for Certificate Manager certificates
  certificate_manager_certificates = [
    "//certificatemanager.googleapis.com/${google_certificate_manager_certificate.main.id}"
  ]
}

# -----------------------------------------------------------------------------
# Regional Forwarding Rule (Frontend)
# -----------------------------------------------------------------------------

resource "google_compute_forwarding_rule" "https" {
  name                  = "${local.lb_name_prefix}-https-forwarding-rule"
  project               = var.project_id
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network_tier          = "STANDARD"
  network               = var.vpc_network_self_link
  ip_address            = google_compute_address.lb_ip.id
  port_range            = "443"
  target                = google_compute_region_target_https_proxy.main.id
  description           = "HTTPS forwarding rule for ${var.sponsor} ${var.environment}"

  # Note: The proxy-only subnet must exist before the forwarding rule.
  # It is created by the vpc-network module and passed via proxy_only_subnet_id.
}

# -----------------------------------------------------------------------------
# Optional: HTTP to HTTPS Redirect
# -----------------------------------------------------------------------------

resource "google_compute_region_url_map" "http_redirect" {
  count = var.enable_http_redirect ? 1 : 0

  name    = "${local.lb_name_prefix}-http-redirect"
  project = var.project_id
  region  = var.region

  default_url_redirect {
    https_redirect         = true
    strip_query            = false
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
  }
}

resource "google_compute_region_target_http_proxy" "http_redirect" {
  count = var.enable_http_redirect ? 1 : 0

  name    = "${local.lb_name_prefix}-http-proxy"
  project = var.project_id
  region  = var.region
  url_map = google_compute_region_url_map.http_redirect[0].id
}

resource "google_compute_forwarding_rule" "http_redirect" {
  count = var.enable_http_redirect ? 1 : 0

  name                  = "${local.lb_name_prefix}-http-forwarding-rule"
  project               = var.project_id
  region                = var.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network_tier          = "STANDARD"
  network               = var.vpc_network_self_link
  ip_address            = google_compute_address.lb_ip.id
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.http_redirect[0].id
  description           = "HTTP to HTTPS redirect for ${var.sponsor} ${var.environment}"
}
