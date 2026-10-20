variable "project_id" { type = string }
variable "project_number" { type = string }
variable "region" { type = string }
variable "services" { type = set(string) }
variable "repository_id" { type = string }
variable "secret_ids" { type = set(string) }
variable "youtube_api_key_name" { type = string }
variable "youtube_api_key_display_name" { type = string }
