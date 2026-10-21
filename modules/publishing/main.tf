resource "google_service_account" "publisher" {
  project      = var.project_id
  account_id   = "soccer-schedule-publisher"
  display_name = "Soccer Schedule GitHub image publisher"
}

resource "google_artifact_registry_repository_iam_member" "publisher" {
  project    = var.project_id
  location   = var.region
  repository = var.repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.publisher.email}"
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "soccer-schedule-github"
  display_name              = "Soccer Schedule GitHub"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub Actions"

  attribute_mapping = {
    "google.subject"          = "assertion.sub"
    "attribute.repository_id" = "assertion.repository_id"
  }

  # Numeric IDs prevent a renamed or recreated repository/owner taking over trust.
  # PR workflows cannot publish, even when their base branch is main.
  attribute_condition = "assertion.repository_owner_id == '${var.github_owner_id}' && assertion.repository_id == '${var.github_repository_id}' && assertion.ref == 'refs/heads/${var.publishing_branch}' && assertion.event_name in ['push', 'workflow_dispatch']"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github" {
  service_account_id = google_service_account.publisher.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository_id/${var.github_repository_id}"
}

locals {
  actions_variables = {
    GCP_PROJECT_ID                 = var.project_id
    GCP_WORKLOAD_IDENTITY_PROVIDER = google_iam_workload_identity_pool_provider.github.name
    GCP_SERVICE_ACCOUNT            = google_service_account.publisher.email
    GCP_REGION                     = var.region
    GAR_REPOSITORY                 = var.repository_id
  }
}

resource "github_actions_variable" "publishing" {
  for_each      = local.actions_variables
  repository    = var.github_repository
  variable_name = each.key
  value         = each.value
}
