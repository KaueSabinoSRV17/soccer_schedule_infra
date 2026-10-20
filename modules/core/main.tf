resource "google_project_service" "api" {
  for_each = var.services
  project  = var.project_id
  service  = each.value

  disable_on_destroy = false
}

resource "google_apikeys_key" "youtube" {
  project      = var.project_number
  name         = var.youtube_api_key_name
  display_name = var.youtube_api_key_display_name

  restrictions {
    api_targets {
      service = "youtube.googleapis.com"
      methods = []
    }
  }

  depends_on = [google_project_service.api]

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_artifact_registry_repository" "docker" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  description   = "Soccer Schedule application images"
  format        = "DOCKER"

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions { keep_count = 5 }
  }

  cleanup_policies {
    id     = "delete-old-untagged"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "604800s"
    }
  }

  depends_on = [google_project_service.api]
}

locals {
  service_accounts = {
    runtime = {
      account_id   = "soccer-schedule-runtime"
      display_name = "Soccer Schedule runtime"
    }
    scheduler = {
      account_id   = "soccer-schedule-scheduler"
      display_name = "Soccer Schedule scheduler"
    }
  }
}

resource "google_service_account" "account" {
  for_each     = local.service_accounts
  project      = var.project_id
  account_id   = each.value.account_id
  display_name = each.value.display_name

  depends_on = [google_project_service.api]
}

resource "google_project_iam_member" "runtime_roles" {
  for_each = toset([
    "roles/datastore.user",
    "roles/firebasecloudmessaging.admin",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.account["runtime"].email}"
}

resource "google_secret_manager_secret" "secret" {
  for_each  = var.secret_ids
  project   = var.project_id
  secret_id = each.value

  replication {
    auto {}
  }

  depends_on = [google_project_service.api]
}

resource "google_secret_manager_secret_iam_member" "runtime_access" {
  for_each  = var.secret_ids
  project   = var.project_id
  secret_id = google_secret_manager_secret.secret[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.account["runtime"].email}"
}
