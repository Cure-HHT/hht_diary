# Supabase Project Module Outputs

output "project_id" {
  description = "Supabase project ID (reference)"
  value       = supabase_project.main.id
}

output "project_name" {
  description = "Supabase project name"
  value       = supabase_project.main.name
}

output "project_region" {
  description = "Supabase project region"
  value       = supabase_project.main.region
}

output "project_url" {
  description = "Supabase project URL"
  value       = "https://${supabase_project.main.id}.supabase.co"
}

output "api_url" {
  description = "Supabase API URL"
  value       = "https://${supabase_project.main.id}.supabase.co/rest/v1"
}

output "graphql_url" {
  description = "Supabase GraphQL URL"
  value       = "https://${supabase_project.main.id}.supabase.co/graphql/v1"
}

output "database_host" {
  description = "Database host"
  value       = "db.${supabase_project.main.id}.supabase.co"
}

output "database_port" {
  description = "Database port"
  value       = 5432
}

output "anon_key" {
  description = "Supabase anonymous key (public)"
  value       = supabase_project.main.anon_key
  sensitive   = false  # Public key, safe to expose
}

output "service_role_key" {
  description = "Supabase service role key (sensitive)"
  value       = supabase_project.main.service_role_key
  sensitive   = true  # Keep secret
}

output "jwt_secret" {
  description = "JWT secret for token verification"
  value       = supabase_project.main.jwt_secret
  sensitive   = true  # Keep secret
}

output "backup_schedule" {
  description = "Backup schedule (if enabled)"
  value       = var.enable_backups ? "Daily at 2 AM" : "Disabled"
}

output "preview_branch_id" {
  description = "Preview branch ID (if created)"
  value       = var.create_preview_branch ? supabase_branch.preview[0].id : null
}
