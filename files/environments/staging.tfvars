aws_region = "ap-south-1"

vpc_id = "vpc-0staging123456789"

private_subnet_ids = [
  "subnet-0staging123456789",
  "subnet-0staging987654321",
]

default_ec2_ami_id                = "ami-0staging123456789"
default_rds_backup_retention_days = 14

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
#   "arn:aws:sns:ap-south-1:111122223333:idp-staging-alerts",
#   "arn:aws:sns:ap-south-1:111122223333:idp-platform-alerts",
# ]

global_tags = {
  Owner       = "platform-engineering"
  CostCenter  = "shared-platform-staging"
  Compliance  = "required"
  Environment = "staging"
}

# Demo mode: keep default AWS-managed encryption and do not require customer-managed KMS keys.
# rds_kms_key_id = "arn:aws:kms:ap-south-1:111122223333:key/staging-rds-key"
# ec2_kms_key_id = "arn:aws:kms:ap-south-1:111122223333:key/staging-ec2-key"
# s3_kms_key_id  = "arn:aws:kms:ap-south-1:111122223333:key/staging-s3-key"
