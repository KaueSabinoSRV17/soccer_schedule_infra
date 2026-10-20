output "uri" { value = try(google_cloud_run_v2_service.api[0].uri, null) }
