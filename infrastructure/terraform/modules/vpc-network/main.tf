# modules/vpc-network/main.tf
#
# Creates VPC network with private connectivity for Cloud SQL and Cloud Run
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
# Local Variables
# -----------------------------------------------------------------------------

locals {
  network_name   = "${var.sponsor}-${var.environment}-vpc"
  subnet_name    = "${var.sponsor}-${var.environment}-subnet"
  connector_name = "${var.sponsor}-${var.environment}-vpc-con"

  common_labels = {
    sponsor     = var.sponsor
    environment = var.environment
    managed_by  = "terraform"
    compliance  = "fda-21-cfr-part-11"
  }
}

# -----------------------------------------------------------------------------
# VPC Network
# -----------------------------------------------------------------------------

resource "google_compute_network" "vpc" {
  name                    = local.network_name
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "VPC network for ${var.sponsor} ${var.environment}"
}

# -----------------------------------------------------------------------------
# Application Subnet
# -----------------------------------------------------------------------------

resource "google_compute_subnetwork" "app_subnet" {
  name                     = local.subnet_name
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.app_subnet_cidr
  private_ip_google_access = true
  description              = "Main subnet for ${var.sponsor} ${var.environment}"

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# -----------------------------------------------------------------------------
# Private Service Connection for Cloud SQL
# -----------------------------------------------------------------------------

resource "google_compute_global_address" "private_ip_range" {
  name          = "${var.sponsor}-${var.environment}-private-ip-range"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = tonumber(split("/", var.db_subnet_cidr)[1])
  network       = google_compute_network.vpc.id
  address       = split("/", var.db_subnet_cidr)[0]
  description   = "Private IP range for Cloud SQL"
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]

  deletion_policy = "ABANDON"
}

# -----------------------------------------------------------------------------
# Serverless VPC Access Connector
# -----------------------------------------------------------------------------

resource "google_vpc_access_connector" "cldrun" {
  name          = local.connector_name
  project       = var.project_id
  region        = var.region
  ip_cidr_range = var.connector_cidr
  network       = google_compute_network.vpc.name

  # Autoscaling settings based on instances not throughput for simplicity.
  # TODO tune based on expected load.
  # min_instances = var.connector_min_instances
  # max_instances = var.connector_max_instances

  # TODO enable throughput scaling based on environment.
  # min_throughput = 200
  # max_throughput = var.environment == "prod" ? 1000 : 300
  max_throughput = 1000

  depends_on = [google_compute_network.vpc]
}

# -----------------------------------------------------------------------------
# Firewall Rules
# -----------------------------------------------------------------------------

# Allow internal communication
resource "google_compute_firewall" "allow_internal" {
  name    = "${local.network_name}-allow-internal"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [var.app_subnet_cidr, var.db_subnet_cidr]
  description   = "Allow internal communication within VPC"
}

# Allow health checks from Google
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${local.network_name}-allow-health-checks"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }

  # Google health check ranges
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  description   = "Allow Google health checks"
}

# Deny all egress by default (except for Cloud Run which has its own config)
resource "google_compute_firewall" "deny_all_egress" {
  count = var.restrict_egress ? 1 : 0

  name      = "${local.network_name}-deny-all-egress"
  project   = var.project_id
  network   = google_compute_network.vpc.name
  direction = "EGRESS"
  priority  = 65534

  deny {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
  description        = "Deny all egress (Cloud Run uses VPC connector)"
}
