# modules/cloud-sql/outputs.tf

output "instance_name" {
  description = "The Cloud SQL instance name"
  value       = google_sql_database_instance.main.name
}

output "instance_connection_name" {
  description = "The Cloud SQL instance connection name (for proxy)"
  value       = google_sql_database_instance.main.connection_name
}

output "instance_self_link" {
  description = "The Cloud SQL instance self link"
  value       = google_sql_database_instance.main.self_link
}

output "private_ip_address" {
  description = "The private IP address of the instance"
  value       = google_sql_database_instance.main.private_ip_address
}

output "database_name" {
  description = "The database name"
  value       = google_sql_database.main.name
}

output "database_user" {
  description = "The database username"
  value       = google_sql_user.app_user.name
}

output "connection_string" {
  description = "PostgreSQL connection string (without password)"
  value       = "postgresql://${google_sql_user.app_user.name}@${google_sql_database_instance.main.private_ip_address}:5432/${google_sql_database.main.name}"
}

output "instance_tier" {
  description = "The Cloud SQL instance tier"
  value       = google_sql_database_instance.main.settings[0].tier
}

output "availability_type" {
  description = "The availability type (ZONAL or REGIONAL)"
  value       = google_sql_database_instance.main.settings[0].availability_type
}
