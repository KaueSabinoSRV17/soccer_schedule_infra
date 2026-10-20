variable "project_id" { type = string }
variable "region" { type = string }
variable "enabled" { type = bool }
variable "name" { type = string }
variable "image" { type = string }
variable "runtime_service_account_email" { type = string }
variable "scheduler_service_account_email" { type = string }
variable "environment" { type = map(string) }
variable "secrets" {
  type = map(object({ secret = string, version = optional(string, "latest") }))
}
variable "secret_volumes" {
  type = map(object({ secret = string, mount_path = string, file_name = string, version = optional(string, "latest") }))
}
variable "scheduler_name" { type = string }
variable "schedule" {
  type    = string
  default = "0 6 * * *"
}
variable "time_zone" {
  type    = string
  default = "America/Sao_Paulo"
}
