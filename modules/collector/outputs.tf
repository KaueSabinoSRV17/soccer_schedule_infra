output "job_name" { value = try(google_cloud_run_v2_job.daily[0].name, null) }
output "scheduler_name" { value = try(google_cloud_scheduler_job.daily[0].name, null) }
