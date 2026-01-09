# bootstrap/providers.tf
#
# Google Cloud provider configuration

provider "google" {
  region = var.default_region
}

provider "google-beta" {
  region = var.default_region
}
