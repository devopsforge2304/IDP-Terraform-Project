variable "tenant_name" {
  type = string
}
variable "environment" {
  type = string
}
variable "instance_type" {
  type = string
}
variable "instance_count" {
  type = number
}
variable "ami_id" {
  type = string
}
variable "subnet_id" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "iam_instance_profile_name" {
  type = string
}
variable "backup_enabled" {
  type = bool
}
variable "monitor_actions" {
  type = list(string)
}
variable "kms_key_id" {
  type    = string
  default = null
}
variable "tags" {
  type = map(string)
}