include "root" { path = find_in_parent_folders("root.hcl") }
locals { config = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals }

terraform { source = "../../modules/core" }

inputs = {
  repository_id = local.config.repository_id
  # Canonical identifiers from the imported key. The API Keys provider stores
  # the numeric project in state, so using the project ID here would force a
  # replacement even though both identify the same project.
  project_number               = "238859401285"
  youtube_api_key_name         = "81db29ad-1b1d-4c82-b3fa-30d5c33b3889"
  youtube_api_key_display_name = "soccer_schedule"
  services = [
    "apikeys.googleapis.com",
    "artifactregistry.googleapis.com",
    "calendar-json.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "fcm.googleapis.com",
    "firebase.googleapis.com",
    "firebaseinstallations.googleapis.com",
    "firestore.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
    "youtube.googleapis.com",
  ]
  secret_ids = [
    "thesportsdb-api-key",
    "youtube-api-key",
    "google-calendar-oauth",
    "google-calendar-token",
  ]
}
