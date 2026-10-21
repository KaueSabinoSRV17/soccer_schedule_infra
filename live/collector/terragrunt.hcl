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
  calendar_auth_mode              = local.config.calendar_auth_mode
  calendar_id                     = local.config.calendar_id
  environment = merge({
    SOCCER_TIMEZONE = "America/Sao_Paulo"
    }, local.config.calendar_auth_mode == "oauth" ? {
    GOOGLE_CALENDAR_TOKEN = "/var/secrets/google-calendar-token/token.json"
  } : {})
  secrets = {
    THESPORTSDB_API_KEY = { secret = "thesportsdb-api-key" }
    YOUTUBE_API_KEY     = { secret = "youtube-api-key" }
  }
  secret_volumes = local.config.calendar_auth_mode == "oauth" ? {
    google-calendar-token = {
      secret     = "google-calendar-token"
      mount_path = "/var/secrets/google-calendar-token"
      file_name  = "token.json"
    }
  } : {}
}
