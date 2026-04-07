variable "tenant_name" { type = string }
variable "environment" { type = string }

variable "rds_endpoint" {
  type    = string
  default = ""
}

variable "rds_username" {
  type    = string
  default = ""
}

variable "rds_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "s3_bucket_name" {
  type    = string
  default = ""
}

variable "redis_endpoint" {
  type    = string
  default = ""
}

variable "ec2_private_ips" {
  type    = list(string)
  default = []
}

variable "enabled_modules" {
  type    = list(string)
  default = []
}