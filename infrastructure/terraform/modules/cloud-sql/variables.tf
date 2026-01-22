# modules/cloud-sql/variables.tf

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

variable "vpc_network_id" {
  description = "VPC network ID for private IP"
  type        = string
  default     = "projects/callisto4-dev/global/networks/callisto4-dev-vpc"
}

variable "private_vpc_connection" {
  description = "Private VPC connection resource (for depends_on)"
  type        = string
  default     = "projects/callisto4-dev/locations/europe-west9/connectors/callisto4-dev-vpc-con"
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "callisto4_dev_db"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "app_user"
}

variable "DB_PASSWORD" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_tier" {
  description = "Cloud SQL instance tier (leave empty for environment defaults)"
  type        = string
  default     = ""
}

variable "edition" {
  description = "PostgreSQL edition (leave empty for environment defaults)"
  type        = string
  default     = ""
}

variable "disk_size" {
  description = "Initial disk size in GB (0 = use environment default)"
  type        = number
  default     = 0
}
