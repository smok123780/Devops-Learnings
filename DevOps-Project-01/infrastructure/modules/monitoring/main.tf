resource "google_monitoring_notification_channel" "ops_email" {
  display_name = "Ops Email"
  type         = "email"
  project      = var.project_id
  labels       = { email_address = var.ops_email }
}

resource "google_monitoring_alert_policy" "cpu_high" {
  display_name = "High CPU usage"
  combiner     = "OR"
  project      = var.project_id
  conditions {
    display_name = "VM CPU > 80% for 5m"
    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }
  notification_channels = [google_monitoring_notification_channel.ops_email.id]
  alert_strategy { auto_close = "1800s" }
  enabled = true
}
