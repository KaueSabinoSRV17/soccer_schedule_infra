locals {
  project_id = get_env("GCP_PROJECT_ID", "")
  region     = get_env("GCP_REGION", "southamerica-east1")

  repository_id = "soccer-schedule"
  job_name      = "soccer-schedule-daily"
  api_name      = "soccer-schedule-api"

  # Set to true only after an application container has been published.
  deploy_job = false
  deploy_api = false

  # Override with SOCCER_IMAGE. The default name is where CI should publish it.
  image = get_env(
    "SOCCER_IMAGE",
    "${local.region}-docker.pkg.dev/${local.project_id}/${local.repository_id}/soccer-schedule:latest"
  )
}
