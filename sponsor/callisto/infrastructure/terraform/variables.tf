# Callisto Terraform Variables

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production"
  }
}

variable "enable_object_lock" {
  description = "Enable S3 Object Lock (WORM) for FDA compliance"
  type        = bool
  default     = false  # Set to true for production after initial setup
}

variable "create_cicd_user" {
  description = "Create IAM user for CI/CD (recommended: use GitHub Actions OIDC instead)"
  type        = bool
  default     = false
}
