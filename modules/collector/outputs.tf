output "job_name" { value = try(google_cloud_run_v2_job.daily[0].name, null) }
output "scheduler_name" { value = try(google_cloud_scheduler_job.daily[0].name, null) }
output "calendar_service_account_email" { value = var.runtime_service_account_email }
output "calendar_auth_mode" { value = var.calendar_auth_mode }
output "calendar_id" { value = var.calendar_id }
