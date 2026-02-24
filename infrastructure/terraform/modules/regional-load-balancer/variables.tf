# modules/regional-load-balancer/variables.tf
#
# Input variables for Regional Load Balancer module
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00008: Multi-sponsor deployment model

# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "sponsor" {
  description = "Sponsor name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, qa, uat, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "qa", "uat", "prod"], var.environment)
    error_message = "Environment must be one of: dev, qa, uat, prod."
  }
}

variable "region" {
  description = "GCP region for the regional load balancer"
  type        = string
}

variable "domain" {
  description = "Domain name for SSL certificate (e.g., portal.sponsor.example.com)"
  type        = string
}

variable "proxy_only_subnet_id" {
  description = "ID of the proxy-only subnet (created by vpc-network module). Required for Regional Load Balancer forwarding rules."
  type        = string
}

variable "vpc_network_self_link" {
  description = "Self link of the VPC network for the forwarding rules"
  type        = string
}

variable "proxy_only_subnet_cidr" {
  description = "CIDR range of the proxy-only subnet (informational, for documentation)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Optional Variables
# -----------------------------------------------------------------------------

variable "backend_timeout_sec" {
  description = "Backend service timeout in seconds"
  type        = number
  default     = 30
}

variable "health_check_port" {
  description = "Port for health check requests"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Path for health check requests"
  type        = string
  default     = "/"
}

variable "enable_logging" {
  description = "Enable logging for the backend service"
  type        = bool
  default     = true
}

variable "log_sample_rate" {
  description = "Sampling rate for backend service logs (0.0 to 1.0)"
  type        = number
  default     = 1.0

  validation {
    condition     = var.log_sample_rate >= 0.0 && var.log_sample_rate <= 1.0
    error_message = "log_sample_rate must be between 0.0 and 1.0."
  }
}

variable "enable_http_redirect" {
  description = "Create HTTP to HTTPS redirect forwarding rule"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Cloud Run Backend Configuration
# -----------------------------------------------------------------------------

variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service to route traffic to (e.g., 'portal-server'). If empty, no backend is configured."
  type        = string
  default     = ""
}
