# modules/vpc-network/variables.tf

variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "callisto4-dev"
}

variable "sponsor" {
  description = "Sponsor name"
  type        = string
  default     = "callisto4"
}

variable "environment" {
  description = "Environment name (dev, qa, uat, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "qa", "uat", "prod"], var.environment)
    error_message = "Environment must be one of: dev, qa, uat, prod."
  }
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west9"
}

variable "app_subnet_cidr" {
  description = "CIDR for the main application subnet"
  type        = string
  default     = "10.0.3.0/24"
}

variable "db_subnet_cidr" {
  description = "CIDR for the database private service connection"
  type        = string
  default     = "10.0.2.0/24"
}

variable "connector_cidr" {
  description = "CIDR for the VPC Access Connector (must be /28)"
  type        = string
  default     = "10.0.1.0/28"

  validation {
    condition     = can(regex("/28$", var.connector_cidr))
    error_message = "VPC connector CIDR must be /28."
  }
}

variable "connector_min_instances" {
  description = "Minimum instances for VPC connector"
  type        = number
  default     = 2

  validation {
    condition     = var.connector_min_instances >= 2 && var.connector_min_instances <= 10
    error_message = "Connector min instances must be between 2 and 10."
  }
}

variable "connector_max_instances" {
  description = "Maximum instances for VPC connector"
  type        = number
  default     = 10

  validation {
    condition     = var.connector_max_instances >= 3 && var.connector_max_instances <= 10
    error_message = "Connector max instances must be between 3 and 10."
  }
}

variable "restrict_egress" {
  description = "Add firewall rule to deny all egress (Cloud Run has its own egress config)"
  type        = bool
  default     = false
}

variable "enable_proxy_only_subnet" {
  description = "Enable proxy-only subnet for Regional Load Balancer"
  type        = bool
  default     = false
}

variable "proxy_only_subnet_cidr" {
  description = "CIDR range for the proxy-only subnet (Regional Load Balancer). Required if enable_proxy_only_subnet is true. Must not overlap with app_subnet_cidr or db_subnet_cidr."
  type        = string
  default     = ""

  validation {
    condition     = var.proxy_only_subnet_cidr == "" || can(cidrhost(var.proxy_only_subnet_cidr, 0))
    error_message = "proxy_only_subnet_cidr must be empty or a valid CIDR notation."
  }
}
