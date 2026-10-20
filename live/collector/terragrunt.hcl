include "root" { path = find_in_parent_folders("root.hcl") }
locals { config = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals }
terraform { source = "../../modules/collector" }

dependency "core" {
  config_path = "../core"
  mock_outputs = {
    runtime_email   = "soccer-schedule-runtime@example.invalid"
    scheduler_email = "soccer-schedule-scheduler@example.invalid"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  enabled                         = local.config.deploy_job
  name                            = local.config.job_name
  scheduler_name                  = "soccer-schedule-at-0600"
  image                           = local.config.image
  runtime_service_account_email   = dependency.core.outputs.runtime_email
  scheduler_service_account_email = dependency.core.outputs.scheduler_email
  schedule                        = "0 6 * * *"
  time_zone                       = "America/Sao_Paulo"
  environment = {
    SOCCER_TIMEZONE             = "America/Sao_Paulo"
    GOOGLE_CALENDAR_ID          = "primary"
    GOOGLE_CALENDAR_CREDENTIALS = "/var/secrets/google-calendar-oauth/client.json"
    GOOGLE_CALENDAR_TOKEN       = "/var/secrets/google-calendar-token/token.json"
  }
  secrets = {
    THESPORTSDB_API_KEY = { secret = "thesportsdb-api-key" }
    YOUTUBE_API_KEY     = { secret = "youtube-api-key" }
  }
  secret_volumes = {
    google-calendar-oauth = {
      secret     = "google-calendar-oauth"
      mount_path = "/var/secrets/google-calendar-oauth"
      file_name  = "client.json"
    }
    google-calendar-token = {
      secret     = "google-calendar-token"
      mount_path = "/var/secrets/google-calendar-token"
      file_name  = "token.json"
    }
  }
}
