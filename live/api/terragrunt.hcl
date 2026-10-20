include "root" { path = find_in_parent_folders("root.hcl") }
locals { config = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals }
terraform { source = "../../modules/api" }

dependency "core" {
  config_path                             = "../core"
  mock_outputs                            = { runtime_email = "soccer-schedule-runtime@example.invalid" }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependencies { paths = ["../data"] }

inputs = {
  enabled               = local.config.deploy_api
  name                  = local.config.api_name
  image                 = local.config.image
  service_account_email = dependency.core.outputs.runtime_email
  # The API will validate Firebase ID tokens itself when implemented.
  allow_unauthenticated = local.config.deploy_api
}
