# modules/vpc-network/outputs.tf

output "network_id" {
  description = "The VPC network ID"
  value       = google_compute_network.main.id
}

output "network_name" {
  description = "The VPC network name"
  value       = google_compute_network.main.name
}

output "network_self_link" {
  description = "The VPC network self link"
  value       = google_compute_network.main.self_link
}

output "subnet_id" {
  description = "The subnet ID"
  value       = google_compute_subnetwork.main.id
}

output "subnet_name" {
  description = "The subnet name"
  value       = google_compute_subnetwork.main.name
}

output "subnet_self_link" {
  description = "The subnet self link"
  value       = google_compute_subnetwork.main.self_link
}

output "connector_id" {
  description = "The VPC Access Connector ID"
  value       = google_vpc_access_connector.main.id
}

output "connector_name" {
  description = "The VPC Access Connector name"
  value       = google_vpc_access_connector.main.name
}

output "private_vpc_connection" {
  description = "The private VPC connection for Cloud SQL"
  value       = google_service_networking_connection.private_vpc_connection.id
}

output "private_ip_range_name" {
  description = "The private IP range name for Cloud SQL"
  value       = google_compute_global_address.private_ip_range.name
}
