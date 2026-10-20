variable "project_id" { type = string }
variable "region" { type = string }
variable "enabled" { type = bool }
variable "name" { type = string }
variable "image" { type = string }
variable "service_account_email" { type = string }
variable "allow_unauthenticated" {
  type    = bool
  default = false
}
