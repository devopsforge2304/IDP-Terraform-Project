aws_region = "ap-south-1"

vpc_id = "vpc-0qa123456789abcd0"

private_subnet_ids = [
  "subnet-0qa123456789abcd0",
  "subnet-0qa987654321abcd0",
]

default_ec2_ami_id                = "ami-0qa123456789abcd0"
default_rds_backup_retention_days = 7

allowed_rds_instance_classes = [
  "db.t3.small",
  "db.r5.large",
]

allowed_redis_node_types = [
  "cache.t3.small",
]

allowed_ec2_instance_types = [
  "t3.small",
  "m6i.large",
]

# Demo mode: leave alarm actions empty so Terraform does not depend on SNS topics.
# monitor_alarm_actions = [
#   "arn:aws:sns:ap-south-1:111122223333:idp-qa-alerts",
# ]

global_tags = {
  Owner       = "platform-engineering"
  CostCenter  = "shared-platform-qa"
  Compliance  = "required"
  Environment = "qa"
}

# Demo mode: keep default AWS-managed encryption and do not require customer-managed KMS keys.
# rds_kms_key_id = "arn:aws:kms:ap-south-1:111122223333:key/qa-rds-key"
# ec2_kms_key_id = "arn:aws:kms:ap-south-1:111122223333:key/qa-ec2-key"
# s3_kms_key_id  = "arn:aws:kms:ap-south-1:111122223333:key/qa-s3-key"
