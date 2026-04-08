variable "tenant_name" { type = string }
variable "environment" { type = string }
variable "team_email" { type = string }

variable "gmail_sender_email" {
  type = string
}

variable "gmail_app_password" {
  type      = string
  sensitive = true
}

variable "enabled_resources" { type = list(string) }

variable "rds_endpoint" {
  type    = string
  default = "N/A"
}

variable "s3_bucket_name" {
  type    = string
  default = "N/A"
}

variable "redis_endpoint" {
  type    = string
  default = "N/A"
}

variable "ec2_private_ips" {
  type    = list(string)
  default = []
}

variable "secret_name" { type = string }
variable "secret_arn" { type = string }
variable "estimated_cost_value" { type = number }
