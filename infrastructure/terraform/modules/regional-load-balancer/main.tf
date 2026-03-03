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

  # For wildcard certificates (*.example.com), DNS authorization must use
  # the parent domain (example.com). Strip the "*." prefix if present.
  dns_auth_domain = trimprefix(var.domain, "*.")

  # Short domain hash ensures GCP resource names change when the domain
  # changes, allowing create_before_destroy to work without name collisions.
  domain_hash = substr(md5(var.domain), 0, 8)

  common_labels = {
    sponsor     = var.sponsor
    environment = var.environment
    managed_by  = "terraform"
    compliance  = "fda-21-cfr-part-11"
  }

  # Determine default backend service for the URL map.
  # Uses explicit override if set, otherwise picks the alphabetically first service.
  default_service_key = var.default_cloud_run_service != "" ? var.default_cloud_run_service : (
    length(var.cloud_run_services) > 0 ? sort(keys(var.cloud_run_services))[0] : ""
  )
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
  name        = "${local.lb_name_prefix}-dns-auth-${local.domain_hash}"
  project     = var.project_id
  location    = var.region
  domain      = local.dns_auth_domain
  description = "DNS authorization for ${local.dns_auth_domain}"

  labels = local.common_labels

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Google-Managed Regional SSL Certificate
# -----------------------------------------------------------------------------

resource "google_certificate_manager_certificate" "main" {
  name        = "${local.lb_name_prefix}-cert-${local.domain_hash}"
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

  lifecycle {
    create_before_destroy = true
  }
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
# One-time migration: moved blocks for single-service → multi-service refactor.
# These tell Terraform the old resources were renamed, not destroyed+recreated.
# Safe to remove after the first successful apply of each environment.
# -----------------------------------------------------------------------------

moved {
  from = google_compute_region_network_endpoint_group.cloud_run[0]
  to   = google_compute_region_network_endpoint_group.cloud_run["portal-server"]
}

moved {
  from = google_compute_region_backend_service.main
  to   = google_compute_region_backend_service.services["portal-server"]
}

# -----------------------------------------------------------------------------
# Serverless NEGs for Cloud Run (one per service)
# -----------------------------------------------------------------------------
# Creates a Network Endpoint Group for each Cloud Run service.
# This allows the regional load balancer to route traffic to multiple
# Cloud Run services via host-based routing in the URL map.

resource "google_compute_region_network_endpoint_group" "cloud_run" {
  for_each = var.cloud_run_services

  name                  = "${local.lb_name_prefix}-${each.key}-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = each.key
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Regional Backend Services (one per Cloud Run service)
# -----------------------------------------------------------------------------

resource "google_compute_region_backend_service" "services" {
  for_each = var.cloud_run_services

  name                  = "${local.lb_name_prefix}-${each.key}-backend"
  project               = var.project_id
  region                = var.region
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = var.backend_timeout_sec
  description           = "Backend for ${each.key} in ${var.sponsor} ${var.environment}"

  # Cloud Run has its own health checks; serverless NEGs do not use external health checks
  health_checks = null

  backend {
    group           = google_compute_region_network_endpoint_group.cloud_run[each.key].id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  log_config {
    enable      = var.enable_logging
    sample_rate = var.log_sample_rate
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Regional URL Map (host-based routing)
# -----------------------------------------------------------------------------
# Routes requests to the appropriate backend service based on the Host header.
# Each Cloud Run service is mapped to one or more hostnames.

resource "google_compute_region_url_map" "main" {
  name            = "${local.lb_name_prefix}-url-map"
  project         = var.project_id
  region          = var.region
  default_service = google_compute_region_backend_service.services[local.default_service_key].id
  description     = "Regional URL map for ${var.sponsor} ${var.environment}"

  dynamic "host_rule" {
    for_each = var.cloud_run_services
    content {
      hosts        = host_rule.value.hosts
      path_matcher = host_rule.key
    }
  }

  dynamic "path_matcher" {
    for_each = var.cloud_run_services
    content {
      name            = path_matcher.key
      default_service = google_compute_region_backend_service.services[path_matcher.key].id
    }
  }
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
