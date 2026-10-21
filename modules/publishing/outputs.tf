output "workload_identity_provider" { value = google_iam_workload_identity_pool_provider.github.name }
output "publisher_email" { value = google_service_account.publisher.email }
output "actions_variables" { value = local.actions_variables }
