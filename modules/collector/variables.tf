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

variable "calendar_auth_mode" {
  type    = string
  default = "oauth"
  validation {
    condition     = contains(["oauth", "service_account"], var.calendar_auth_mode)
    error_message = "Calendar authentication must be oauth or service_account."
  }
}
variable "calendar_id" {
  type    = string
  default = "primary"
  validation {
    condition     = length(trimspace(var.calendar_id)) > 0
    error_message = "A Calendar ID is required."
  }
}
