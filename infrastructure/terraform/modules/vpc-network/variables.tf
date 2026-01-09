# modules/vpc-network/variables.tf

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
  description = "GCP region"
  type        = string
  default     = "europe-west9"
}

variable "app_subnet_cidr" {
  description = "CIDR for the main application subnet"
  type        = string
}

variable "db_subnet_cidr" {
  description = "CIDR for the database private service connection"
  type        = string
}

variable "connector_cidr" {
  description = "CIDR for the VPC Access Connector (must be /28)"
  type        = string

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
