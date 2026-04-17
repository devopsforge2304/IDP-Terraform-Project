aws_region = "us-east-1"

vpc_id = "vpc-0e8f0bcc09c90f226"

private_subnet_ids = [
  "subnet-0af172c4760bcc457",
  "subnet-0a9b27882a8722f77",
]

default_ec2_ami_id                = "ami-098e39bafa7e7303d"
default_rds_backup_retention_days = 3

allowed_rds_instance_classes = [
  "db.t3.micro",
  "db.t3.small",
]

allowed_redis_node_types = [
  "cache.t3.micro",
]

allowed_ec2_instance_types = [
  "t3.micro",
  "t3.small",
]

# Demo mode: leave alarm actions empty so Terraform does not depend on SNS topics.
# monitor_alarm_actions = [
#   "arn:aws:sns:ap-south-1:111122223333:idp-dev-alerts",
# ]

global_tags = {
  Owner       = "platform-engineering"
  CostCenter  = "shared-platform-dev"
  Compliance  = "baseline"
  Environment = "dev"
}

# Demo mode: keep default AWS-managed encryption and do not require customer-managed KMS keys.
# rds_kms_key_id = "arn:aws:kms:ap-south-1:111122223333:key/dev-rds-key"
# ec2_kms_key_id = "arn:aws:kms:ap-south-1:111122223333:key/dev-ec2-key"
# s3_kms_key_id  = "arn:aws:kms:ap-south-1:111122223333:key/dev-s3-key"
