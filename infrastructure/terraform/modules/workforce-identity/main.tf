# modules/workforce-identity/main.tf
#
# Creates Workforce Identity Federation for sponsor SSO
# Allows sponsor employees to access the portal via their corporate IdP
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
  pool_id     = "${var.sponsor}-${var.environment}-workforce"
  provider_id = "${var.sponsor}-${var.environment}-idp"
}

# -----------------------------------------------------------------------------
# Workforce Identity Pool
# -----------------------------------------------------------------------------

resource "google_iam_workforce_pool" "main" {
  count = var.enabled ? 1 : 0

  workforce_pool_id = local.pool_id
  parent            = "organizations/${var.gcp_org_id}"
  location          = "global"
  display_name      = "${title(var.sponsor)} ${upper(var.environment)} Workforce Pool"
  description       = "Workforce Identity Pool for ${var.sponsor} ${var.environment} users"

  session_duration = "3600s" # 1 hour

  # Disable pool instead of delete to preserve audit history
  disabled = false
}

# -----------------------------------------------------------------------------
# OIDC Provider (Azure AD, Okta, Google Workspace, etc.)
# -----------------------------------------------------------------------------

resource "google_iam_workforce_pool_provider" "oidc" {
  count = var.enabled && var.provider_type == "oidc" ? 1 : 0

  workforce_pool_id = google_iam_workforce_pool.main[0].workforce_pool_id
  location          = "global"
  provider_id       = local.provider_id
  display_name      = "${title(var.sponsor)} ${upper(var.environment)} OIDC Provider"
  description       = "OIDC identity provider for ${var.sponsor} ${var.environment}"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "google.display_name"  = "assertion.name"
    "attribute.email"      = "assertion.email"
    "attribute.department" = "assertion.department"
  }

  # Only allow users with verified email from the expected domain
  attribute_condition = var.allowed_email_domain != "" ? "assertion.email.endsWith('@${var.allowed_email_domain}')" : null

  oidc {
    issuer_uri = var.oidc_issuer_uri
    client_id  = var.oidc_client_id

    client_secret {
      value {
        plain_text = var.oidc_client_secret
      }
    }

    web_sso_config {
      response_type             = "CODE"
      assertion_claims_behavior = "MERGE_USER_INFO_OVER_ID_TOKEN_CLAIMS"
    }
  }
}

# -----------------------------------------------------------------------------
# SAML Provider (alternative to OIDC)
# -----------------------------------------------------------------------------

resource "google_iam_workforce_pool_provider" "saml" {
  count = var.enabled && var.provider_type == "saml" ? 1 : 0

  workforce_pool_id = google_iam_workforce_pool.main[0].workforce_pool_id
  location          = "global"
  provider_id       = local.provider_id
  display_name      = "${title(var.sponsor)} ${upper(var.environment)} SAML Provider"
  description       = "SAML identity provider for ${var.sponsor} ${var.environment}"

  attribute_mapping = {
    "google.subject"      = "assertion.subject"
    "google.display_name" = "assertion.attributes.displayName[0]"
    "attribute.email"     = "assertion.attributes.email[0]"
  }

  saml {
    idp_metadata_xml = var.saml_idp_metadata_xml
  }
}

# -----------------------------------------------------------------------------
# IAM - Grant Cloud Run Access to Workforce Users
# -----------------------------------------------------------------------------

resource "google_cloud_run_v2_service_iam_member" "workforce_invoker" {
  count = var.enabled && var.cloud_run_service_name != "" ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = var.cloud_run_service_name
  role     = "roles/run.invoker"

  member = "principalSet://iam.googleapis.com/${google_iam_workforce_pool.main[0].name}/*"
}
