# modules/monitoring-alerts/outputs.tf

output "uptime_check_id" {
  description = "Portal uptime check ID"
  value       = google_monitoring_uptime_check_config.portal.uptime_check_id
}

output "alert_policy_ids" {
  description = "Map of alert policy names to IDs"
  value = {
    cloud_run_errors = google_monitoring_alert_policy.cloud_run_errors.name
    db_cpu           = google_monitoring_alert_policy.db_cpu.name
    db_storage       = google_monitoring_alert_policy.db_storage.name
    uptime_failed    = google_monitoring_alert_policy.uptime_failed.name
  }
}
