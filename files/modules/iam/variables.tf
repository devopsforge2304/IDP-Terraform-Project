variable "tenant_name" { type = string }
variable "environment" { type = string }
variable "enable_rds" { type = bool }
variable "enable_s3" { type = bool }
variable "enable_redis" { type = bool }
variable "enable_ec2" { type = bool }
variable "tags" { type = map(string) }