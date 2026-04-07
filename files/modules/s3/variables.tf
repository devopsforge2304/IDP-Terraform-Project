variable "tenant_name" { type = string }
variable "environment" { type = string }
variable "versioning" { type = bool }
variable "lifecycle_days" {
  type    = number
  default = null
}
variable "iam_role_arn" { type = string }
variable "kms_key_id" {
  type    = string
  default = null
}
variable "tags" { type = map(string) }