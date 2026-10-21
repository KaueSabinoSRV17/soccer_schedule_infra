include "root" { path = find_in_parent_folders("root.hcl") }
locals { config = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals }
terraform { source = "../../modules/publishing" }

# The repository ID is shared configuration, so no state output is needed.
# Keep core first in all-unit runs to create the registry and enable APIs.
dependencies { paths = ["../core"] }

generate "github_provider" {
  path      = "github-provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "github" {
      owner = "${local.config.github_owner}"
    }
  EOF
}

inputs = {
  repository_id        = local.config.repository_id
  github_repository    = local.config.github_repository
  github_repository_id = local.config.github_repository_id
  github_owner_id      = local.config.github_owner_id
  publishing_branch    = local.config.publishing_branch
}
