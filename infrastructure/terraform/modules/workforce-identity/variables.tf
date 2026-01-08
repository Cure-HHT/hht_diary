# modules/workforce-identity/variables.tf

variable "enabled" {
  description = "Enable Workforce Identity Federation"
  type        = bool
  default     = false
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_org_id" {
  description = "GCP Organization ID"
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

variable "provider_type" {
  description = "Identity provider type (oidc or saml)"
  type        = string
  default     = "oidc"

  validation {
    condition     = contains(["oidc", "saml"], var.provider_type)
    error_message = "Provider type must be oidc or saml."
  }
}

# OIDC configuration
variable "oidc_issuer_uri" {
  description = "OIDC issuer URI (e.g., https://login.microsoftonline.com/{tenant}/v2.0)"
  type        = string
  default     = ""
}

variable "oidc_client_id" {
  description = "OIDC client ID"
  type        = string
  default     = ""
}

variable "oidc_client_secret" {
  description = "OIDC client secret"
  type        = string
  sensitive   = true
  default     = ""
}

# SAML configuration
variable "saml_idp_metadata_xml" {
  description = "SAML IdP metadata XML"
  type        = string
  default     = ""
}

# Access control
variable "allowed_email_domain" {
  description = "Only allow users with email from this domain"
  type        = string
  default     = ""
}

variable "cloud_run_service_name" {
  description = "Cloud Run service name to grant access to"
  type        = string
  default     = ""
}
