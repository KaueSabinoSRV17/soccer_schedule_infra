locals {
  project_id = get_env("GCP_PROJECT_ID", "")
  region     = get_env("GCP_REGION", "southamerica-east1")

  github_owner         = "KaueSabinoSRV17"
  github_repository    = "soccer-schedule"
  github_owner_id      = "81828528"
  github_repository_id = "1427148023"
  publishing_branch    = "main"

  repository_id = "soccer-schedule"
  job_name      = "soccer-schedule-daily"
  api_name      = "soccer-schedule-api"

  # Switch after applying the app patch and sharing the target calendar.
  calendar_auth_mode = "oauth"
  calendar_id        = get_env("GOOGLE_CALENDAR_ID", "primary")

  # Set to true only after an application container has been published.
  deploy_job = true
  deploy_api = false

  # Follow the latest image published by CI. SOCCER_IMAGE can override this for a rollback.
  image = get_env(
    "SOCCER_IMAGE",
    "${local.region}-docker.pkg.dev/${local.project_id}/${local.repository_id}/soccer-schedule:latest"
  )
}
