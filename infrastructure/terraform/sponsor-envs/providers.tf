# sponsor-envs/providers.tf
#
# Google Cloud provider configuration using SA impersonation.
# The caller (e.g. tom@anspar.org) must have
# roles/iam.serviceAccountTokenCreator on the target SA.

# 1. "Bootstrap" provider – uses the caller's own credentials (ADC / gcloud)
#    solely to mint a short-lived token for the per-environment Terraform SA.
provider "google" {
  alias                 = "impersonation"
  project               = var.project_id
  user_project_override = true
  billing_project       = var.project_id
  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/userinfo.email",
  ]
}

# 2. Fetch a short-lived access token for the per-environment Terraform SA
data "google_service_account_access_token" "default" {
  provider               = google.impersonation
  target_service_account = "terraform-sa@${var.project_id}.iam.gserviceaccount.com"
  scopes                 = ["cloud-platform"]
  lifetime               = "1200s"
}

# 3. Main providers – all resources use the impersonated SA token
provider "google" {
  project               = var.project_id
  region                = var.region
  access_token          = data.google_service_account_access_token.default.access_token
  user_project_override = true
  billing_project       = var.project_id
}

provider "google-beta" {
  project               = var.project_id
  region                = var.region
  access_token          = data.google_service_account_access_token.default.access_token
  user_project_override = true
  billing_project       = var.project_id
}
