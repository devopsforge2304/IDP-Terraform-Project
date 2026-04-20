variable "aws_region" {
  description = "AWS region for platform resources."
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where tenant resources will be created."
  type        = string
  default     = null
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by workload resources."
  type        = list(string)
  default     = []
}

variable "secrets_manager_kms_key_id" {
  description = "Optional KMS key ID or ARN for encrypting AWS Secrets Manager secrets."
  type        = string
  default     = null
}

variable "gmail_sender_email" {
  description = "Gmail address used to send provisioning notifications."
  type        = string
}

variable "gmail_app_password" {
  description = "Gmail app password used for SMTP authentication."
  type        = string
  sensitive   = true
}

variable "allowed_environments" {
  description = "Permitted deployment environments from the request workflow."
  type        = list(string)
  default     = ["dev", "test", "qa", "staging", "production"]
}

variable "allowed_rds_instance_classes" {
  description = "Approved RDS instance classes."
  type        = list(string)
  default     = ["db.t3.micro", "db.t3.small", "db.r5.large"]
}

variable "allowed_redis_node_types" {
  description = "Approved Redis node types."
  type        = list(string)
  default     = ["cache.t3.micro", "cache.t3.small"]
}

variable "allowed_ec2_instance_types" {
  description = "Approved EC2 instance types."
  type        = list(string)
  default     = ["t3.micro", "t3.small", "m6i.large"]
}

variable "default_ec2_ami_id" {
  description = "Default AMI for EC2 requests when none is supplied in infra-management/infra.yaml."
  type        = string
  default     = "ami-xxxxxxxxxxxxxxxxx"
}

variable "default_rds_backup_retention_days" {
  description = "Default RDS backup retention days when none is supplied in infra-management/infra.yaml."
  type        = number
  default     = 7
}

variable "monitor_alarm_actions" {
  description = "Optional CloudWatch alarm actions for notifications."
  type        = list(string)
  default     = []
}

variable "global_tags" {
  description = "Additional global tags applied to all resources."
  type        = map(string)
  default = {
    Owner      = "platform-engineering"
    CostCenter = "shared-platform"
    Compliance = "required"
  }
}

variable "rds_kms_key_id" {
  description = "Optional KMS key ID or ARN used for RDS storage encryption."
  type        = string
  default     = null
}

variable "ec2_kms_key_id" {
  description = "Optional KMS key ID or ARN used for EC2 root volume encryption."
  type        = string
  default     = null
}

variable "s3_kms_key_id" {
  description = "Optional KMS key ID or ARN used for S3 default bucket encryption."
  type        = string
  default     = null
}

variable "rds_cost_map" {
  description = "Monthly estimate by RDS instance class."
  type        = map(number)
  default = {
    "db.t3.micro" = 13
    "db.t3.small" = 27
    "db.r5.large" = 175
  }
}

variable "redis_cost_map" {
  description = "Monthly estimate by Redis node type."
  type        = map(number)
  default = {
    "cache.t3.micro" = 12
    "cache.t3.small" = 24
  }
}

variable "ec2_cost_map" {
  description = "Monthly estimate by EC2 instance type."
  type        = map(number)
  default = {
    "t3.micro"  = 8
    "t3.small"  = 15
    "m6i.large" = 70
  }
}

variable "s3_base_monthly_cost" {
  description = "Base monthly estimate for a small tenant S3 footprint."
  type        = number
  default     = 1
}
