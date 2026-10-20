output "runtime_email" { value = google_service_account.account["runtime"].email }
output "scheduler_email" { value = google_service_account.account["scheduler"].email }
output "repository_url" { value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}" }
output "secret_ids" { value = { for key, secret in google_secret_manager_secret.secret : key => secret.secret_id } }
output "enabled_services" { value = sort([for service in google_project_service.api : service.service]) }
output "youtube_api_key_id" { value = google_apikeys_key.youtube.id }
