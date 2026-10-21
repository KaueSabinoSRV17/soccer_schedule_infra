resource "google_cloud_run_v2_job" "daily" {
  count    = var.enabled ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = var.name

  deletion_protection = true

  lifecycle {
    precondition {
      condition     = var.calendar_auth_mode != "service_account" || lower(trimspace(var.calendar_id)) != "primary"
      error_message = "Service-account authentication requires the shared calendar's explicit Calendar ID, not primary."
    }
  }

  template {
    task_count  = 1
    parallelism = 1

    template {
      service_account = var.runtime_service_account_email
      timeout         = "600s"
      max_retries     = 2

      containers {
        image   = var.image
        command = ["node", "dist/src/cli.js"]
        args    = ["--full-calendar-sync"]

        resources { limits = { cpu = "1", memory = "512Mi" } }

        dynamic "env" {
          for_each = merge(var.environment, {
            GOOGLE_CALENDAR_AUTH_MODE = var.calendar_auth_mode
            GOOGLE_CALENDAR_ID        = var.calendar_id
          })
          content {
            name  = env.key
            value = env.value
          }
        }

        dynamic "env" {
          for_each = var.secrets
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value.secret
                version = env.value.version
              }
            }
          }
        }

        dynamic "volume_mounts" {
          for_each = var.secret_volumes
          content {
            name       = volume_mounts.key
            mount_path = volume_mounts.value.mount_path
          }
        }
      }

      dynamic "volumes" {
        for_each = var.secret_volumes
        content {
          name = volumes.key
          secret {
            secret = volumes.value.secret
            items {
              version = volumes.value.version
              path    = volumes.value.file_name
            }
          }
        }
      }
    }
  }
}

resource "google_cloud_run_v2_job_iam_member" "scheduler_invoker" {
  count    = var.enabled ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.daily[0].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.scheduler_service_account_email}"
}

resource "google_cloud_scheduler_job" "daily" {
  count       = var.enabled ? 1 : 0
  project     = var.project_id
  region      = var.region
  name        = var.scheduler_name
  description = "Run the Soccer Schedule collector every morning"
  schedule    = var.schedule
  time_zone   = var.time_zone

  attempt_deadline = "320s"

  retry_config {
    retry_count          = 2
    min_backoff_duration = "30s"
    max_backoff_duration = "300s"
  }

  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.region}/jobs/${google_cloud_run_v2_job.daily[0].name}:run"

    oauth_token {
      service_account_email = var.scheduler_service_account_email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  depends_on = [google_cloud_run_v2_job_iam_member.scheduler_invoker]
}
