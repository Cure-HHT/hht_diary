# admin-project/providers.tf
#
# Provider configuration for admin project
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment

provider "google" {
  project = var.project_id
  region  = var.region
}
