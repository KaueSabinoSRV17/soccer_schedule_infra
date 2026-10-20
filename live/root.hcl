locals {
  config     = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals
  project_id = local.config.project_id
  region     = local.config.region
}

remote_state {
  backend = "gcs"
  config = {
    project  = local.project_id
    location = local.region
    bucket   = "${local.project_id}-soccer-schedule-tfstate"
    prefix   = path_relative_to_include()
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.7, < 2.0"
      required_providers {
        google = {
          source  = "hashicorp/google"
          version = "~> 7.0"
        }
        google-beta = {
          source  = "hashicorp/google-beta"
          version = "~> 7.0"
        }
      }
    }

    provider "google" {
      project = var.project_id
      region  = var.region
    }

    provider "google-beta" {
      project = var.project_id
      region  = var.region
    }
  EOF
}

inputs = {
  project_id = local.project_id
  region     = local.region
}
