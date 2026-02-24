# modules/regional-load-balancer/outputs.tf
#
# Outputs from Regional Load Balancer module
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment
#   REQ-p00008: Multi-sponsor deployment model

# -----------------------------------------------------------------------------
# Load Balancer IP Address
# -----------------------------------------------------------------------------

output "lb_ip_address" {
  description = "The external IP address of the load balancer"
  value       = google_compute_address.lb_ip.address
}

output "lb_ip_name" {
  description = "The name of the reserved IP address"
  value       = google_compute_address.lb_ip.name
}

# -----------------------------------------------------------------------------
# DNS Authorization (for Gandi.net CNAME record)
# -----------------------------------------------------------------------------

output "dns_authorization_name" {
  description = "DNS authorization resource name"
  value       = google_certificate_manager_dns_authorization.main.name
}

output "dns_record_name" {
  description = "CNAME record name to add at your DNS provider (Gandi.net)"
  value       = google_certificate_manager_dns_authorization.main.dns_resource_record[0].name
}

output "dns_record_type" {
  description = "DNS record type (CNAME)"
  value       = google_certificate_manager_dns_authorization.main.dns_resource_record[0].type
}

output "dns_record_data" {
  description = "CNAME record data to add at your DNS provider (Gandi.net)"
  value       = google_certificate_manager_dns_authorization.main.dns_resource_record[0].data
}

# -----------------------------------------------------------------------------
# SSL Certificate
# -----------------------------------------------------------------------------

output "certificate_id" {
  description = "The ID of the Google-managed SSL certificate"
  value       = google_certificate_manager_certificate.main.id
}

output "certificate_name" {
  description = "The name of the Google-managed SSL certificate"
  value       = google_certificate_manager_certificate.main.name
}

# -----------------------------------------------------------------------------
# Backend Service
# -----------------------------------------------------------------------------

output "backend_service_id" {
  description = "The ID of the regional backend service"
  value       = google_compute_region_backend_service.main.id
}

output "backend_service_name" {
  description = "The name of the regional backend service"
  value       = google_compute_region_backend_service.main.name
}

output "backend_service_self_link" {
  description = "The self link of the regional backend service"
  value       = google_compute_region_backend_service.main.self_link
}

# -----------------------------------------------------------------------------
# URL Map and Forwarding Rules
# -----------------------------------------------------------------------------

output "url_map_id" {
  description = "The ID of the URL map"
  value       = google_compute_region_url_map.main.id
}

output "forwarding_rule_id" {
  description = "The ID of the HTTPS forwarding rule"
  value       = google_compute_forwarding_rule.https.id
}

# -----------------------------------------------------------------------------
# Instructions for Completing Setup
# -----------------------------------------------------------------------------

output "setup_instructions" {
  description = "Instructions for completing the load balancer setup"
  value       = <<-EOT

    ============================================================
    Regional Load Balancer Setup Instructions
    ============================================================

    1. ADD DNS RECORD AT GANDI.NET:
       ----------------------------------------
       Record Type: CNAME
       Name:        ${google_certificate_manager_dns_authorization.main.dns_resource_record[0].name}
       Value:       ${google_certificate_manager_dns_authorization.main.dns_resource_record[0].data}

    2. ADD A RECORD FOR YOUR DOMAIN:
       ----------------------------------------
       Record Type: A
       Name:        @ (or subdomain)
       Value:       ${google_compute_address.lb_ip.address}

    3. CHECK CERTIFICATE STATUS:
       ----------------------------------------
       gcloud certificate-manager certificates describe ${google_certificate_manager_certificate.main.name} \
         --location=${var.region} --project=${var.project_id}

    4. FIREWALL RULE:
       ----------------------------------------
       The firewall rule allowing traffic from the proxy-only subnet
       is automatically created by the vpc-network module when
       enable_proxy_only_subnet=true is set in bootstrap.

    ============================================================

  EOT
}
