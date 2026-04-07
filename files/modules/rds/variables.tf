variable "tenant_name" { type = string }
variable "environment" { type = string }
variable "instance_class" { type = string }
variable "db_name" { type = string }
variable "subnet_ids" { type = list(string) }
variable "vpc_id" { type = string }
variable "backup_retention" { type = number }
variable "multi_az" { type = bool }
variable "monitor_actions" { type = list(string) }
variable "kms_key_id" {
  type    = string
  default = null
}
variable "tags" { type = map(string) }